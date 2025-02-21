import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class EditAttendancePage extends StatefulWidget {
  @override
  _EditAttendancePageState createState() => _EditAttendancePageState();
}

class _EditAttendancePageState extends State<EditAttendancePage> {
  DateTime selectedDate = DateTime.now();
  String? selectedSemester;
  String? selectedDepartment;
  String? selectedStudent;
  String? selectedSubject;
  String? checkInTime;
  String? checkOutTime;
  String? actionType; // Add or Edit
  bool isLoading = false;

  final List<String> semesters = [
    "Sem 1",
    "Sem 2",
    "Sem 3",
    "Sem 4",
    "Sem 5",
    "Sem 6"
  ];
  final List<String> departments = [
    "Computer Engineering",
    "Electronics Engineering",
    "Printing Technology"
  ];

  List<Map<String, String>> students = [];
  List<Map<String, String>> subjects = [];

  void fetchStudents() async {
    if (selectedDepartment != null && selectedSemester != null) {
      setState(() {
        isLoading = true;
        students = [];
      });

      try {
        QuerySnapshot snapshot = await FirebaseFirestore.instance
            .collection('users')
            .where('user_type', isEqualTo: 'Student')
            .where('department', isEqualTo: selectedDepartment)
            .where('semester', isEqualTo: selectedSemester)
            .get();

        setState(() {
          students = snapshot.docs
              .map((doc) =>
                  {"name": doc['name'].toString(), "id": doc['id'].toString()})
              .toList();
        });
      } catch (e) {
        print("Error fetching students: $e");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error fetching students!')),
        );
      } finally {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  void fetchSubjects() async {
    if (selectedDepartment != null && selectedSemester != null) {
      setState(() {
        isLoading = true;
      });

      String day = DateFormat('EEEE').format(selectedDate); // Get the day
      print(day);
      try {
        QuerySnapshot timetableSnapshot = await FirebaseFirestore.instance
            .collection('timetable')
            .where('branch', isEqualTo: selectedDepartment)
            .where('semester', isEqualTo: selectedSemester)
            .where('day', isEqualTo: day)
            .get();

        if (timetableSnapshot.docs.isNotEmpty) {
          var periods = timetableSnapshot.docs.first['periods'] as List;
          setState(() {
            subjects = periods
                .map((p) => {
                      "subject": p["subject"].toString(),
                      "time": p["time"].toString()
                    })
                .toList();
          });
        } else {
          setState(() {
            subjects = [];
          });
        }
      } catch (e) {
        print("Error fetching subjects: $e");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error fetching subjects!')),
        );
      } finally {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  void updateCheckInOutTime(String subject) {
    var subjectData = subjects.firstWhere((s) => s["subject"] == subject);
    List<String> times = subjectData["time"]!.split(" - ");

    // Remove AM/PM
    String formatTime(String time) {
      return time.replaceAll(RegExp(r'\s?(AM|PM)'), '').trim();
    }

    setState(() {
      checkInTime = formatTime(times[0]);
      checkOutTime = formatTime(times[1]);
    });
  }

  Future<Map<String, dynamic>?> getAttendanceData(
      String studentId, String date) async {
    final attendanceRef = FirebaseFirestore.instance.collection('attendance');
    final querySnapshot = await attendanceRef
        .where('id', isEqualTo: studentId)
        .where('date', isEqualTo: date)
        .get();

    if (querySnapshot.docs.isNotEmpty) {
      return querySnapshot.docs.first.data(); // Return the first matched record
    }
    return null; // No data found
  }

  void showEditAttendanceDialog(
      BuildContext context, String studentId, String date) async {
    Map<String, dynamic>? attendanceData =
        await getAttendanceData(studentId, date);

    if (attendanceData != null) {
      TextEditingController checkInController =
          TextEditingController(text: attendanceData['time_in']);
      TextEditingController checkOutController =
          TextEditingController(text: attendanceData['time_out']);

      showDialog(
        context: context,
        builder: (BuildContext dialogContext) {
          return AlertDialog(
            title: Text('Edit Attendance'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: checkInController,
                  decoration: InputDecoration(labelText: "Check-In Time"),
                ),
                TextField(
                  controller: checkOutController,
                  decoration: InputDecoration(labelText: "Check-Out Time"),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: Text("Cancel"),
              ),
              ElevatedButton(
                onPressed: () async {
                  bool success = await updateAttendance(studentId, date,
                      checkInController.text, checkOutController.text);

                  Navigator.pop(dialogContext); // Close the edit dialog

                  if (success) {
                    // Show pop-up message when attendance is updated successfully
                    showDialog(
                      context: context,
                      builder: (BuildContext successDialogContext) {
                        return AlertDialog(
                          title: Text('Success'),
                          content: Text('Attendance updated successfully!'),
                          actions: [
                            TextButton(
                              onPressed: () =>
                                  Navigator.pop(successDialogContext),
                              child: Text("OK"),
                            ),
                          ],
                        );
                      },
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed to update attendance!')),
                    );
                  }
                },
                child: Text("Save"),
              ),
            ],
          );
        },
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No attendance record found!')),
      );
    }
  }

  Future<bool> updateAttendance(
      String studentId, String date, String checkIn, String checkOut) async {
    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('attendance')
          .where('id', isEqualTo: studentId)
          .where('date', isEqualTo: date)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        await querySnapshot.docs.first.reference.update({
          'time_in': checkIn,
          'time_out': checkOut,
          'periods': null,
        });
        return true; // Successfully updated
      } else {
        return false; // No record found
      }
    } catch (error) {
      print("Failed to update attendance: $error");
      return false;
    }
  }

  void addAttendance() async {
    if (selectedStudent != null && selectedSubject != null) {
      String formattedDate = DateFormat('yyyy-M-dd').format(selectedDate);
      String? studentId = students
          .firstWhere((student) => student["name"] == selectedStudent)["id"];
      TimeOfDay checkInParsed = TimeOfDay(
        hour: int.parse(checkInTime!.split(":")[0]),
        minute: int.parse(checkInTime!.split(":")[1].split(" ")[0]),
      );
      DateTime checkInDateTime = DateTime(
        selectedDate.year,
        selectedDate.month,
        selectedDate.day,
        checkInParsed.hour,
        checkInParsed.minute,
      );
      try {
        QuerySnapshot attendanceRecords = await FirebaseFirestore.instance
            .collection('attendance')
            .where('name', isEqualTo: selectedStudent)
            .where('date', isEqualTo: formattedDate)
            .where('department', isEqualTo: selectedDepartment)
            .where('semester', isEqualTo: selectedSemester)
            .get();

        if (attendanceRecords.docs.isEmpty) {
          await FirebaseFirestore.instance.collection('attendance').add({
            'id': studentId,
            'name': selectedStudent,
            'department': selectedDepartment,
            'semester': selectedSemester,
            'date': formattedDate,
            'time_in': checkInTime,
            'time_out': checkOutTime,
            'user_type': "Student",
            'subject': selectedSubject,
            'timestamp': checkInDateTime,
            'periods': null,
          });

          showPopup("Success", "Attendance added successfully!");
        } else {
          showPopup(
              "Duplicate Entry", "Attendance already exists for this student!");
        }
      } catch (e) {
        print("Error adding attendance: $e");
        showPopup("Error", "Error adding attendance!");
      }
    } else {
      showPopup("Missing Fields", "Please select all fields!");
    }
  }

  void showPopup(String title, String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text("OK"),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Attendance Management')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Wrap(
            spacing: 10.0,
            runSpacing: 10.0,
            children: [
              Card(
                elevation: 4.0,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      DropdownButtonFormField(
                        decoration: InputDecoration(labelText: "Select Action"),
                        value: "Edit", // Setting the default value
                        items: [
                          DropdownMenuItem(
                            value: "Add",
                            child: Text("Add Attendance"),
                          ),
                          DropdownMenuItem(
                            value: "Edit",
                            child: Text("Edit Attendance"),
                          ),
                        ],
                        onChanged: (value) {
                          setState(() {
                            actionType = value.toString();
                            selectedStudent = null;
                            checkInTime = null;
                            checkOutTime = null;
                          });
                        },
                      ),
                      if (actionType != null) ...[
                        ListTile(
                          title: Text(
                              "Date: ${DateFormat('yyyy-M-dd').format(selectedDate)}"),
                          trailing: Icon(Icons.calendar_today),
                          onTap: () async {
                            DateTime? pickedDate = await showDatePicker(
                              context: context,
                              initialDate: selectedDate,
                              firstDate: DateTime(2022),
                              lastDate: DateTime(2030),
                            );
                            if (pickedDate != null) {
                              setState(() {
                                selectedDate = pickedDate;
                                fetchStudents();
                                fetchSubjects();
                              });
                            }
                          },
                        ),
                        DropdownButtonFormField(
                          decoration:
                              InputDecoration(labelText: "Select Semester"),
                          items: semesters
                              .map((sem) => DropdownMenuItem(
                                  value: sem, child: Text("$sem")))
                              .toList(),
                          onChanged: (value) {
                            setState(() {
                              selectedSemester = value.toString();
                              selectedStudent = null;
                              fetchStudents();
                            });
                          },
                        ),
                        DropdownButtonFormField(
                          decoration:
                              InputDecoration(labelText: "Select Department"),
                          items: departments
                              .map((dept) => DropdownMenuItem(
                                  value: dept, child: Text(dept)))
                              .toList(),
                          onChanged: (value) {
                            setState(() {
                              selectedDepartment = value.toString();
                              selectedStudent = null;
                              fetchStudents();
                            });
                          },
                        ),
                        if (actionType == "Add") ...[
                          DropdownButtonFormField(
                            decoration:
                                InputDecoration(labelText: "Select Student"),
                            value: selectedStudent,
                            items: students
                                .map((student) => DropdownMenuItem(
                                      value: student["name"],
                                      child: Text(student["name"]!),
                                    ))
                                .toList(),
                            onChanged: (value) {
                              setState(() {
                                selectedStudent = value.toString();
                              });
                            },
                          ),
                          DropdownButtonFormField(
                            decoration:
                                InputDecoration(labelText: "Select Subject"),
                            value: selectedSubject,
                            items: subjects
                                .map((subject) => DropdownMenuItem(
                                      value: subject["subject"],
                                      child: Text(subject["subject"]!),
                                    ))
                                .toList(),
                            onChanged: (value) {
                              setState(() {
                                selectedSubject = value.toString();
                                updateCheckInOutTime(value.toString());
                              });
                            },
                          ),
                          if (checkInTime != null && checkOutTime != null)
                            Column(
                              children: [
                                Text("Check-In: $checkInTime"),
                                Text("Check-Out: $checkOutTime"),
                              ],
                            ),
                          ElevatedButton(
                            onPressed: addAttendance,
                            child: Text("Add Attendance"),
                          ),
                        ],
                        if (actionType == "Edit") ...[
                          DropdownButtonFormField(
                            decoration:
                                InputDecoration(labelText: "Select Student"),
                            value: selectedStudent,
                            items: students
                                .map((student) => DropdownMenuItem(
                                      value: student["name"],
                                      child: Text(student["name"]!),
                                    ))
                                .toList(),
                            onChanged: (value) {
                              setState(() {
                                selectedStudent = value.toString();
                              });
                            },
                          ),
                          if (selectedStudent != null)
                            ElevatedButton(
                              onPressed: () {
                                String formattedDate = DateFormat('yyyy-M-dd')
                                    .format(selectedDate);
                                String studentId = students.firstWhere(
                                    (student) =>
                                        student["name"] ==
                                        selectedStudent)["id"]!;
                                showEditAttendanceDialog(
                                    context, studentId, formattedDate);
                              },
                              child: Text("Edit Attendance"),
                            ),
                        ],
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
