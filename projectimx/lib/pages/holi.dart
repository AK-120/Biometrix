import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class HolidayPage extends StatefulWidget {
  @override
  _HolidayPageState createState() => _HolidayPageState();
}

class _HolidayPageState extends State<HolidayPage> {
  DateTime _selectedHoliday = DateTime.now();
  DateTime? _startHoliday;
  DateTime? _endHoliday;
  TextEditingController _holidayNameController = TextEditingController();
  String _holidayType = 'Single Day';
  int _selectedMonth = DateTime.now().month;
  int _selectedYear = DateTime.now().year; // Set this to a valid year initially

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Set Holidays')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Holiday Type",
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: _holidayType,
                      decoration: InputDecoration(border: OutlineInputBorder()),
                      items: [
                        DropdownMenuItem(
                            value: 'Single Day', child: Text('Single Day')),
                        DropdownMenuItem(
                            value: 'Multiple Days',
                            child: Text('Multiple Days')),
                        DropdownMenuItem(
                            value: 'Weekend for Month',
                            child: Text('Weekend for Month')),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _holidayType = value!;
                          _startHoliday = null;
                          _endHoliday = null;
                        });
                      },
                    ),
                    SizedBox(height: 16),
                    if (_holidayType == 'Single Day')
                      _buildDatePicker(
                          "Holiday Date", _selectedHoliday, _pickHolidayDate),
                    if (_holidayType == 'Multiple Days') ...[
                      _buildDatePicker("Start Date", _startHoliday,
                          () => _pickRangeDate('start')),
                      SizedBox(height: 16),
                      _buildDatePicker(
                          "End Date", _endHoliday, () => _pickRangeDate('end')),
                    ],
                    if (_holidayType == 'Weekend for Month') ...[
                      _buildDropdown("Select Month", _selectedMonth, 1, 12,
                          (value) {
                        setState(() {
                          _selectedMonth = value!;
                        });
                      }),
                      SizedBox(height: 16),
                      _buildDropdown(
                          "Select Year",
                          _selectedYear,
                          DateTime.now().year - 1,
                          DateTime.now().year + 10, (value) {
                        setState(() {
                          _selectedYear = value!;
                        });
                      }),
                    ],
                    SizedBox(height: 16),
                    if (_holidayType != 'Weekend for Month')
                      TextField(
                        controller: _holidayNameController,
                        decoration: InputDecoration(
                          labelText: 'Holiday Name',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    SizedBox(height: 16),
                    Center(
                      child: ElevatedButton(
                        onPressed: _saveHoliday,
                        child: Text('Save Holiday'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDatePicker(String label, DateTime? date, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(date != null
                ? "${date.toLocal()}".split(' ')[0]
                : "Not Selected"),
            Icon(Icons.calendar_today),
          ],
        ),
      ),
    );
  }

  Widget _buildDropdown(
      String label, int value, int min, int max, ValueChanged<int?> onChanged) {
    return DropdownButtonFormField<int>(
      value: value,
      decoration:
          InputDecoration(labelText: label, border: OutlineInputBorder()),
      items: List.generate(max - min + 1, (index) => min + index)
          .map((val) => DropdownMenuItem(value: val, child: Text('$val')))
          .toList(),
      onChanged: onChanged,
    );
  }

  Future<void> _pickHolidayDate() async {
    DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedHoliday,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (pickedDate != null) {
      setState(() {
        _selectedHoliday = pickedDate;
      });
    }
  }

  Future<void> _pickRangeDate(String type) async {
    DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: type == 'start'
          ? (_startHoliday ?? DateTime.now())
          : (_endHoliday ?? DateTime.now()),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (pickedDate != null) {
      setState(() {
        if (type == 'start') {
          _startHoliday = pickedDate;
        } else {
          _endHoliday = pickedDate;
        }
      });
    }
  }

  Future<void> _saveHoliday() async {
    try {
      if (_holidayType == 'Single Day') {
        await FirebaseFirestore.instance.collection('holidays').add({
          'date': _selectedHoliday.toIso8601String(),
          'name': _holidayNameController.text.trim(),
        });
      } else if (_holidayType == 'Multiple Days' &&
          _startHoliday != null &&
          _endHoliday != null) {
        WriteBatch batch = FirebaseFirestore.instance.batch();
        for (DateTime current = _startHoliday!;
            current.isBefore(_endHoliday!) ||
                current.isAtSameMomentAs(_endHoliday!);
            current = current.add(Duration(days: 1))) {
          DocumentReference docRef =
              FirebaseFirestore.instance.collection('holidays').doc();
          batch.set(docRef, {
            'date': current.toIso8601String(),
            'name': _holidayNameController.text.trim(),
          });
        }
        await batch.commit();
      } else if (_holidayType == 'Weekend for Month') {
        await _addWeekendHolidays(_selectedYear, _selectedMonth);
      }
      _clearInputs();
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Holiday(s) saved successfully')));
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error saving holidays: $e')));
    }
  }

  void _clearInputs() {
    _holidayNameController.clear();
    setState(() {
      _selectedHoliday = DateTime.now();
      _startHoliday = null;
      _endHoliday = null;
    });
  }

  Future<void> _addWeekendHolidays(int year, int month) async {
    DateTime startOfMonth = DateTime(year, month, 1);
    DateTime endOfMonth =
        DateTime(year, month + 1, 1).subtract(Duration(days: 1));

    WriteBatch batch = FirebaseFirestore.instance.batch();
    for (DateTime day = startOfMonth;
        day.isBefore(endOfMonth) || day.isAtSameMomentAs(endOfMonth);
        day = day.add(Duration(days: 1))) {
      if (day.weekday == DateTime.saturday || day.weekday == DateTime.sunday) {
        DocumentReference docRef =
            FirebaseFirestore.instance.collection('holidays').doc();
        batch.set(docRef, {
          'date': day.toIso8601String(),
          'name': 'Weekend',
        });
      }
    }
    await batch.commit();
  }
}
