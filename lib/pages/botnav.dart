import 'package:flutter/material.dart';
import 'package:projectimx/pages/home.dart'; // Import your pages
import 'package:projectimx/pages/user_list.dart';
import 'package:projectimx/pages/atten_dashboard.dart';
import 'package:projectimx/pages/signup.dart';
import 'package:projectimx/pages/settings.dart';

class BottomNav extends StatefulWidget {
  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<BottomNav> {
  int _currentIndex = 0;

  // List of pages for BottomNavigationBar
  final List<Widget> _pages = [
    UserListScreen(), // Index 0 - Calendar (example)
    AttendanceDashboard(), // Index 1 - Attendance/Reports
    HomeScreen(), // Index 2 - Home (No BottomNav here)
    SignupPage(), // Index 3 - Add user
    SettingsScreen(), // Index 4 - Settings
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_currentIndex], // Display the selected page

      // Conditionally show BottomNavigationBar only when the index is not Home (index 2)
      bottomNavigationBar: _currentIndex != 2
          ? BottomNavigationBar(
              currentIndex: _currentIndex, // Current selected index
              onTap: (index) {
                setState(() {
                  _currentIndex = index; // Change the selected index
                });
              },
              items: [
                BottomNavigationBarItem(
                  icon: Icon(Icons.calendar_today),
                  label: 'Users',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.bar_chart),
                  label: 'Report',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.home),
                  backgroundColor: Color.fromARGB(255, 0, 136, 255),
                  label: 'Home',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.account_circle),
                  label: 'Add User',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.settings),
                  label: 'Settings',
                ),
              ],
              selectedItemColor: Colors.blue,
              unselectedItemColor: Colors.grey,
              showUnselectedLabels: true, // Display unselected labels
              type: BottomNavigationBarType.fixed, // Fix the label visibility
            )
          : null, // No BottomNavigationBar for HomeScreen (index 2)
    );
  }
}
