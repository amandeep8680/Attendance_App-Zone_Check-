import 'package:attendance_aap/utility/texts.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:geolocator/geolocator.dart';
import '../widgets/drawer.dart';
import 'package:lottie/lottie.dart';
import 'package:animated_text_kit/animated_text_kit.dart';

class StudentDash extends StatefulWidget {
  const StudentDash({Key? key}) : super(key: key);

  @override
  State createState() => _StudentDashState();
}

class _StudentDashState extends State<StudentDash> with SingleTickerProviderStateMixin {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();

  String? _activeSessionId;
  bool _canMarkAttendance = false;
  String studentClass = '';
  String studentSemester = '';
  String studentName = '';
  String studentId = '';
  String? studentRollNumber;
  DateTime? lastBackPressed;

  StreamSubscription? _sessionListener;

  String _sessionSubject = '';
  String _sessionCourse = '';
  String _sessionTeacherName = '';
  Map<String, bool> _studentAttendance = {};

  late final AnimationController _emojiAnimationController;

  @override
  void initState() {
    super.initState();
    _emojiAnimationController = AnimationController(vsync: this);
    fetchStudentDetails();
  }

  @override
  void dispose() {
    _sessionListener?.cancel();
    _emojiAnimationController.dispose();
    super.dispose();
  }

  Future fetchStudentDetails() async {
    final user = _auth.currentUser;
    if (user == null) return;
    studentId = user.uid;
    final snapshot = await _dbRef.child('users/students/$studentId').get();

    if (snapshot.exists) {
      final data = snapshot.value as Map;
      studentClass = data['class'] ?? '';
      studentSemester = data['semester'] ?? '';
      studentName = data['name'] ?? '';
      String? rollNumber = data['rollNumber'];

      if (rollNumber != null) {
        setState(() {
          studentRollNumber = rollNumber;
        });
        listenToActiveSession();
      }
    }
  }

  void listenToActiveSession() {
    _sessionListener?.cancel();
    Query sessionQuery = _dbRef
        .child('attendance_sessions')
        .orderByChild('class')
        .equalTo(studentClass);

    _sessionListener = sessionQuery.onValue.listen((event) {
      final data = event.snapshot.value;
      bool found = false;

      if (data is Map) {
        data.forEach((key, value) {
          if (value is Map &&
              value['active'] == true &&
              value['semester'] == studentSemester) {
            found = true;
            fetchStudentList(key);
            if (mounted) {
              setState(() {
                _activeSessionId = key;
                _canMarkAttendance = true;
                _sessionSubject = value['subject'] ?? '';
                _sessionCourse = value['course'] ?? '';
                _sessionTeacherName = value['teacherName'] ?? '';
              });
            }
            return;
          }
        });
      }

      if (!found) {
        if (mounted) {
          setState(() {
            _activeSessionId = null;
            _canMarkAttendance = false;
            _sessionSubject = '';
            _sessionCourse = '';
            _sessionTeacherName = '';
            _studentAttendance = {};
          });
        }
      }
    });
  }

  Future fetchStudentList(String sessionId) async {
    final snapshot = await _dbRef.child('attendance_sessions/$sessionId/attendance').get();
    if (snapshot.exists) {
      final data = snapshot.value as Map?;
      if (data != null) {
        Map<String, bool> attendanceMap = {};
        data.forEach((studentId, studentData) {
          if (studentData is Map) {
            String name = studentData['name'] ?? 'Unknown Student';
            attendanceMap[name] = false;
          }
        });
        if (mounted) {
          setState(() {
            _studentAttendance = attendanceMap;
          });
        }
      }
    } else {
      if (mounted) {
        setState(() {
          _studentAttendance = {};
        });
      }
    }
  }

  Future markAttendance() async {
    if (!_canMarkAttendance || _activeSessionId == null) return;

    try {
      Position studentPosition = await _getCurrentLocation();

      final sessionSnapshot = await _dbRef.child('attendance_sessions/$_activeSessionId').get();
      if (sessionSnapshot.exists) {
        final sessionData = sessionSnapshot.value as Map;
        double teacherLatitude = sessionData['teacherLatitude'];
        double teacherLongitude = sessionData['teacherLongitude'];

        Position teacherPosition = Position(
          latitude: teacherLatitude,
          longitude: teacherLongitude,
          timestamp: DateTime.now(),
          accuracy: 0.0,
          altitude: 0.0,
          heading: 0.0,
          speed: 0.0,
          speedAccuracy: 0.0,
          altitudeAccuracy: 0.0,
          headingAccuracy: 0.0,
        );

        bool isWithinRange = await _checkProximity(studentPosition, teacherPosition);

        if (isWithinRange) {
          await _saveAttendance(true);
        } else {
          await _saveAttendance(false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("You were outside range. Marked as absent.")),
          );
        }

        setState(() {
          _canMarkAttendance = false;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to mark attendance: $e")),
      );
    }
  }

  Future<void> _saveAttendance(bool isPresent) async {
    if (_activeSessionId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Session not active.")),
      );
      return;
    }

    final date = DateTime.now().toIso8601String().split('T')[0];
    final attendanceRef = _dbRef.child('attendance/$studentClass/$date/$_sessionSubject');

    final studentData = {
      'name': studentName,
      'rollNumber': studentRollNumber,
      'isPresent': isPresent,
      'timestamp': ServerValue.timestamp,
      'markedBy': _sessionTeacherName,
    };

    try {
      await attendanceRef.child(studentId).set(studentData);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isPresent
              ? "Attendance saved successfully!"
              : "Marked as absent (out of range)."),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error saving attendance: $e")),
      );
    }
  }

  Future<Position> _getCurrentLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('Location services are disabled.');
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission != LocationPermission.whileInUse &&
          permission != LocationPermission.always) {
        throw Exception('Location permission denied');
      }
    }

    return await Geolocator.getCurrentPosition();
  }

  Future<bool> _checkProximity(Position studentPosition, Position teacherPosition) async {
    double distance = Geolocator.distanceBetween(
      studentPosition.latitude,
      studentPosition.longitude,
      teacherPosition.latitude,
      teacherPosition.longitude,
    );
    return distance <= 10;
  }

  Future<bool> _onWillPop() async {
    final now = DateTime.now();
    if (lastBackPressed == null || now.difference(lastBackPressed!) > Duration(seconds: 2)) {
      lastBackPressed = now;
      return false;
    }
    SystemNavigator.pop();
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Student Dashboard"),
          centerTitle: true,
        ),
        drawer: MyDrawer(),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: _canMarkAttendance && _activeSessionId != null
              ? Center(
                child: SingleChildScrollView(
                            child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Center(
                    child: Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('Subject: $_sessionSubject', style: style1(), textAlign: TextAlign.center),
                            Text('Class: $studentClass', style: style3(), textAlign: TextAlign.center),
                            Text('Semester: $studentSemester', style: style3(), textAlign: TextAlign.center),
                            const Divider(height: 30),
                            Text('Mark Attendance',
                                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                                textAlign: TextAlign.center),
                            const SizedBox(height: 10),
                            Container(
                              constraints: const BoxConstraints(maxHeight: 300),
                              child: ListView.builder(
                                shrinkWrap: true,
                                itemCount: _studentAttendance.length,
                                itemBuilder: (context, index) {
                                  final entry = _studentAttendance.entries.elementAt(index);
                                  return Card(
                                    margin: const EdgeInsets.symmetric(vertical: 5),
                                    child: SwitchListTile(
                                      title: Text(entry.key, textAlign: TextAlign.center),
                                      value: entry.value,
                                      onChanged: (val) {
                                        setState(() {
                                          _studentAttendance[entry.key] = val;
                                        });
                                      },
                                    ),
                                  );
                                },
                              ),
                            ),
                            const SizedBox(height: 20),
                            ElevatedButton.icon(
                              onPressed: markAttendance,
                              icon: const Icon(Icons.check),
                              label: const Text('Submit Attendance'),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                                textStyle: const TextStyle(fontSize: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
                            ),
                          ),
              )
              : Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Lottie.asset(
                  'assets/animations/Animation - 1747299354579.json',
                  width: 150,
                  height: 150,
                  controller: _emojiAnimationController,
                  animate: true,
                  repeat: true,
                ),
                const SizedBox(height: 20),
                Text(
                  studentName.isNotEmpty ? 'Hello, $studentName!' : 'Dear User,',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                AnimatedTextKit(
                  animatedTexts: [
                    TypewriterAnimatedText('No active attendance session.',
                        textStyle: const TextStyle(fontSize: 18, color: Colors.black87),
                        speed: const Duration(milliseconds: 80)),
                    TypewriterAnimatedText('Please wait for the teacher to start a session.',
                        textStyle: const TextStyle(fontSize: 18, color: Colors.black87),
                        speed: const Duration(milliseconds: 80)),
                  ],
                  totalRepeatCount: 1,
                  pause: const Duration(milliseconds: 1000),
                ),
                const SizedBox(height: 15),
                const Text(
                  'Check back later.',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
