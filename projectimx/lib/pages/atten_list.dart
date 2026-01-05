import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart'; // For date formatting

class AttendanceSearchPage extends StatefulWidget {
  @override
  _AttendanceSearchPageState createState() => _AttendanceSearchPageState();
}

class _AttendanceSearchPageState extends State<AttendanceSearchPage> {
  String selectedDept = "Computer Engineering";
  String selectedSemester = "Sem 6";
  String selectedStudent = ""; // Selected student name
  DateTime selectedMonth = DateTime.now();
  List<String> subjectsList = [];
  String selectedSubject = "";
  List<Map<String, dynamic>> absentees = [];
  List<Map<String, dynamic>> filteredAbsentees = [];
  List<Map<String, dynamic>> timetableRecords = [];
  String? Just;
  List<String> subjectAbsentDays = [];

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
  List<String> studentNames = [];
  List<Map<String, dynamic>> attendanceRecords = [];
  List<String> holidayList = [];
  bool isLoading = true;
  String errorMessage = "";

  @override
  void initState() {
    super.initState();
    fetchAttendanceData();
    fetchStudents();
    fetchTimetable();
  }

  Future<void> fetchTimetable() async {
    try {
      QuerySnapshot querySnapshot = await FirebaseFirestore.instance
          .collection("timetable")
          .where("branch", isEqualTo: selectedDept)
          .where("semester", isEqualTo: selectedSemester)
          .get();

      setState(() {
        timetableRecords = querySnapshot.docs
            .map((doc) => doc.data() as Map<String, dynamic>)
            .toList();
      });
    } catch (e) {}
  }

  Future<void> fetchAttendanceData() async {
    setState(() => isLoading = true);
    try {
      // ✅ Step 1: Fetch Attendance Records (Ensure composite index exists)
      DateTime nextMonthStart =
          DateTime(selectedMonth.year, selectedMonth.month + 1, 1);
      DateTime monthEnd = nextMonthStart.subtract(Duration(days: 1));

      Query attendanceQuery = FirebaseFirestore.instance
          .collection('attendance')
          .where('department', isEqualTo: selectedDept)
          .where('semester', isEqualTo: selectedSemester)
          .where('timestamp',
              isGreaterThanOrEqualTo: Timestamp.fromDate(
                  DateTime(selectedMonth.year, selectedMonth.month, 1)))
          .where('timestamp',
              isLessThanOrEqualTo: Timestamp.fromDate(monthEnd));

      if (selectedSubject.isNotEmpty && selectedSubject != "---") {
        attendanceQuery =
            attendanceQuery.where('subject', isEqualTo: selectedSubject);
      }

      final attendanceSnapshot = await attendanceQuery.get();
      List<Map<String, dynamic>> fetchedAttendance = attendanceSnapshot.docs
          .map((doc) => doc.data() as Map<String, dynamic>)
          .toList();

      // ✅ Step 2: Fetch Timetable for the Subject
      QuerySnapshot timetableSnapshot = await FirebaseFirestore.instance
          .collection('timetable')
          .where('branch', isEqualTo: selectedDept)
          .where('semester', isEqualTo: selectedSemester)
          .get();

      List<Map<String, dynamic>> timetableRecords = timetableSnapshot.docs
          .map((doc) => doc.data() as Map<String, dynamic>)
          .toList();

      Set<String> scheduledDays = {};
      Set<String> allSubjects = {};

      for (var record in timetableRecords) {
        for (var period in record['periods']) {
          allSubjects.add(period['subject']);
          if (selectedSubject.isNotEmpty &&
              selectedSubject != "---" &&
              period['subject'] == selectedSubject) {
            scheduledDays.add(record['day']);
          }
        }
      }

      // ✅ Step 3: Extract Present Days from Attendance Records
      Set<String> presentDays = fetchedAttendance
          .map((record) =>
              DateFormat('yyyy-MM-dd').format(record['timestamp'].toDate()))
          .toSet();

      // ✅ Step 4: Identify Absent Days (Only Timetable Days)
      List<String> allWorkingDays = generateWorkingDaysForMonth(selectedMonth);
      List<String> subjectWorkingDays = allWorkingDays
          .where((day) => scheduledDays.contains(getDayFromDate(day)))
          .toList();

      DateTime today = DateTime.now();
      String todayStr = DateFormat('yyyy-MM-dd').format(today);
      List<String> pastWorkingDays = subjectWorkingDays
          .where((day) => day.compareTo(todayStr) < 0)
          .toList();
      String lastWorkingDay =
          pastWorkingDays.isNotEmpty ? pastWorkingDays.last : todayStr;

      List<String> absentDays =
          pastWorkingDays.where((day) => !presentDays.contains(day)).toList();

      List<String> subjectAbsentDaysFiltered = (selectedSubject.isNotEmpty &&
              selectedSubject != "---")
          ? absentDays
          : allWorkingDays.where((day) => !presentDays.contains(day)).toList();
      print(selectedStudent);

      // ✅ Step 5: Update State
      setState(() {
        attendanceRecords = fetchedAttendance;
        subjectsList = ["---", ...allSubjects.toList()];
        errorMessage = attendanceRecords.isEmpty
            ? "No attendance data found for this month."
            : "";
        subjectAbsentDays = subjectAbsentDaysFiltered;
      });
    } catch (e) {
      setState(() => errorMessage = 'Error fetching attendance data: $e');
    } finally {
      setState(() => isLoading = false);
    }
  }

// Function to return subject-specific or all absent days
  List<String> getSubjectAbsentDays() {
    return subjectAbsentDays;
  }

// Function to generate all working days of the month (Excluding Saturdays & Sundays)
  List<String> generateWorkingDaysForMonth(DateTime month) {
    List<String> workingDays = [];
    DateTime startDate = DateTime(month.year, month.month, 1);
    DateTime endDate = DateTime(month.year, month.month + 1, 0);

    for (DateTime day = startDate;
        day.isBefore(endDate) || day.isAtSameMomentAs(endDate);
        day = day.add(Duration(days: 1))) {
      if (day.weekday != DateTime.saturday && day.weekday != DateTime.sunday) {
        workingDays.add(DateFormat('yyyy-MM-dd').format(day));
      }
    }
    return workingDays;
  }

// Function to convert Date to Day Name
  String getDayFromDate(String dateString) {
    DateTime date = DateFormat('yyyy-MM-dd').parse(dateString);
    return DateFormat('EEEE').format(date);
  }

  int getTotalAttendedPeriods() {
    return attendanceRecords
        .where((record) => record['name'] == selectedStudent)
        .fold(0, (sum, record) => sum + int.parse(record['periods'] ?? "0"));
  }

  int getTotalMissedPeriods() {
    DateTime today = DateTime.now();

    // Filter working days that are only up to today's date
    int totalPeriods = getAllWorkingDays()
            .where((day) =>
                DateTime.parse(day).isBefore(today) ||
                DateTime.parse(day).isAtSameMomentAs(today))
            .length *
        3; // Assuming 3 periods per day
    return totalPeriods - getTotalAttendedPeriods();
  }

  int getTotalPeriods() {
    DateTime today = DateTime.now();
    int totalPeriods = getAllWorkingDays()
            .where((day) =>
                DateTime.parse(day).isBefore(today) ||
                DateTime.parse(day).isAtSameMomentAs(today))
            .length *
        3;
    return totalPeriods;
  }

  Future<void> fetchStudents() async {
    setState(() => isLoading = true);
    try {
      final studentsQuery = await FirebaseFirestore.instance
          .collection('users')
          .where('department', isEqualTo: selectedDept)
          .where('semester', isEqualTo: selectedSemester)
          .get();

      setState(() {
        studentNames = studentsQuery.docs
            .map((doc) => doc.data()['name'].toString())
            .toList();
        errorMessage = studentNames.isEmpty ? "No students found." : "";
        selectedStudent = ""; // Reset selection
      });
    } catch (e) {
      setState(() => errorMessage = 'Error fetching students: $e');
    } finally {
      setState(() => isLoading = false);
    }
  }

  List<String> getAllWorkingDays() {
    DateTime firstDayOfMonth =
        DateTime(selectedMonth.year, selectedMonth.month, 1);
    DateTime lastDayOfMonth =
        DateTime(selectedMonth.year, selectedMonth.month + 1, 0);
    DateTime today = DateTime.now();
    // Ensure the last day does not go beyond today
    if (lastDayOfMonth.isAfter(today)) {
      lastDayOfMonth = today;
    }
    List<String> workingDays = [];
    DateTime currentDate = firstDayOfMonth;
    while (currentDate.isBefore(lastDayOfMonth) ||
        currentDate.isAtSameMomentAs(lastDayOfMonth)) {
      if (currentDate.weekday != DateTime.saturday &&
          currentDate.weekday != DateTime.sunday &&
          !holidayList.contains(DateFormat('yyyy-MM-dd').format(currentDate))) {
        workingDays.add(DateFormat('yyyy-MM-dd').format(currentDate));
      }
      currentDate = currentDate.add(Duration(days: 1));
    }
    return workingDays;
  }

  String getLastWorkingDay() {
    DateTime today = DateTime.now();
    while (today.weekday == DateTime.saturday ||
        today.weekday == DateTime.sunday) {
      today = today.subtract(Duration(days: 1));
    }
    return DateFormat('yyyy-MM-dd').format(today);
  }

  List<String> getAbsentDays() {
    List<String> workingDays = getAllWorkingDays();
    String lastWorkingDay = getLastWorkingDay();

    // Filter only past working days up to today
    List<String> filteredWorkingDays =
        workingDays.where((day) => day.compareTo(lastWorkingDay) <= 0).toList();

    // Extract present days from attendance records
    List<String> presentDays = attendanceRecords
        .where((record) =>
            record['name'] == selectedStudent &&
            record['time_in'] != null &&
            record['date'] != null)
        .map((record) {
      DateTime parsedDate = DateFormat('yyyy-M-d').parse(record['date']);
      return DateFormat('yyyy-MM-dd').format(parsedDate);
    }).toList();

    // Find absent days
    return filteredWorkingDays
        .where((day) => !presentDays.contains(day))
        .toList();
  }

  List<String> getPresentDays() {
    List<String> workingDays = getAllWorkingDays();
    List<String> presentDays = attendanceRecords
        .where((record) =>
            record['name'] == selectedStudent &&
            record['time_in'] != null &&
            record['date'] != null)
        .map((record) {
      DateTime parsedDate = DateFormat('yyyy-M-d').parse(record['date']);
      return DateFormat('yyyy-MM-dd').format(parsedDate);
    }).toList();
    return workingDays.where((day) => presentDays.contains(day)).toList();
  }

  Future<void> pickMonth(BuildContext context) async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime(selectedMonth.year, selectedMonth.month,
          1), // Ensure it's the first day of the month
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      // Allow only the first day of each month to be selectable
      selectableDayPredicate: (day) =>
          day.day == 1 && day.isBefore(DateTime.now().add(Duration(days: 1))),
    );

    if (pickedDate != null) {
      setState(() {
        // Save only the month and year from the picked date
        selectedMonth = DateTime(pickedDate.year, pickedDate.month);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Attendance Search')),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: SingleChildScrollView(
                // 🔹 Wrap the Column
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          children: [
                            Text(
                              "Selected Month: ${DateFormat('MMMM yyyy').format(selectedMonth)}",
                              style: TextStyle(fontSize: 16),
                            ),
                            Spacer(),
                            ElevatedButton(
                              onPressed: () => pickMonth(context),
                              child: Text('Pick Month'),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: 20),
                    Card(
                      elevation: 5,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          children: [
                            DropdownButtonFormField<String>(
                              value: selectedDept,
                              decoration:
                                  InputDecoration(labelText: "Department"),
                              onChanged: (value) {
                                setState(() {
                                  selectedDept = value!;
                                  fetchStudents();
                                });
                              },
                              items: departments
                                  .map((dept) => DropdownMenuItem(
                                      value: dept, child: Text(dept)))
                                  .toList(),
                            ),
                            SizedBox(width: 10),
                            DropdownButtonFormField<String>(
                              value: selectedSemester,
                              decoration:
                                  InputDecoration(labelText: "Semester"),
                              onChanged: (value) {
                                setState(() {
                                  selectedSemester = value!;
                                  fetchStudents();
                                });
                              },
                              items: semesters
                                  .map((sem) => DropdownMenuItem(
                                      value: sem, child: Text(sem)))
                                  .toList(),
                            ),
                            SizedBox(height: 20),
                            DropdownButtonFormField<String>(
                              value: selectedStudent.isEmpty
                                  ? null
                                  : selectedStudent,
                              decoration: InputDecoration(labelText: "Student"),
                              onChanged: (value) {
                                setState(() {
                                  selectedStudent = value!;
                                });
                              },
                              items: studentNames
                                  .map((name) => DropdownMenuItem(
                                      value: name, child: Text(name)))
                                  .toList(),
                            ),
                            SizedBox(height: 20),
                            DropdownButtonFormField<String>(
                              value: subjectsList.contains(selectedSubject)
                                  ? selectedSubject
                                  : null,
                              decoration: InputDecoration(labelText: "Subject"),
                              onChanged: (String? newValue) {
                                setState(() {
                                  selectedSubject = newValue!;
                                });
                                fetchAttendanceData();
                              },
                              items: subjectsList.map((value) {
                                return DropdownMenuItem<String>(
                                  value: value,
                                  child: Text(
                                      value == "---" ? "All Subjects" : value),
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: 20),
                    Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          children: [
                            Text("Attendance Summary",
                                style: TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 18)),
                            Divider(),
                            Table(
                              border: TableBorder.all(),
                              columnWidths: {
                                0: FlexColumnWidth(2),
                                1: FlexColumnWidth(1)
                              },
                              children: [
                                _tableRow("Total Working Days",
                                    getAllWorkingDays().length.toString()),
                                _tableRow("Total Absent Days",
                                    getAbsentDays().length.toString()),
                                _tableRow("Total Periods",
                                    getTotalPeriods().toString()),
                                _tableRow("Total Periods Attended",
                                    getTotalAttendedPeriods().toString()),
                                _tableRow("Total Periods Missed",
                                    getTotalMissedPeriods().toString()),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: 20),

                    // Detailed Attendance Table
                    if (selectedStudent.isNotEmpty)
                      Card(
                        elevation: 4,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            children: [
                              Text("Detailed Attendance",
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18)),
                              Divider(),
                              _detailedAttendanceTable("Present Days",
                                  getPresentDays(), Icons.check, Colors.green),
                              _detailedAttendanceTable(
                                  selectedSubject == "---"
                                      ? "Absent Days (Overall)"
                                      : "Absent Days for $selectedSubject",
                                  getAbsentDays(),
                                  Icons.cancel,
                                  Colors.red),
                            ],
                          ),
                        ),
                      ),
                    if (errorMessage.isNotEmpty)
                      Center(
                          child: Text(errorMessage,
                              style: TextStyle(color: Colors.red))),
                  ],
                ),
              ),
            ),
    );
  }

  TableRow _tableRow(String category, String count) {
    return TableRow(
      children: [
        Padding(padding: EdgeInsets.all(8.0), child: Text(category)),
        Padding(padding: EdgeInsets.all(8.0), child: Text(count)),
      ],
    );
  }

  Widget _detailedAttendanceTable(
      String title, List<String> dates, IconData icon, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        SizedBox(height: 5),
        Table(
          border: TableBorder.all(),
          columnWidths: {0: FlexColumnWidth(3), 1: FlexColumnWidth(1)},
          children: dates
              .map((date) => TableRow(children: [
                    Padding(padding: EdgeInsets.all(8.0), child: Text(date)),
                    Icon(icon, color: color),
                  ]))
              .toList(),
        ),
      ],
    );
  }
}
