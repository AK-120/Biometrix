import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class UploadTimetableScreen extends StatefulWidget {
  @override
  _UploadTimetableScreenState createState() => _UploadTimetableScreenState();
}

class _UploadTimetableScreenState extends State<UploadTimetableScreen> {
  final _formKey = GlobalKey<FormState>();
  String? selectedBranch;
  String? selectedSemester;
  String? selectedDay;
  List<Map<String, String>> periods = [];

  final branchOptions = [
    "Computer Engineering",
    "Electronics Engineering",
    "Printing Technology"
  ];
  final semesterOptions = [
    'Sem 1',
    'Sem 2',
    'Sem 3',
    'Sem 4',
    'Sem 5',
    'Sem 6',
  ];
  final dayOptions = [
    "Monday",
    "Tuesday",
    "Wednesday",
    "Thursday",
    "Friday",
  ];

  final subjectController = TextEditingController();
  String? selectedTimeRange; // Stores the selected time range

  // Method to pick a time range
  Future<void> pickTimeRange(BuildContext context) async {
    TimeOfDay? startTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );

    if (startTime != null) {
      TimeOfDay? endTime = await showTimePicker(
        context: context,
        initialTime: startTime,
      );

      if (endTime != null) {
        setState(() {
          selectedTimeRange =
              "${startTime.format(context)} - ${endTime.format(context)}";
        });
      }
    }
  }

  void addPeriod() {
    if (selectedTimeRange != null && subjectController.text.isNotEmpty) {
      setState(() {
        periods.add({
          "time": selectedTimeRange!,
          "subject": subjectController.text,
        });
        selectedTimeRange = null;
        subjectController.clear();
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Please select time and enter subject.")),
      );
    }
  }

  Future<void> uploadTimetable() async {
    if (selectedBranch != null &&
        selectedSemester != null &&
        selectedDay != null &&
        periods.isNotEmpty) {
      try {
        await FirebaseFirestore.instance.collection('timetable').add({
          "branch": selectedBranch,
          "semester": selectedSemester,
          "day": selectedDay,
          "periods": periods,
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Timetable uploaded successfully!")),
        );

        setState(() {
          periods.clear();
        });
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error uploading timetable: $e")),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Please fill all fields and add periods.")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Upload Timetable")),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Center(
            child: Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Branch Dropdown
                      DropdownButtonFormField<String>(
                        decoration: InputDecoration(labelText: "Select Branch"),
                        value: selectedBranch,
                        items: branchOptions.map((branch) {
                          return DropdownMenuItem(
                              value: branch, child: Text(branch));
                        }).toList(),
                        onChanged: (value) =>
                            setState(() => selectedBranch = value),
                      ),
                      SizedBox(height: 16),

                      // Semester Dropdown
                      DropdownButtonFormField<String>(
                        decoration:
                            InputDecoration(labelText: "Select Semester"),
                        value: selectedSemester,
                        items: semesterOptions.map((semester) {
                          return DropdownMenuItem(
                              value: semester, child: Text(semester));
                        }).toList(),
                        onChanged: (value) =>
                            setState(() => selectedSemester = value),
                      ),
                      SizedBox(height: 16),

                      // Day Dropdown
                      DropdownButtonFormField<String>(
                        decoration: InputDecoration(labelText: "Select Day"),
                        value: selectedDay,
                        items: dayOptions.map((day) {
                          return DropdownMenuItem(value: day, child: Text(day));
                        }).toList(),
                        onChanged: (value) =>
                            setState(() => selectedDay = value),
                      ),
                      SizedBox(height: 16),

                      // Time Range Selection
                      Center(
                        child: GestureDetector(
                          onTap: () => pickTimeRange(context),
                          child: Container(
                            padding: EdgeInsets.symmetric(
                                vertical: 16, horizontal: 12),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.blue),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              selectedTimeRange ?? "Select Time Range",
                              style: TextStyle(fontSize: 16),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: 8),

                      // Subject Input
                      TextField(
                        controller: subjectController,
                        decoration: InputDecoration(labelText: "Subject"),
                      ),
                      SizedBox(height: 16),

                      // Add Period Button
                      Center(
                        child: ElevatedButton.icon(
                          onPressed: addPeriod,
                          icon: Icon(Icons.add),
                          label: Text("Add Period"),
                          style: ElevatedButton.styleFrom(
                            padding: EdgeInsets.symmetric(
                                vertical: 12, horizontal: 16),
                          ),
                        ),
                      ),
                      SizedBox(height: 16),

                      // Display Added Periods
                      if (periods.isNotEmpty)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Added Periods:",
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            SizedBox(height: 8),
                            ...periods.map((period) => Text(
                                "${period['time']} - ${period['subject']}")),
                          ],
                        ),
                      SizedBox(height: 16),

                      // Upload Button
                      Center(
                        child: ElevatedButton.icon(
                          onPressed: uploadTimetable,
                          icon: Icon(Icons.upload),
                          label: Text("Upload Timetable"),
                          style: ElevatedButton.styleFrom(
                            padding: EdgeInsets.symmetric(
                                vertical: 12, horizontal: 20),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
