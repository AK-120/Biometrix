import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // For formatting time and date
import 'package:projectimx/pages/scaner.dart'; // Import the scan result screen
import 'package:projectimx/pages/botnav.dart';

class HomeScreen extends StatefulWidget {
  @override
  _ScanScreenState createState() => _ScanScreenState();
}

class _ScanScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  String _timeString = '';
  String _dateString = '';
  bool isHoliday = false; // To track if it's a holiday
  String holidayName = ''; // To store the holiday name
  DateTime _selectedDate = DateTime.now(); // Default to today
  Map<String, String> _timeRestrictions = {}; // To store time restrictions
  late AnimationController _controller;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _updateTime();
    Timer.periodic(Duration(seconds: 1), (Timer t) => _updateTime());
    _fetchTimeRestrictions();
    // Initialize the controller first
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..repeat(reverse: true); // Makes the glow fade in and out

    // Initialize the animation after the controller
    _glowAnimation = Tween<double>(begin: 10, end: 100).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _updateTime() {
    final DateTime now = DateTime.now();
    final String formattedTime = DateFormat('h:mm a').format(now);
    final String formattedDate = DateFormat('EEE, d MMMM').format(now);
    setState(() {
      _timeString = formattedTime;
      _dateString = formattedDate;
    });
  }

  Future<void> _fetchTimeRestrictions() async {
    final String currentDay = DateFormat('EEEE').format(DateTime.now());

    if (['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday']
        .contains(currentDay)) {
      try {
        final docSnapshot = await FirebaseFirestore.instance
            .collection('time_restrictions')
            .doc(currentDay)
            .get();

        if (docSnapshot.exists) {
          setState(() {
            _timeRestrictions = Map<String, String>.from(docSnapshot.data()!);
          });
        } else {
          print("No time restrictions found for $currentDay");
        }
      } catch (e) {
        print("Error fetching time restrictions: $e");
      }
    } else {
      print("Today is not a working day (Mon-Fri).");
    }
  }

  Future<void> _checkIfHoliday() async {
    try {
      String formattedDate =
          _selectedDate.toIso8601String().split('T')[0] + 'T00:00:00.000';

      final holidaySnapshot = await FirebaseFirestore.instance
          .collection('holidays')
          .where('date', isEqualTo: formattedDate)
          .get();

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

  bool _isTimeWithinRange() {
    final now = DateTime.now();
    final formattedTime = DateFormat('h:mm a').format(now);

    // Convert string times to DateTime for proper comparison
    DateTime parseTime(String timeStr) {
      if (timeStr.isEmpty) return DateTime(2000); // Default invalid time
      return DateFormat('h:mm a').parse(timeStr);
    }

    DateTime currentTime = DateFormat('h:mm a').parse(formattedTime);

    DateTime checkInStart =
        parseTime(_timeRestrictions['morning_check_in_start'] ?? '');
    DateTime checkInEnd =
        parseTime(_timeRestrictions['morning_check_in_end'] ?? '');
    DateTime checkOutStart =
        parseTime(_timeRestrictions['morning_check_out_start'] ?? '');
    DateTime checkOutEnd =
        parseTime(_timeRestrictions['morning_check_out_end'] ?? '');

    DateTime afternoonCheckInStart =
        parseTime(_timeRestrictions['afternoon_check_in_start'] ?? '');
    DateTime afternoonCheckInEnd =
        parseTime(_timeRestrictions['afternoon_check_in_end'] ?? '');
    DateTime afternoonCheckOutStart =
        parseTime(_timeRestrictions['afternoon_check_out_start'] ?? '');
    DateTime afternoonCheckOutEnd =
        parseTime(_timeRestrictions['afternoon_check_out_end'] ?? '');

    print("Current Time: $formattedTime");
    print(
        "Check-in Range: ${_timeRestrictions['morning_check_in_start']} - ${_timeRestrictions['morning_check_in_end']}");

    if ((currentTime.isAfter(checkInStart) &&
            currentTime.isBefore(checkInEnd)) ||
        (currentTime.isAfter(checkOutStart) &&
            currentTime.isBefore(checkOutEnd)) ||
        (currentTime.isAfter(afternoonCheckInStart) &&
            currentTime.isBefore(afternoonCheckInEnd)) ||
        (currentTime.isAfter(afternoonCheckOutStart) &&
            currentTime.isBefore(afternoonCheckOutEnd))) {
      return true;
    }

    return false; // Not within time limits
  }

  void _handleScan(BuildContext context) async {
    await _checkIfHoliday(); // Check for holidays before proceeding

    if (isHoliday) {
      // Show a popup if it's a holiday
      showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: Text('Holiday Alert'),
            content: Text('Today is $holidayName. Scanning is not allowed.'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: Text('OK'),
              ),
            ],
          );
        },
      );
    } else {
      // Check if current time is within allowed check-in/check-out range
      if (_isTimeWithinRange()) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => ScannerScreen()),
        );
      } else {
        // Show an alert if the time is not within range
        showDialog(
          context: context,
          builder: (context) {
            return AlertDialog(
              title: Text('Time Alert'),
              content: Text('Scanning is not allowed at this time.'),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: Text('OK'),
                ),
              ],
            );
          },
        );
      }
    }
  }

  void _handleSettings(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => BottomNav()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Dynamic Time Display
            Text(
              _timeString,
              style: const TextStyle(
                fontSize: 48,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),

            // Dynamic Date Display
            Text(
              _dateString,
              style: const TextStyle(
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 40),

            // Scan Button with Animation
            GestureDetector(
              onTap: () => _handleScan(context),
              child: Column(
                children: [
                  AnimatedBuilder(
                    animation: _glowAnimation,
                    builder: (context, child) {
                      return Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.blueAccent.withOpacity(0.1),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.blueAccent.withOpacity(0.4),
                              blurRadius: _glowAnimation.value,
                              spreadRadius: 5,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.camera_alt_outlined,
                          size: 100,
                          color: Colors.blueAccent,
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'SCAN',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.blueAccent,
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(),

            // Settings Icon
            Padding(
              padding: const EdgeInsets.only(right: 20, bottom: 20),
              child: Align(
                alignment: Alignment.bottomRight,
                child: InkWell(
                  onTap: () => _handleSettings(context),
                  borderRadius: BorderRadius.circular(50),
                  child: const Padding(
                    padding: EdgeInsets.all(10),
                    child: Icon(
                      Icons.settings,
                      size: 32,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
