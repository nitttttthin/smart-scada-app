import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AlarmScreen extends StatefulWidget {
  @override
  _AlarmScreenState createState() => _AlarmScreenState();
}

class _AlarmScreenState extends State<AlarmScreen> {
  List<Map<String, String>> alarms = [];
  late Timer timer;

  final List<Map<String, String>> simulatedAlarms = [
    {"time": "10:15 AM", "message": "Overheat in zone 1", "priority": "High"},
    {"time": "10:20 AM", "message": "Pump failure", "priority": "Medium"},
    {"time": "10:30 AM", "message": "Filter block detected", "priority": "Low"},
    {"time": "10:35 AM", "message": "Voltage drop", "priority": "Medium"},
    {"time": "10:40 AM", "message": "Pressure spike", "priority": "High"},
  ];

  int index = 0;

  @override
  void initState() {
    super.initState();
    _updateAlarms();
    timer = Timer.periodic(Duration(seconds: 5), (Timer t) => _updateAlarms());
  }

  void _updateAlarms() {
    setState(() {
      alarms.insert(0, simulatedAlarms[index % simulatedAlarms.length]);
      if (alarms.length > 10) {
        alarms.removeLast();
      }
      index++;
    });
  }

  @override
  void dispose() {
    timer.cancel();
    super.dispose();
  }

  Color getPriorityColor(String priority) {
    switch (priority) {
      case "High":
        return Colors.red;
      case "Medium":
        return Colors.orange;
      case "Low":
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Active Alarms',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.indigo,
      ),
      body: ListView.builder(
        itemCount: alarms.length,
        itemBuilder: (context, index) {
          final alarm = alarms[index];
          final String priority = alarm['priority'] ?? 'Unknown';
          final String message = alarm['message'] ?? 'No message';
          final String time = alarm['time'] ?? 'Unknown time';

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
            child: Card(
              elevation: 3,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: ListTile(
                contentPadding: EdgeInsets.all(16),
                leading: CircleAvatar(
                  backgroundColor: getPriorityColor(priority),
                  child: Icon(Icons.warning, color: Colors.white),
                ),
                title: Text(
                  message,
                  style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
                ),
                subtitle: Text('Time: $time', style: GoogleFonts.poppins()),
                trailing: Text(
                  priority,
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold,
                    color: getPriorityColor(priority),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}