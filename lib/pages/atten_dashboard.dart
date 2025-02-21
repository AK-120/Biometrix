import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'atten_down.dart';
import 'atten_edit.dart';
import 'timetable.dart';
import 'abstd.dart';
import 'atten_list.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';

class AttendanceDashboard extends StatefulWidget {
  @override
  _AttendanceDashboardState createState() => _AttendanceDashboardState();
}

class _AttendanceDashboardState extends State<AttendanceDashboard> {
  DateTime _selectedDate = DateTime.now(); // Default to today's date
  late String date_;
  List<String> allUserIds = []; // Placeholder for list of all student IDs
  List<String> presentUserIds = []; // Placeholder for present students
  bool isHoliday = false; // Flag to indicate if the selected date is a holiday
  String holidayName = ''; // Store the holiday name

  String selectedSemester = 'Sem 1'; // Default semester
  String selectedDepartment = 'Computer Engineering'; // Default department

  @override
  void initState() {
    super.initState();
    _fetchUserIds(); // Fetch all user IDs when the screen is loaded
    _checkIfHoliday(); // Check if the current date is a holiday
  }

  // Fetch all student IDs from Firestore
  Future<void> _fetchUserIds() async {
    try {
      final userSnapshot = await FirebaseFirestore.instance
          .collection('users') // Assuming there's a collection for users
          .where('user_type',
              isEqualTo: 'Student') // Filter by user type "Student"
          .get();

      setState(() {
        allUserIds =
            userSnapshot.docs.map((doc) => doc['id'] as String).toList();
      });
    } catch (e) {
      print("Error fetching user IDs: $e");
    }
  }

  // Check if the selected date is a holiday
  Future<void> _checkIfHoliday() async {
    try {
      // Format _selectedDate to match the Firestore date string format
      String formattedDate =
          _selectedDate.toIso8601String().split('T')[0] + 'T00:00:00.000';

      print('Formatted date: $formattedDate');

      // Query Firestore for holidays matching the date string
      final holidaySnapshot = await FirebaseFirestore.instance
          .collection('holidays')
          .where('date', isEqualTo: formattedDate)
          .get();

      print('Query result: ${holidaySnapshot.docs}');

      if (holidaySnapshot.docs.isNotEmpty) {
        setState(() {
          isHoliday = true;
          holidayName = holidaySnapshot.docs.first['name'] ?? 'Unknown Holiday';
        });
      } else {
        setState(() {
          isHoliday = false;
          holidayName = '';
        });
      }
    } catch (e) {
      print("Error checking for holiday: $e");
    }
  }

  // Method to calculate the period between check-in and check-out times
  Future<String> _calculatePeriod(
      String documentId, String timeIn, String timeOut) async {
    try {
      // Parse time_in and time_out from 'HH:mm:ss' format
      final timeInFormat = DateFormat('H:m').parse(timeIn);
      final timeOutFormat = DateFormat('H:m').parse(timeOut);

      final duration = timeOutFormat.difference(timeInFormat);

      int hours = duration.inHours;
      int minutes = duration.inMinutes % 60;
      int totalMinutes = duration.inMinutes;

      String? periods = "0";

      // Determine periods based on time duration
      if (hours == 3 || totalMinutes >= 165) {
        periods = "3"; // 3 periods if session is 3 hours or more
      } else if (hours == 2 || totalMinutes >= 115) {
        periods = "2"; // 2 periods if session is 2 hours or more
      } else if (totalMinutes > 45 || totalMinutes <= 100) {
        periods = "1"; // 1 period if session is less than 2 hours
      } else {
        periods = null;
      }
      // Reference Firestore
      FirebaseFirestore firestore = FirebaseFirestore.instance;

      // Update document with calculated period
      await firestore.collection('attendance').doc(documentId).update({
        'periods': periods,
      });

      print('Periods saved successfully: $periods');

      return periods.toString(); // Return the period as a String
    } catch (e) {
      print('Error saving period: $e');
      return 'Error'; // Return an error message if something goes wrong
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Attendance Dashboard',
          style: TextStyle(),
        ),
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.book),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => UploadTimetableScreen()),
              );
            },
          ),
          IconButton(
            icon: Icon(Icons.access_alarm), // Correct
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => AttendanceSearchPage()),
              );
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Date Selector
            GestureDetector(
              onTap: _pickDate, // Trigger date picker
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    DateFormat('EEE, d MMM yyyy').format(_selectedDate),
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  Icon(Icons.arrow_drop_down),
                ],
              ),
            ),
            SizedBox(height: 16),

            // Holiday Check
            if (isHoliday)
              Container(
                padding: EdgeInsets.all(10),
                color: Colors.green[100],
                child: Text(
                  '${DateFormat('d MMM yyyy').format(_selectedDate)} is a holiday: $holidayName',
                  style: TextStyle(fontSize: 16, color: Colors.green),
                ),
              ),
            SizedBox(height: 16),

            // Semester and Department Selector
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Semester Selector
                DropdownButton<String>(
                  value: selectedSemester,
                  onChanged: (String? newSemester) {
                    setState(() {
                      selectedSemester = newSemester!;
                    });
                  },
                  items: ['Sem 1', 'Sem 2', 'Sem 3', 'Sem 4', 'Sem 5', 'Sem 6']
                      .map<DropdownMenuItem<String>>((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value),
                    );
                  }).toList(),
                ),

                // Department Selector
                DropdownButton<String>(
                  value: selectedDepartment,
                  onChanged: (String? newDepartment) {
                    setState(() {
                      selectedDepartment = newDepartment!;
                    });
                  },
                  items: [
                    'Computer Engineering',
                    'Electronics Engineering',
                    'Printing Technology'
                  ].map<DropdownMenuItem<String>>((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value),
                    );
                  }).toList(),
                ),
              ],
            ),
            SizedBox(height: 16),

            // Attendance Statistics (Present/Absent for Students Only)
            if (!isHoliday)
              StreamBuilder(
                stream: FirebaseFirestore.instance
                    .collection('users') // Fetch users (students)
                    .where('user_type',
                        isEqualTo: 'Student') // Filter for students
                    .where('department',
                        isEqualTo: selectedDepartment) // Filter by department
                    .where('semester',
                        isEqualTo: selectedSemester) // Filter by semester
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildAttendanceCard('Present', '0'),
                        _buildAttendanceCard('Absent', '0'),
                      ],
                    );
                  }

                  final allStudents = snapshot.data!.docs;
                  allUserIds.clear();
                  allStudents.forEach((doc) {
                    allUserIds.add(doc['id']);
                  });

                  // Fetch present students based on attendance collection
                  return StreamBuilder(
                    stream: FirebaseFirestore.instance
                        .collection('attendance')
                        .where('timestamp',
                            isGreaterThanOrEqualTo: Timestamp.fromDate(DateTime(
                                _selectedDate.year,
                                _selectedDate.month,
                                _selectedDate.day)))
                        .where('timestamp',
                            isLessThan: Timestamp.fromDate(DateTime(
                                _selectedDate.year,
                                _selectedDate.month,
                                _selectedDate.day + 1)))
                        .where('department', isEqualTo: selectedDepartment)
                        .where('semester', isEqualTo: selectedSemester)
                        .snapshots(),
                    builder: (context, attendanceSnapshot) {
                      if (!attendanceSnapshot.hasData) {
                        return Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _buildAttendanceCard('Present', '0'),
                            _buildAttendanceCard(
                                'Absent', allUserIds.length.toString()),
                          ],
                        );
                      }

                      final presentDocs = attendanceSnapshot.data!.docs;
                      presentUserIds.clear();
                      for (var doc in presentDocs) {
                        if (doc['user_type'] == 'Student') {
                          presentUserIds.add(doc['id']);
                        }
                      }

                      // Calculate absent students
                      int absentCount =
                          allUserIds.length - presentUserIds.length;

                      return Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildAttendanceCard(
                            'Present',
                            presentUserIds.length.toString(),
                          ),
                          _buildAttendanceCard(
                            'Absent',
                            (allUserIds.length - presentUserIds.length)
                                .toString(),
                            onViewAbsent: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => AbsentStudentsPage(
                                    selectedDepartment: selectedDepartment,
                                    selectedSemester: selectedSemester,
                                    selectedDate: _selectedDate,
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      );
                    },
                  );
                },
              ),

            SizedBox(height: 20),

            // Daily Report Table Header
            Text(
              'Daily Report',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),

            // Table Column Headings
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Adm. No', style: TextStyle()),
                Text('Name', style: TextStyle()),
                Text('Time in', style: TextStyle()),
                Text('Time out', style: TextStyle()),
                Text('Periods', style: TextStyle()),
                Text('Subject'),
              ],
            ),
            SizedBox(height: 8),

            // Table Rows
            if (!isHoliday)
              Expanded(
                child: StreamBuilder(
                  stream: FirebaseFirestore.instance
                      .collection('attendance')
                      .where('timestamp',
                          isGreaterThanOrEqualTo: Timestamp.fromDate(DateTime(
                              _selectedDate.year,
                              _selectedDate.month,
                              _selectedDate.day)))
                      .where('timestamp',
                          isLessThan: Timestamp.fromDate(DateTime(
                              _selectedDate.year,
                              _selectedDate.month,
                              _selectedDate.day + 1)))
                      .where('department', isEqualTo: selectedDepartment)
                      .where('semester', isEqualTo: selectedSemester)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return Center(child: CircularProgressIndicator());
                    }
                    final docs = snapshot.data!.docs;
                    if (docs.isEmpty) {
                      return Center(
                          child:
                              Text("No records found for the selected date."));
                    }
                    return ListView.builder(
                      itemCount: docs.length,
                      itemBuilder: (context, index) {
                        final doc = docs[index];
                        if (doc['user_type'] == 'Student') {
                          // Call _calculatePeriod to update the period automatically when the data changes
                          final documentId = doc.id;
                          final timeIn = doc['time_in'];
                          final timeOut = doc['time_out'];
                          if (doc['periods'] == null &&
                              doc['time_out'] != null) {
                            _calculatePeriod(documentId, timeIn, timeOut);
                          }
                          // Call the period calculation function
                          return _buildReportRow(
                            doc['id'] ?? 'N/A',
                            doc['name'] ?? 'N/A',
                            doc['time_in'] ?? 'N/A',
                            doc['time_out'] ?? 'N/A',
                            doc['periods'] ?? 'N/A',
                            doc['subject'] ?? 'N/A',
                          );
                        } else {
                          return SizedBox.shrink(); // Exclude faculty records
                        }
                      },
                    );
                  },
                ),
              ),
          ],
        ),
      ),
      floatingActionButton: SpeedDial(
        animatedIcon: AnimatedIcons.menu_close,
        backgroundColor: Colors.blue,
        children: [
          SpeedDialChild(
            child: Icon(Icons.create_rounded),
            label: "Edit Attendance",
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => EditAttendancePage()),
            ),
          ),
          SpeedDialChild(
            child: Icon(Icons.download),
            label: "Download Report",
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => AttendanceReportPage()),
            ),
          ),
        ],
      ),
    );
  }

  // Date picker logic
  Future<void> _pickDate() async {
    DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDate, // Start with the currently selected date
      firstDate: DateTime(2000), // Minimum selectable date
      lastDate: DateTime(2100), // Maximum selectable date
    );

    if (pickedDate != null && pickedDate != _selectedDate) {
      setState(() {
        _selectedDate = pickedDate; // Update the selected date
      });
      _checkIfHoliday(); // Re-check if the new date is a holiday
    }
  }

  Widget _buildAttendanceCard(String title, String count,
      {VoidCallback? onViewAbsent}) {
    return Container(
      width: 150,
      height: 120,
      decoration: BoxDecoration(
        color: Colors.blue,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            title,
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8),
          Text(
            count,
            style: TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (onViewAbsent != null)
            IconButton(
              icon: Icon(
                Icons.visibility_off,
                color: Colors.white,
              ),
              onPressed: onViewAbsent,
            ),
        ],
      ),
    );
  }

  Widget _buildReportRow(String admNo, String name, String timeIn,
      String timeOut, String period, String subject) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(admNo),
          Text(name),
          Text(timeIn),
          Text(timeOut),
          Text(period), // Display the calculated period
          Text(subject),
        ],
      ),
    );
  }
}
