import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:open_file/open_file.dart';

class AttendanceReportPage extends StatefulWidget {
  @override
  _AttendanceReportPageState createState() => _AttendanceReportPageState();
}

class _AttendanceReportPageState extends State<AttendanceReportPage> {
  String selectedDept = "Computer Engineering";
  String selectedSemester = "Sem 6";
  DateTime selectedMonth = DateTime.now();
  List<String> subjectsList = [];
  String selectedSubject = "";
  List<Map<String, dynamic>> attendanceRecords = [];
  List<Map<String, dynamic>> students = [];
  bool isLoading = true;
  String errorMessage = "";
  Set<DateTime> selectedMonths = {};
  bool isMultipleSelection = false;

  List<String> departments = [
    "Computer Engineering",
    "Electronics Engineering",
    "Printing Technology"
  ];
  List<String> semesters = [
    "Sem 1",
    "Sem 2",
    "Sem 3",
    "Sem 4",
    "Sem 5",
    "Sem 6"
  ];
  List<String> holidays = [];

  @override
  void initState() {
    super.initState();
    fetchTimetable();
    fetchStudents();
    fetchHolidays();
  }

  Future<void> fetchTimetable() async {
    try {
      QuerySnapshot querySnapshot = await FirebaseFirestore.instance
          .collection("timetable")
          .where("branch", isEqualTo: selectedDept)
          .where("semester", isEqualTo: selectedSemester)
          .get();

      Set<String> subjects = {};
      for (var doc in querySnapshot.docs) {
        var data = doc.data() as Map<String, dynamic>;
        for (var period in data["periods"]) {
          subjects.add(period["subject"]);
        }
      }

      setState(() {
        subjectsList = ["---", ...subjects.toList()];
      });
    } catch (e) {
      print("Error fetching timetable: $e");
    }
  }

  Future<void> fetchStudents() async {
    setState(() => isLoading = true);
    try {
      final studentsQuery = await FirebaseFirestore.instance
          .collection('users')
          .where('department', isEqualTo: selectedDept)
          .where('semester', isEqualTo: selectedSemester)
          .get();

      List<Map<String, dynamic>> studentData = studentsQuery.docs
          .map((doc) => doc.data() as Map<String, dynamic>)
          .toList();

      setState(() {
        students = studentData;
      });

      fetchAttendanceData();
    } catch (e) {
      setState(() => errorMessage = 'Error fetching students: $e');
    }
  }

  Future<void> fetchAttendanceData() async {
    setState(() => isLoading = true);
    try {
      List<DateTime> monthsToFetch =
          isMultipleSelection ? selectedMonths.toList() : [selectedMonth];

      List<QuerySnapshot> attendanceSnapshots = [];

      for (var month in monthsToFetch) {
        DateTime nextMonthStart = DateTime(month.year, month.month + 1, 1);
        DateTime monthEnd = nextMonthStart.subtract(Duration(days: 1));

        Query attendanceQuery = FirebaseFirestore.instance
            .collection('attendance')
            .where('department', isEqualTo: selectedDept)
            .where('semester', isEqualTo: selectedSemester)
            .where('timestamp',
                isGreaterThanOrEqualTo:
                    Timestamp.fromDate(DateTime(month.year, month.month, 1)))
            .where('timestamp',
                isLessThanOrEqualTo: Timestamp.fromDate(monthEnd));

        if (selectedSubject.isNotEmpty && selectedSubject != "---") {
          attendanceQuery =
              attendanceQuery.where('subject', isEqualTo: selectedSubject);
        }

        final snapshot = await attendanceQuery.get();
        attendanceSnapshots.add(snapshot);
      }

      List<Map<String, dynamic>> fetchedAttendance = [];
      for (var snapshot in attendanceSnapshots) {
        fetchedAttendance.addAll(snapshot.docs
            .map((doc) => doc.data() as Map<String, dynamic>)
            .toList());
      }

      setState(() {
        attendanceRecords = fetchedAttendance;
        isLoading = false;
      });
    } catch (e) {
      setState(() => errorMessage = 'Error fetching attendance data: $e');
    }
  }

  int getTotalAttendedPeriods(String studentId) {
    return attendanceRecords
        .where((record) => record['id'] == studentId)
        .fold(0, (sum, record) => sum + int.parse(record['periods'] ?? "0"));
  }

  int getTotalPeriods() {
    DateTime today = DateTime.now();
    int totalPeriods = getAllWorkingDays()
            .where((day) =>
                DateTime.parse(day).isBefore(today) ||
                DateTime.parse(day).isAtSameMomentAs(today))
            .length *
        3; // Assuming 3 periods per day
    return totalPeriods;
  }

  Future<void> fetchHolidays() async {
    try {
      QuerySnapshot snapshot =
          await FirebaseFirestore.instance.collection('holidays').get();

      List<String> fetchedHolidays =
          snapshot.docs.map((doc) => doc['date'] as String).toList();

      setState(() {
        holidays = fetchedHolidays;
      });
    } catch (e) {
      print("Error fetching holidays: $e");
    }
  }

  List<String> getAllWorkingDays() {
    List<DateTime> monthsToProcess =
        isMultipleSelection ? selectedMonths.toList() : [selectedMonth];

    List<String> workingDays = [];

    if (monthsToProcess.isEmpty) {
      return [];
    }
    // Get the last month selected
    DateTime lastSelectedMonth = monthsToProcess.last;

    DateTime firstDayOfMonth =
        DateTime(lastSelectedMonth.year, lastSelectedMonth.month, 1);
    DateTime lastDayOfMonth =
        DateTime(lastSelectedMonth.year, lastSelectedMonth.month + 1, 0);
    DateTime today = DateTime.now();

    if (lastDayOfMonth.isAfter(today)) {
      lastDayOfMonth = today;
    }

    DateTime currentDate = firstDayOfMonth;

    while (currentDate.isBefore(lastDayOfMonth) ||
        currentDate.isAtSameMomentAs(lastDayOfMonth)) {
      String formattedDate = DateFormat('yyyy-MM-dd').format(currentDate);
      if (currentDate.weekday != DateTime.saturday &&
          currentDate.weekday != DateTime.sunday &&
          !holidays.contains(formattedDate)) {
        workingDays.add(formattedDate);
      }
      currentDate = currentDate.add(Duration(days: 1));
    }

    print(workingDays.length);
    return workingDays;
  }

  int getAllWorkingDaysInMonth(DateTime month) {
    DateTime firstDay = DateTime(month.year, month.month, 1);
    DateTime lastDay =
        DateTime(month.year, month.month + 1, 0); // Last day of month
    int count = 0;

    for (DateTime day = firstDay;
        day.isBefore(lastDay) || day.isAtSameMomentAs(lastDay);
        day = day.add(Duration(days: 1))) {
      if (day.weekday != DateTime.saturday &&
          day.weekday != DateTime.sunday &&
          !holidays.contains(DateFormat('yyyy-MM-dd').format(day))) {
        count++;
      }
    }

    return count * 3; // Assuming 3 periods per day
  }

  int getTotalAttendedPeriodsInMonth(String studentId, DateTime month) {
    return attendanceRecords
        .where((record) =>
            record['id'] == studentId &&
            record['timestamp'].toDate().month == month.month &&
            record['timestamp'].toDate().year == month.year)
        .fold(0, (sum, record) => sum + int.parse(record['periods'] ?? "0"));
  }

  Future<void> _generatePDF() async {
    final pdf = pw.Document();
    // Ensure monthsToShow contains only valid months
    Iterable<DateTime> monthsToShow =
        isMultipleSelection && selectedMonths.isNotEmpty
            ? selectedMonths
            : [selectedMonth];

// Get the last selected month safely
    DateTime lastSelectedMonth = monthsToShow.last;

// Format month and year correctly
    String monthName =
        DateFormat('MMMM').format(lastSelectedMonth); // Full month name
    String year = DateFormat('yyyy').format(lastSelectedMonth); // Year
    String MonthName = monthName.toUpperCase();
    String SMonth = DateFormat('MMM').format(lastSelectedMonth); //for like feb
    List<String> Td = getAllWorkingDays() as List<String>;
    int TotalDays = Td.length;
    int tp = getTotalPeriods();
    pdf.addPage(
      pw.Page(
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Center(
                child: pw.Text(
                  'ATTENDANCE STATEMENT $MonthName $year',
                  style: pw.TextStyle(
                      fontSize: 18, fontWeight: pw.FontWeight.bold),
                ),
              ),
              pw.SizedBox(height: 10),
              pw.Center(
                child: pw.Text(
                  'Programme: $selectedDept',
                  style: pw.TextStyle(
                      fontSize: 16, fontWeight: pw.FontWeight.bold),
                ),
              ),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Semester: $selectedSemester',
                    style: pw.TextStyle(
                        fontSize: 16, fontWeight: pw.FontWeight.bold),
                  ),
                  if (selectedSubject == "---")
                    pw.Text(
                      'No of Days in $SMonth $year: $TotalDays',
                      style: pw.TextStyle(
                          fontSize: 16, fontWeight: pw.FontWeight.bold),
                    ),
                ],
              ),
              if (selectedSubject != "---")
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'Subject: $selectedSubject',
                      style: pw.TextStyle(
                          fontSize: 16, fontWeight: pw.FontWeight.bold),
                    ),
                    pw.Text(
                      'Total Periods in $SMonth $year : $tp',
                      style: pw.TextStyle(
                          fontSize: 16, fontWeight: pw.FontWeight.bold),
                    ),
                  ],
                ),
              pw.SizedBox(height: 20),

              // **Table with Attendance Percentage**
              pw.Table.fromTextArray(
                headers: [
                  'ID',
                  'Name',
                  ...monthsToShow
                      .map((month) => '${DateFormat('MMM yyyy').format(month)}')
                      .toList(),
                  'Total Periods',
                  'Attendance %'
                ],
                data: students.map((data) {
                  int totalAttended = 0;
                  List<int> attendedPerMonth = [];
                  List<String> percentagePerMonth = [];

                  for (var month in monthsToShow) {
                    int attended =
                        getTotalAttendedPeriodsInMonth(data['id'], month);
                    int monthTotalPeriods = getAllWorkingDaysInMonth(month);

                    attendedPerMonth.add(attended);

                    double percentage = monthTotalPeriods == 0
                        ? 0
                        : (attended / (monthTotalPeriods * 3)) * 100;
                    percentagePerMonth.add(percentage.toStringAsFixed(2));

                    totalAttended += attended;
                  }

                  int totalPeriods = monthsToShow.fold(
                      0, (sum, month) => sum + getAllWorkingDaysInMonth(month));

                  double avgPercentage = totalPeriods == 0
                      ? 0
                      : (totalAttended / (totalPeriods * 3)) * 100;

                  return [
                    data['id'],
                    data['name'],
                    ...attendedPerMonth,
                    totalAttended,
                    avgPercentage.toStringAsFixed(2),
                  ];
                }).toList(),
              ),
            ],
          );
        },
      ),
    );

    // Define base filename
    String baseFileName = (selectedSubject.isNotEmpty &&
            selectedSubject != "---")
        ? "attendance_report_${monthName.toLowerCase()}_${year}_${selectedSubject.replaceAll('/', '_')}"
        : "attendance_report_${monthName.toLowerCase()}_${year}";

    String fileName = "$baseFileName.pdf";

    // Get user-selected directory
    String? outputDir = await FilePicker.platform.getDirectoryPath();
    if (outputDir == null) {
      print("No directory selected.");
      return;
    }

    // Ensure the directory exists
    Directory directory = Directory(outputDir);
    if (!directory.existsSync()) {
      try {
        directory.createSync(recursive: true);
      } catch (e) {
        print("Error creating directory: $e");
        return;
      }
    }

    // Construct the file path
    File file = File("${directory.path}/$fileName");

    // Ensure unique filename if file already exists
    int counter = 1;
    while (file.existsSync()) {
      fileName = "$baseFileName($counter).pdf";
      file = File("${directory.path}/$fileName");
      counter++;
    }

    try {
      await file.writeAsBytes(await pdf.save());
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("PDF saved to ${file.path}")),
      );
      OpenFile.open(file.path);
    } catch (e) {
      print("Error writing file: $e");
    }
  }

  Future<void> pickMonth(BuildContext context) async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime(selectedMonth.year, selectedMonth.month, 1),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      selectableDayPredicate: (day) =>
          day.day == 1 && day.isBefore(DateTime.now().add(Duration(days: 1))),
    );

    if (pickedDate != null) {
      setState(() {
        if (isMultipleSelection) {
          initialDate:
          null;
          selectedMonths.add(DateTime(pickedDate.year, pickedDate.month));
        } else {
          selectedMonth = DateTime(pickedDate.year, pickedDate.month);
          selectedMonths = {selectedMonth}; // Reset multiple selection
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    String selectedText = isMultipleSelection
        ? (selectedMonths.isEmpty
            ? 'Select Months'
            : selectedMonths
                .map((m) => DateFormat('MMMM yyyy').format(m))
                .join(', '))
        : DateFormat('MMMM yyyy').format(selectedMonth);

    return Scaffold(
      appBar: AppBar(
        title: Text('Attendance Report'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Toggle Selection Mode
            Center(
              child: ToggleButtons(
                borderRadius: BorderRadius.circular(10),
                isSelected: [!isMultipleSelection, isMultipleSelection],
                onPressed: (index) {
                  setState(() {
                    isMultipleSelection = index == 1;
                    selectedMonths.clear();
                    selectedMonths.add(selectedMonth);
                  });
                },
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text('Single Month'),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text('Multiple Months'),
                  ),
                ],
              ),
            ),

            SizedBox(height: 20),

            // Month Selection UI
            Center(
              child: Column(
                children: [
                  ElevatedButton.icon(
                    onPressed: () => pickMonth(context),
                    icon: Icon(Icons.calendar_today),
                    label: Text(isMultipleSelection
                        ? 'Select Months'
                        : 'Select Month: ${DateFormat('MMMM yyyy').format(selectedMonth)}'),
                    style: ElevatedButton.styleFrom(
                      padding:
                          EdgeInsets.symmetric(vertical: 12, horizontal: 24),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),

                  // Show Selected Months List if Multiple Selection is Enabled
                  if (isMultipleSelection && selectedMonths.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Wrap(
                        spacing: 8.0,
                        children: selectedMonths.map((month) {
                          return Chip(
                            label: Text(DateFormat('MMM yyyy').format(month)),
                            backgroundColor:
                                const Color.fromARGB(255, 0, 140, 255),
                            deleteIcon: Icon(Icons.close, size: 18),
                            onDeleted: () {
                              setState(() {
                                selectedMonths.remove(month);
                              });
                            },
                          );
                        }).toList(),
                      ),
                    ),

                  // Clear Button for Multiple Months
                  if (isMultipleSelection && selectedMonths.isNotEmpty)
                    TextButton.icon(
                      onPressed: () {
                        setState(() {
                          selectedMonths.clear();
                          selectedMonth = DateTime.now();
                        });
                      },
                      icon: Icon(Icons.clear, color: Colors.red),
                      label: Text("Clear Selection",
                          style: TextStyle(color: Colors.red)),
                    ),
                ],
              ),
            ),
            SizedBox(height: 20),
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 16,
                      runSpacing: 16,
                      children: [
                        DropdownButton<String>(
                          value: selectedDept,
                          isExpanded: true,
                          items: departments
                              .map((dept) => DropdownMenuItem(
                                    value: dept,
                                    child: Text(dept),
                                  ))
                              .toList(),
                          onChanged: (value) {
                            setState(() {
                              selectedDept = value!;
                              fetchStudents();
                              fetchTimetable();
                            });
                          },
                        ),
                        DropdownButton<String>(
                          value: selectedSemester,
                          isExpanded: true,
                          items: semesters
                              .map((sem) => DropdownMenuItem(
                                    value: sem,
                                    child: Text(sem),
                                  ))
                              .toList(),
                          onChanged: (value) {
                            setState(() {
                              selectedSemester = value!;
                              fetchStudents();
                              fetchTimetable();
                            });
                          },
                        ),
                        DropdownButton<String>(
                          value: subjectsList.contains(selectedSubject)
                              ? selectedSubject
                              : "---",
                          isExpanded: true,
                          onChanged: (String? newValue) {
                            setState(() {
                              selectedSubject = newValue!;
                            });
                            fetchAttendanceData();
                          },
                          items: [
                            DropdownMenuItem<String>(
                              value: "---",
                              child: Text("All Subjects"),
                            ),
                            ...subjectsList
                                .where((subject) =>
                                    subject != "---") // Avoid duplicate "---"
                                .map<DropdownMenuItem<String>>((String value) {
                              return DropdownMenuItem<String>(
                                value: value,
                                child: Text(value),
                              );
                            }).toList(),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    scrollDirection:
                        Axis.horizontal, // Enables horizontal scrolling
                    child: ConstrainedBox(
                      constraints:
                          BoxConstraints(minWidth: constraints.maxWidth),
                      child: SingleChildScrollView(
                        scrollDirection:
                            Axis.vertical, // Enables vertical scrolling
                        child: DataTable(
                          border: TableBorder.all(
                            color: const Color.fromARGB(168, 0, 163, 245),
                            borderRadius: BorderRadius.circular(13),
                          ),
                          columns: [
                            DataColumn(
                              label: Text("Name",
                                  style:
                                      TextStyle(fontWeight: FontWeight.bold)),
                            ),
                            DataColumn(
                              label: Text("Attendance %",
                                  style:
                                      TextStyle(fontWeight: FontWeight.bold)),
                            ),
                          ],
                          rows: students.isEmpty
                              ? []
                              : students.map((student) {
                                  int attended =
                                      getTotalAttendedPeriods(student['id']);
                                  int totalPeriods = getTotalPeriods();
                                  double percentage = totalPeriods == 0
                                      ? 0
                                      : (attended / totalPeriods) * 100;

                                  return DataRow(cells: [
                                    DataCell(Text(student['name'])),
                                    DataCell(Text(
                                        "${percentage.toStringAsFixed(2)}%")),
                                  ]);
                                }).toList(),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            SizedBox(height: 20),
            Center(
              child: ElevatedButton(
                onPressed: students.isNotEmpty ? _generatePDF : null,
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text('Download PDF', style: TextStyle(fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
