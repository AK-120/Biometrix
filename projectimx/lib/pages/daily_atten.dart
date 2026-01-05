import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class DateWiseReport extends StatefulWidget {
  @override
  _DateWiseReportState createState() => _DateWiseReportState();
}

class _DateWiseReportState extends State<DateWiseReport> {
  String selectedDate = "";
  String selectedDepartment = "Computer Engineering";
  String selectedSemester = "Sem 6";

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
  List<Map<String, dynamic>> _attendanceData = [];

  @override
  void initState() {
    super.initState();
    _initializeDate();
  }

  Future<void> _initializeDate() async {
    String today = DateFormat('yyyy-M-d').format(DateTime.now());
    String lastWorkingDay = await getLastWorkingDay(today);
    setState(() {
      selectedDate = lastWorkingDay;
    });
    await fetchAttendance(); // Fetch attendance immediately
  }

  Future<String> getLastWorkingDay(String date) async {
    DateTime parsedDate = DateFormat('yyyy-M-d').parse(date);
    DocumentSnapshot holidayDoc =
        await FirebaseFirestore.instance.collection('holidays').doc(date).get();

    // If today is not a holiday and not a weekend, return it directly
    if (!holidayDoc.exists &&
        parsedDate.weekday != DateTime.saturday &&
        parsedDate.weekday != DateTime.sunday) {
      return date;
    }

    // Otherwise, find the last working day
    while (true) {
      parsedDate = parsedDate.subtract(Duration(days: 1));
      String previousDate = DateFormat('yyyy-M-d').format(parsedDate);
      DocumentSnapshot prevHolidayDoc = await FirebaseFirestore.instance
          .collection('holidays')
          .doc(previousDate)
          .get();
      if (!prevHolidayDoc.exists &&
          parsedDate.weekday != DateTime.saturday &&
          parsedDate.weekday != DateTime.sunday) {
        return previousDate;
      }
    }
  }

  Future<void> fetchAttendance() async {
    print("Fetching attendance for: $selectedDate");
    QuerySnapshot querySnapshot = await FirebaseFirestore.instance
        .collection('attendance')
        .where('date', isEqualTo: selectedDate)
        .where('department', isEqualTo: selectedDepartment)
        .where('semester', isEqualTo: selectedSemester)
        .get();

    setState(() {
      _attendanceData = querySnapshot.docs
          .map((doc) => doc.data() as Map<String, dynamic>)
          .toList();
    });

    print("Attendance records found: ${_attendanceData.length}");
  }

  Future<void> generateAndSharePDF() async {
    if (_attendanceData.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("No attendance records found!")));
      return;
    }

    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text("Attendance Report",
                  style: pw.TextStyle(
                      fontSize: 20, fontWeight: pw.FontWeight.bold)),
              pw.Text("Date: $selectedDate"),
              pw.Text("Department: $selectedDepartment"),
              pw.Text("Semester: $selectedSemester"),
              pw.SizedBox(height: 10),
              pw.Table.fromTextArray(
                border: pw.TableBorder.all(),
                headers: ["Name", "Time In", "Time Out", "Subject", "Periods"],
                data: _attendanceData
                    .map((record) => [
                          record['name'],
                          record['time_in'],
                          record['time_out'] ?? 'N/A',
                          record['subject'],
                          record['periods'] ?? "-"
                        ])
                    .toList(),
              ),
            ],
          );
        },
      ),
    );

    final output = await getTemporaryDirectory();
    final file = File("${output.path}/Attendance_Report.pdf");
    await file.writeAsBytes(await pdf.save());

    Share.shareXFiles([XFile(file.path)],
        text: "Attendance Report for $selectedDate");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Attendance Report"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Date Picker Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: () async {
                  DateTime? pickedDate = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now(),
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                  );
                  if (pickedDate != null) {
                    String newDate = DateFormat('yyyy-M-d').format(pickedDate);
                    String finalDate = await getLastWorkingDay(newDate);
                    setState(() => selectedDate = finalDate);
                    await fetchAttendance();
                  }
                },
                icon: Icon(Icons.calendar_today, size: 20),
                label:
                    Text(selectedDate.isEmpty ? "Select Date" : selectedDate),
              ),
            ),
            SizedBox(height: 16),

            // Dropdowns (Department & Semester)
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: selectedDepartment,
                    decoration: InputDecoration(
                      labelText: "Department",
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8)),
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 6, vertical: 14),
                    ),
                    items: departments
                        .map((dept) =>
                            DropdownMenuItem(value: dept, child: Text(dept)))
                        .toList(),
                    onChanged: (value) {
                      setState(() => selectedDepartment = value!);
                      fetchAttendance();
                    },
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: selectedSemester,
                    decoration: InputDecoration(
                      labelText: "Semester",
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8)),
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                    ),
                    items: semesters
                        .map((sem) =>
                            DropdownMenuItem(value: sem, child: Text(sem)))
                        .toList(),
                    onChanged: (value) {
                      setState(() => selectedSemester = value!);
                      fetchAttendance();
                    },
                  ),
                ),
              ],
            ),
            SizedBox(height: 20),

            // Attendance Data Table
            Expanded(
              child: _attendanceData.isEmpty
                  ? Center(
                      child: Text("No records found for $selectedDate",
                          style: TextStyle(fontSize: 16, color: Colors.grey)),
                    )
                  : SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        columnSpacing: 25,
                        columns: const [
                          DataColumn(
                              label: Text('Name',
                                  style:
                                      TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(
                              label: Text('Time In',
                                  style:
                                      TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(
                              label: Text('Time Out',
                                  style:
                                      TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(
                              label: Text('Subject',
                                  style:
                                      TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(
                              label: Text('Periods',
                                  style:
                                      TextStyle(fontWeight: FontWeight.bold))),
                        ],
                        rows: _attendanceData.map((record) {
                          return DataRow(
                            cells: [
                              DataCell(Text(record['name'])),
                              DataCell(Text(record['time_in'])),
                              DataCell(Text(record['time_out'] ?? "N/A")),
                              DataCell(Text(record['subject'])),
                              DataCell(Text(record['periods'] ?? "-")),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
            ),
          ],
        ),
      ),

      // Floating Button (Share Report)
      floatingActionButton: FloatingActionButton(
        onPressed: generateAndSharePDF,
        child: Icon(Icons.send),
      ),
    );
  }
}
