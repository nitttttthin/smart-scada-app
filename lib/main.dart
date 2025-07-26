import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:fl_chart/fl_chart.dart';
import "package:flutter/material.dart";
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
// Firebase Messaging background handler
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print("🔥 Background Message: ${message.messageId}");
}

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Timer? refreshTimer;
  String selectedPriority = 'All';

  Color getPriorityColor(String priority) {
    switch (priority) {
      case 'High':
        return Colors.red;
      case 'Medium':
        return Colors.orange;
      case 'Low':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  @override
  void initState() {
    super.initState();
    refreshTimer = Timer.periodic(Duration(seconds: 30), (_) {
      setState(() {}); // triggers rebuild to refresh timestamp
    });
    // Foreground notification handler
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (message.notification != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message.notification!.title ?? 'New Notification')),
        );
      }
    });
  }

  @override
  void dispose() {
    refreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('SCADA Alarms'),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.indigo, Colors.blueAccent],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.logout),
            onPressed: () async {
              SharedPreferences prefs = await SharedPreferences.getInstance();
              await prefs.remove('remembered_user');
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => LoginScreen()),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: DropdownButton<String>(
              value: selectedPriority,
              isExpanded: true,
              items: ['All', 'High', 'Medium', 'Low']
                  .map((priority) => DropdownMenuItem(
                        value: priority,
                        child: Text('Show $priority Priority'),
                      ))
                  .toList(),
              onChanged: (value) {
                setState(() {
                  selectedPriority = value!;
                });
              },
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('alarms')
                  .where('trigger_time', isLessThanOrEqualTo: Timestamp.now())
                  .orderBy('trigger_time', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return Center(child: CircularProgressIndicator());
                }

                print("⏰ Current filter time: ${Timestamp.now().toDate()}");

                final alarms = snapshot.data!.docs.where((doc) {
                  final priority = doc['priority'] ?? '';
                  return selectedPriority == 'All' || priority == selectedPriority;
                }).toList();

                return ListView.builder(
                  itemCount: alarms.length,
                  itemBuilder: (context, index) {
                    final alarm = alarms[index];
                    final message = alarm['message'] ?? '';
                    final Timestamp? ts = alarm['trigger_time'];
                    final time = ts != null ? ts.toDate().toLocal().toString().substring(0, 16) : 'Unknown';
                    final priority = alarm['priority'] ?? 'Unknown';

                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
                      child: Card(
                        elevation: 6,
                        shadowColor: Colors.black54,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: ListTile(
                          contentPadding: EdgeInsets.all(16),
                          leading: CircleAvatar(
                            backgroundColor: getPriorityColor(priority),
                            child: Icon(Icons.warning, color: Colors.white),
                          ),
                          title: Text(
                            message,
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text('Time: $time'),
                          trailing: Text(
                            priority,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: getPriorityColor(priority),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _rememberMe = false;

  @override
  void initState() {
    super.initState();
    _checkRememberedUser();
  }

  void _checkRememberedUser() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    final name = prefs.getString('remembered_user');
    if (name != null) {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('name', isEqualTo: name)
          .get();
      if (snapshot.docs.isNotEmpty) {
        final user = snapshot.docs.first;
        final isAdmin = user['role'] == 'admin';
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
              builder: (_) => isAdmin ? AdminDashboardScreen() : HomeScreen()),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Login', textAlign: TextAlign.center),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Image.asset(
                  'assets/images/login_icon.png',
                  height: 100,
                  fit: BoxFit.contain,
                ),
                SizedBox(height: 16),
                Text(
                  "Smart SCADA Login",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 32),
                TextFormField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: 'Name',
                    prefixIcon: Icon(Icons.person_outline),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  validator: (value) => value == null || value.isEmpty ? 'Enter name' : null,
                ),
                SizedBox(height: 16),
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    prefixIcon: Icon(Icons.lock_outline),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword ? Icons.visibility_off : Icons.visibility,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                    ),
                  ),
                  validator: (value) => value == null || value.isEmpty ? 'Enter password' : null,
                ),
                CheckboxListTile(
                  title: Text("Remember Me"),
                  value: _rememberMe,
                  onChanged: (value) {
                    setState(() {
                      _rememberMe = value ?? false;
                    });
                  },
                  controlAffinity: ListTileControlAffinity.leading,
                ),
                SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () async {
                    if (_formKey.currentState!.validate()) {
                      FirebaseFirestore.instance
                          .collection('users')
                          .where('name', isEqualTo: _nameController.text.trim())
                          .get()
                          .then((snapshot) async {
                        if (snapshot.docs.isNotEmpty) {
                          final user = snapshot.docs.first;
                          final storedPassword = user['password'];
                          if (storedPassword == _passwordController.text.trim()) {
                            final isAdmin = user['role'] == 'admin';

                            if (_rememberMe) {
                              SharedPreferences prefs = await SharedPreferences.getInstance();
                              prefs.setString('remembered_user', _nameController.text.trim());
                            }

                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (_) => isAdmin ? AdminDashboardScreen() : HomeScreen(),
                              ),
                            );
                            if (!isAdmin) {
                              FirebaseFirestore.instance.collection('logins').add({
                                'name': _nameController.text.trim(),
                                'timestamp': FieldValue.serverTimestamp(),
                              });
                            }
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Incorrect password')),
                            );
                          }
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('User not found')),
                          );
                        }
                      });
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    minimumSize: Size(double.infinity, 48),
                    backgroundColor: Colors.indigo,
                    foregroundColor: Colors.white,
                    textStyle: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text('Login'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class AdminAlarmScreen extends StatelessWidget {
  final TextEditingController messageController = TextEditingController();
  final TextEditingController priorityController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Add Alarm'),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => AdminDashboardScreen()),
            );
          },
        ),
      ),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: messageController,
              decoration: InputDecoration(
                labelText: 'Alarm Message',
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 12),
            TextField(
              controller: priorityController,
              decoration: InputDecoration(
                labelText: 'Priority (High, Medium, Low)',
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 12),
            ElevatedButton(
              onPressed: () {
                final message = messageController.text.trim();
                final priority = priorityController.text.trim();
                if (message.isNotEmpty && priority.isNotEmpty) {
                  FirebaseFirestore.instance.collection('alarms').add({
                    'message': message,
                    'priority': priority,
                    'trigger_time': Timestamp.now(),
                  });
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => HomeScreen()),
                  );
                }
              },
              child: Text('Submit Alarm'),
            ),
          ],
        ),
      ),
    );
  }
}

class AdminDashboardScreen extends StatefulWidget {
  @override
  _AdminDashboardScreenState createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  DateTime? startDate;
  DateTime? endDate;

  Future<void> pickDateRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 1),
      lastDate: now,
      initialDateRange: startDate != null && endDate != null
          ? DateTimeRange(start: startDate!, end: endDate!)
          : null,
    );
    if (picked != null) {
      setState(() {
        startDate = picked.start;
        endDate = picked.end;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Admin Dashboard'),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => LoginScreen()),
            );
          },
        ),
      ),
      body: FutureBuilder<QuerySnapshot>(
        future: FirebaseFirestore.instance.collection('alarms').get(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return Center(child: CircularProgressIndicator());

          final allAlarms = snapshot.data!.docs;
          final alarms = allAlarms.where((doc) {
            final ts = doc['trigger_time'] as Timestamp;
            final dt = ts.toDate();
            if (startDate != null && endDate != null) {
              return dt.isAfter(startDate!.subtract(Duration(days: 1))) &&
                     dt.isBefore(endDate!.add(Duration(days: 1)));
            }
            return true;
          }).toList();

          final total = alarms.length;
          // Ensure type safety and null safety for alarm['priority']
          final high = alarms.where((doc) => (doc['priority'] ?? '') == 'High').length;
          final medium = alarms.where((doc) => (doc['priority'] ?? '') == 'Medium').length;
          final low = alarms.where((doc) => (doc['priority'] ?? '') == 'Low').length;

          return Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              children: [
                Text('Alarm Summary', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                if (startDate != null && endDate != null)
                  Text(
                    'From ${DateFormat.yMMMd().format(startDate!)} to ${DateFormat.yMMMd().format(endDate!)}',
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                SizedBox(height: 16),
                ElevatedButton(
                  onPressed: pickDateRange,
                  child: Text('Filter by Date'),
                ),
                SizedBox(height: 16),
                // Wrap the chart + list in Expanded to allow scrolling/flex
                Expanded(
                  child: Column(
                    children: [
                      AspectRatio(
                        aspectRatio: 1.6,
                        child: BarChart(
                          BarChartData(
                            alignment: BarChartAlignment.spaceAround,
                            maxY: (total * 1.2).toDouble(),
                            barTouchData: BarTouchData(enabled: false),
                            titlesData: FlTitlesData(
                              leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true)),
                              bottomTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  getTitlesWidget: (value, meta) {
                                    switch (value.toInt()) {
                                      case 0:
                                        return Text('High', style: TextStyle(fontSize: 12));
                                      case 1:
                                        return Text('Medium', style: TextStyle(fontSize: 12));
                                      case 2:
                                        return Text('Low', style: TextStyle(fontSize: 12));
                                      default:
                                        return SizedBox.shrink();
                                    }
                                  },
                                ),
                              ),
                            ),
                            barGroups: [
                              BarChartGroupData(x: 0, barRods: [
                                BarChartRodData(toY: high.toDouble(), color: Colors.red)
                              ]),
                              BarChartGroupData(x: 1, barRods: [
                                BarChartRodData(toY: medium.toDouble(), color: Colors.orange)
                              ]),
                              BarChartGroupData(x: 2, barRods: [
                                BarChartRodData(toY: low.toDouble(), color: Colors.green)
                              ]),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(height: 16),
                      // Alarm deletion list
                      Expanded(
                        child: ListView.builder(
                          itemCount: alarms.length,
                          itemBuilder: (context, index) {
                            final doc = alarms[index];
                            final message = doc['message'] ?? '';
                            final priority = doc['priority'] ?? '';
                            final Timestamp? ts = doc['trigger_time'];
                            final time = ts != null ? ts.toDate().toLocal().toString().substring(0, 16) : 'Unknown';
                            return Card(
                              child: ListTile(
                                title: Text(message),
                                subtitle: Text('Priority: $priority\nTime: $time'),
                                trailing: IconButton(
                                  icon: Icon(Icons.delete, color: Colors.red),
                                  onPressed: () async {
                                    await FirebaseFirestore.instance.collection('alarms').doc(doc.id).delete();
                                    setState(() {}); // refresh the dashboard
                                  },
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 24),
                ElevatedButton.icon(
                  icon: Icon(Icons.add),
                  label: Text('Add New Alarm'),
                  onPressed: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (_) => AdminAlarmScreen()),
                    );
                  },
                ),
                SizedBox(height: 12),
                ElevatedButton.icon(
                  icon: Icon(Icons.notifications),
                  label: Text('View All Alarms'),
                  onPressed: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (_) => HomeScreen()),
                    );
                  },
                ),
                SizedBox(height: 12),
                ElevatedButton.icon(
                  icon: Icon(Icons.logout),
                  label: Text('Logout'),
                  onPressed: () async {
                    SharedPreferences prefs = await SharedPreferences.getInstance();
                    await prefs.remove('remembered_user');
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (_) => LoginScreen()),
                    );
                  },
                ),
                SizedBox(height: 12),
                ElevatedButton.icon(
                  icon: Icon(Icons.dashboard),
                  label: Text('Back to Dashboard'),
                  onPressed: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (_) => AdminDashboardScreen()),
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  FirebaseMessaging messaging = FirebaseMessaging.instance;
  await messaging.requestPermission();
  String? token = await messaging.getToken();
  print("🔔 FCM Token: $token");

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  runApp(MaterialApp(
    debugShowCheckedModeBanner: false,
    home: SplashScreen(),
  ));
}

// Simple splash screen to show before login (optional, for demonstration)
class SplashScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // You can add a timer or logic to navigate to LoginScreen after a delay if desired.
    // For now, just redirect immediately.
    Future.microtask(() {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => LoginScreen()),
      );
    });
    return Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}
