import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class AbsentStudentsPage extends StatelessWidget {
  final String selectedDepartment;
  final String selectedSemester;
  final DateTime selectedDate;

  AbsentStudentsPage({
    required this.selectedDepartment,
    required this.selectedSemester,
    required this.selectedDate,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Absent Students'),
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Absent Students for ${DateFormat('d MMM yyyy').format(selectedDate)}',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),

            // Table Header
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Adm. No',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    Text('Name', style: TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),

            // Fetch and display absent students
            Expanded(
              child: StreamBuilder(
                stream: FirebaseFirestore.instance
                    .collection('attendance')
                    .where('timestamp',
                        isGreaterThanOrEqualTo: Timestamp.fromDate(
                          DateTime(selectedDate.year, selectedDate.month,
                              selectedDate.day),
                        ))
                    .where('timestamp',
                        isLessThan: Timestamp.fromDate(
                          DateTime(selectedDate.year, selectedDate.month,
                              selectedDate.day + 1),
                        ))
                    .where('department', isEqualTo: selectedDepartment)
                    .where('semester', isEqualTo: selectedSemester)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final attendanceDocs = snapshot.data!.docs;
                  List<String> presentUserIds =
                      attendanceDocs.map((doc) => doc['id'] as String).toList();

                  return StreamBuilder(
                    stream: FirebaseFirestore.instance
                        .collection('users')
                        .where('user_type', isEqualTo: 'Student')
                        .where('department', isEqualTo: selectedDepartment)
                        .where('semester', isEqualTo: selectedSemester)
                        .snapshots(),
                    builder: (context, userSnapshot) {
                      if (!userSnapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      final allStudents = userSnapshot.data!.docs;
                      final absentStudents = allStudents
                          .where((student) =>
                              !presentUserIds.contains(student['id']))
                          .toList();

                      if (absentStudents.isEmpty) {
                        return const Center(
                          child: Text(
                            "No absent students for this date.",
                            style: TextStyle(fontSize: 16),
                          ),
                        );
                      }

                      return ListView.separated(
                        itemCount: absentStudents.length,
                        separatorBuilder: (_, __) => const Divider(),
                        itemBuilder: (context, index) {
                          final student = absentStudents[index];
                          return Card(
                            elevation: 2,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(student['id'] ?? 'N/A',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w500)),
                                  Text(student['name'] ?? 'N/A',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w500)),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
