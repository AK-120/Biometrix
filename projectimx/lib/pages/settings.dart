import 'package:flutter/material.dart';
import 'daily_atten.dart';
import 'holi.dart';
import 'timeRes.dart';

class SettingsScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Settings'),
      ),
      body: ListView(
        padding: EdgeInsets.all(16.0),
        children: <Widget>[
          ListTile(
            leading: Icon(Icons.send, color: Colors.blue),
            title: Text('Day/Daily Report'),
            trailing: Icon(Icons.arrow_forward_ios, color: Colors.blue),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => DateWiseReport()),
              );
            },
          ),
          ListTile(
            leading: Icon(Icons.beach_access, color: Colors.blue),
            title: Text('Holidays'),
            trailing: Icon(Icons.arrow_forward_ios, color: Colors.blue),
            onTap: () {
              // Navigate to the HolidayPage
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => HolidayPage()),
              );
            },
          ),
          ListTile(
            leading: Icon(Icons.access_alarms, color: Colors.blue),
            title: Text('Time Restriction'),
            trailing: Icon(Icons.arrow_forward_ios, color: Colors.blue),
            onTap: () {
              // Navigate to the HolidayPage
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => TimeRestrictionPage()),
              );
            },
          ),
        ],
      ),
    );
  }
}
