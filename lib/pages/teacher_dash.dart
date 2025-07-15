import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import '../widgets/drawer.dart';
import 'package:geolocator/geolocator.dart';
import 'package:uuid/uuid.dart';
import 'dart:async';
//import 'package:google_fonts/google_fonts.dart'; // Removed google_fonts
import 'package:flutter_svg/flutter_svg.dart'; // For SVG icons

class TeacherDash extends StatefulWidget {
  @override
  _TeacherDashState createState() => _TeacherDashState();
}

class _TeacherDashState extends State<TeacherDash> {
  // Firebase instances
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();
  DatabaseReference? _teacherLocationRef;

  // Session Management
  String? _sessionId;
  bool _isSessionActive = false;

  // Selection variables
  String selectedClass = '';
  String selectedSemester = '';
  String selectedSubject = '';
  String selectedSection = 'A'; // Default section
  DateTime selectedDate = DateTime.now();
  DateTime? lastBackPressed;
  // Data storage
  Map<String, bool> studentAttendance = {};
  Map<String, Map<String, dynamic>> studentDataMap = {};
  bool isLoading = false;
  String? _errorMessage;

  // Teacher information
  String _teacherName = '';
  String _teacherId = '';

  // Dropdown lists
  List<String> classes = [];
  List<String> semesters = [];
  List<String> subjects = [];
  List<String> sections = ['A', 'B']; // Added sections list

  // Location tracking
  StreamSubscription? _locationSubscription;
  bool _useLocation = false;

  // Attendance display
  Map<String, dynamic> _presentStudents = {};
  Map<String, dynamic> _absentStudents = {};
  bool _showAttendanceLists = false;

  @override
  void initState() {
    super.initState();
    fetchClasses();
    _getTeacherName();
  }

  @override
  void dispose() {
    _locationSubscription?.cancel();
    super.dispose();
  }

  // Fetch teacher's name from Firebase
  Future<void> _getTeacherName() async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        _teacherId = user.uid;
        final snapshot = await _dbRef.child('users/teachers/$_teacherId').get();
        if (snapshot.exists) {
          final data = snapshot.value as Map?;
          _teacherName = data?['name'] ?? 'Unknown Teacher';
        } else {
          _teacherName = 'Unknown Teacher';
        }
      } else {
        _teacherName = 'Unknown Teacher';
      }
      if (mounted) setState(() {});
    } catch (e) {
      _teacherName = 'Unknown Teacher';
      if (mounted) setState(() {});
    }
  }

  // Show error dialog
  void _showErrorDialog(String message) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Error', /*style: GoogleFonts.poppins(fontWeight: FontWeight.w600)*/), // Removed
        content: Text(message, /*style: GoogleFonts.poppins()*/), // Removed
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Okay', /*style: GoogleFonts.poppins(fontWeight: FontWeight.w500)*/), // Removed
          ),
        ],
      ),
    );
  }

  // Fetch classes from Firebase
  Future<void> fetchClasses() async {
    try {
      final snapshot = await _dbRef.child('subjects').get();
      if (snapshot.exists && snapshot.value is Map) {
        final data = snapshot.value as Map;
        classes = data.keys.cast<String>().toList();
        if (classes.isNotEmpty) {
          selectedClass = classes.first;
          await fetchSemesters();
        }
        _errorMessage = null;
      } else {
        _errorMessage = "No classes found.";
      }
    } catch (error) {
      _errorMessage = "Failed to fetch classes: $error";
      _showErrorDialog(_errorMessage!);
    } finally {
      if (mounted) setState(() {});
    }
  }

  // Fetch semesters for a selected class
  Future<void> fetchSemesters() async {
    if (selectedClass.isEmpty) return;
    try {
      final snapshot = await _dbRef.child('subjects/$selectedClass').get();
      if (snapshot.exists && snapshot.value is List) {
        final data = snapshot.value as List;
        semesters = data
            .asMap()
            .keys
            .map((e) => (e + 1).toString())
            .toList();
        if (semesters.isNotEmpty) {
          selectedSemester = semesters.first;
          await fetchSubjects();
          await fetchStudents();
        }
        _errorMessage = null;
      } else {
        _errorMessage = "No semesters found for class $selectedClass.";
      }
    } catch (error) {
      _errorMessage = "Failed to fetch semesters: $error";
      _showErrorDialog(_errorMessage!);
    } finally {
      if (mounted) setState(() {});
    }
  }

  // Fetch subjects for a selected class and semester
  Future<void> fetchSubjects() async {
    if (selectedClass.isEmpty || selectedSemester.isEmpty) return;
    try {
      final snapshot = await _dbRef.child(
          'subjects/$selectedClass/$selectedSemester').get();
      if (snapshot.exists && snapshot.value is Map) {
        final data = snapshot.value as Map;
        subjects = data.values.toList().cast<String>();
        selectedSubject = subjects.isNotEmpty ? subjects.first : '';
        _errorMessage = null;
      } else {
        _errorMessage = "No subjects found.";
      }
    } catch (error) {
      _errorMessage = "Failed to fetch subjects: $error";
      _showErrorDialog(_errorMessage!);
    } finally {
      if (mounted) setState(() {});
    }
  }

  // Fetch students for a selected class and semester
  Future<void> fetchStudents() async {
    if (selectedClass.isEmpty || selectedSemester.isEmpty) return;
    setState(() => isLoading = true);
    studentAttendance.clear();
    studentDataMap.clear();
    try {
      final snapshot = await _dbRef.child('users/students').get();
      if (snapshot.exists && snapshot.value is Map) {
        final data = snapshot.value as Map;
        data.forEach((uid, studentData) {
          if (studentData is Map &&
              studentData['class'] == selectedClass &&
              studentData['semester'] == selectedSemester) {
            final name = studentData['name'] ?? 'Unknown';
            final rollNumber = studentData['rollNumber']?.toString() ?? 'N/A';
            studentAttendance[uid] = false;
            studentDataMap[uid] = {'name': name, 'rollNumber': rollNumber};
          }
        });

        final sortedKeys = studentDataMap.keys.toList()
          ..sort((a, b) {
            final rollA = studentDataMap[a]?['rollNumber'] ?? 'N/A';
            final rollB = studentDataMap[b]?['rollNumber'] ?? 'N/A';
            return rollA.compareTo(rollB);
          });

        final sortedAttendance = <String, bool>{};
        sortedKeys.forEach((uid) {
          sortedAttendance[uid] = studentAttendance[uid]!;
        });
        studentAttendance = sortedAttendance;

        _errorMessage = null;
      } else {
        _errorMessage = "No students found for the selected class and semester.";
      }
    } catch (e) {
      _errorMessage = "Failed to fetch students: $e";
      _showErrorDialog(_errorMessage!);
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  // Mark all students present or absent
  void markAll(bool isPresent) {
    setState(() {
      studentAttendance.updateAll((key, value) => isPresent);
    });
  }

  // Request location permission and start/stop session
  Future<void> _requestLocationPermission() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _showErrorDialog('Location permission is required.');
        return;
      }
    }
    if (permission == LocationPermission.deniedForever) {
      _showErrorDialog('Location permission permanently denied.');
      return;
    }

    try {
      Position position = await Geolocator.getCurrentPosition();
      if (_isSessionActive) {
        await _stopAttendanceSession();
      } else {
        _sessionId = const Uuid().v4();
        DatabaseReference sessionRef = _dbRef.child(
            'attendance_sessions/$_sessionId');
        _teacherLocationRef = sessionRef;
        await sessionRef.set({
          'teacherLatitude': position.latitude,
          'teacherLongitude': position.longitude,
          'timestamp': ServerValue.timestamp,
          'class': selectedClass,
          'semester': selectedSemester,
          'subject': selectedSubject,
          'sessionId': _sessionId,
          'active': true,
          'teacherName': _teacherName,
          'teacherId': _teacherId,
          'startTime': DateTime.now().toIso8601String(),
        });
        _isSessionActive = true;
      }
    } catch (e) {
      _showErrorDialog("Failed to get location: $e");
    } finally {
      setState(() {});
    }
  }

  // Stop attendance session and clear data
  Future<void> _stopAttendanceSession() async {
    if (_sessionId != null) {
      await _dbRef.child('attendance_sessions/$_sessionId').update({
        'active': false,
        'endTime': DateTime.now().toIso8601String(),
      });
      _isSessionActive = false;
      await _fetchAttendanceData(); // Fetch data when session ends.
      _sessionId = null;
    }
    setState(() {});
  }

  // Fetch attendance data for display
  Future<void> _fetchAttendanceData() async {
    if (_sessionId == null) return;

    setState(() => isLoading = true);
    _presentStudents.clear();
    _absentStudents.clear();
    try {
      final snapshot = await _dbRef
          .child('attendance_sessions/$_sessionId')
          .get();
      if (snapshot.exists && snapshot.value != null) {
        final sessionData = snapshot.value as Map;

        final date = sessionData['startTime'].toString().split('T')[0];
        final safeSubject = sessionData['subject'].toString().replaceAll('.', '_');
        final attendanceRef =
        _dbRef.child('attendance/${sessionData['class']}/$date/$safeSubject');

        final attendanceSnapshot = await attendanceRef.get();

        if (attendanceSnapshot.exists && attendanceSnapshot.value != null) {
          final attendanceData = attendanceSnapshot.value as Map;

          attendanceData.forEach((studentUid, attendance) {
            final studentInfo = studentDataMap[studentUid];
            if (studentInfo != null) {
              final studentName = studentInfo['name'];
              final rollNumber = studentInfo['rollNumber'];
              final studentNameWithRoll = '$rollNumber - $studentName';
              if (attendance['isPresent'] == true) {
                _presentStudents[studentUid] = studentNameWithRoll;
              } else {
                _absentStudents[studentUid] = studentNameWithRoll;
              }
            }
          });
        }
      }
    } catch (e) {
      _showErrorDialog("Error fetching attendance data: $e");
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  // Save attendance data to Firebase
  Future<void> _saveAttendance() async {
    final date = DateTime.now().toIso8601String().split('T')[0];
    final safeSubject = selectedSubject.replaceAll('.', '_');
    final attendanceRef =
    _dbRef.child('attendance/$selectedClass/$date/$safeSubject');

    try {
      final List<Future> saveTasks = [];

      studentAttendance.forEach((studentUid, isPresent) {
        final studentInfo = studentDataMap[studentUid]!;
        final studentName = studentInfo['name'];
        final rollNumber = studentInfo['rollNumber'];

        final studentAttendanceData = {
          'name': studentName,
          'rollNumber': rollNumber,
          'isPresent': isPresent,
          'timestamp': ServerValue.timestamp,
          'markedBy': _teacherId,
        };

        final studentPath = attendanceRef.child(studentUid);
        saveTasks.add(studentPath.set(studentAttendanceData));
      });

      await Future.wait(saveTasks);

      _showMessageDialog("Attendance saved successfully!");
    } catch (e) {
      _showErrorDialog("Error saving attendance: $e");
    }
  }

  // Show success message dialog
  void _showMessageDialog(String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("Success", /*style: GoogleFonts.poppins(fontWeight: FontWeight.w600)*/), // Removed
        content: Text(message, /*style: GoogleFonts.poppins()*/), // Removed
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
            },
            child: Text("OK", /*style: GoogleFonts.poppins(fontWeight: FontWeight.w500)*/), // Removed
          ),
        ],
      ),
    );
  }


  Future<bool> _onWillPop() async {
    final now = DateTime.now();
    if (lastBackPressed == null || now.difference(lastBackPressed!) > Duration(seconds: 2)) {
      lastBackPressed = now;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Press back again to exit',
            /*style: GoogleFonts.poppins()*/ // Removed
          ),
          duration: const Duration(seconds: 2),
        ),
      );
      return false;
    }
    // Exit app
    SystemNavigator.pop();
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        appBar: AppBar(
          title: Text("Teacher Dashboard", /*style: GoogleFonts.poppins(fontWeight: FontWeight.w600)*/), // Removed
          centerTitle: true, // Consistent AppBar color
          elevation: 0, // Remove shadow for a cleaner look
        ),
        drawer: MyDrawer(),
        backgroundColor: Colors.grey[100], // Light background
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: SingleChildScrollView( // Make the whole body scrollable
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, // Align items to the start
              children: [
                // Location Attendance Switch
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.2),
                        spreadRadius: 1,
                        blurRadius: 3,
                        offset: const Offset(0, 1), // changes position of shadow
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween, // Space between text and switch
                    children: [
                      Text('Use Location Attendance', /*style: GoogleFonts.poppins(fontSize: 16)*/), // Removed
                      Switch(
                        value: _useLocation,
                        onChanged: (value) {
                          setState(() {
                            _useLocation = value;
                            if (!_useLocation && _isSessionActive) {
                              _stopAttendanceSession();
                            } else if (_useLocation && _isSessionActive) {
                              _stopAttendanceSession();
                            }
                            _showAttendanceLists = false;
                          });
                        },
                        activeColor: Colors.indigo, // Consistent active color
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Dropdown Form Fields
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.2),
                        spreadRadius: 1,
                        blurRadius: 3,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: DropdownButtonFormField<String>(
                    value: selectedClass.isEmpty ? null : selectedClass,
                    items: classes.map((e) => DropdownMenuItem(value: e, child: Text(e, /*style: GoogleFonts.poppins()*/))).toList(), // Removed
                    onChanged: (val) {
                      selectedClass = val!;
                      fetchSemesters();
                    },
                    decoration: InputDecoration(
                      labelText: 'Class',
                      //labelStyle: GoogleFonts.poppins(), // Removed
                      border: InputBorder.none, // Remove underline
                    ),
                    //style: GoogleFonts.poppins(), // Removed
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.2),
                        spreadRadius: 1,
                        blurRadius: 3,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: DropdownButtonFormField<String>(
                    value: selectedSemester.isEmpty ? null : selectedSemester,
                    items: semesters.map((e) => DropdownMenuItem(value: e, child: Text('Semester $e', /*style: GoogleFonts.poppins()*/))).toList(), // Removed
                    onChanged: (val) {
                      selectedSemester = val!;
                      fetchSubjects();
                      fetchStudents();
                    },
                    decoration: InputDecoration(
                      labelText: 'Semester',
                      //labelStyle: GoogleFonts.poppins(), // Removed
                      border: InputBorder.none,
                    ),
                    //style: GoogleFonts.poppins(), // Removed
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.2),
                        spreadRadius: 1,
                        blurRadius: 3,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: DropdownButtonFormField<String>(
                    value: selectedSubject.isEmpty ? null : selectedSubject,
                    items: subjects.map((e) => DropdownMenuItem(value: e, child: Text(e, /*style: GoogleFonts.poppins()*/))).toList(), // Removed
                    onChanged: (val) => setState(() => selectedSubject = val!),
                    decoration: InputDecoration(
                      labelText: 'Subject',
                      //labelStyle: GoogleFonts.poppins(), // Removed
                      border: InputBorder.none,
                    ),
                    //style: GoogleFonts.poppins(), // Removed
                  ),
                ),

                const SizedBox(height: 20),
                // Location Session Button
                if (_useLocation)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.2),
                          spreadRadius: 1,
                          blurRadius: 3,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Column(
                        children: [
                          Text("Range to mark attendance is 10mtr", /*style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey[600])*/), // Removed
                          const SizedBox(height: 12),
                          ElevatedButton(
                            onPressed: _requestLocationPermission,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _isSessionActive ? Colors.redAccent : Colors.indigo,
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              //textStyle: GoogleFonts.poppins(fontWeight: FontWeight.w500), // Removed
                            ),
                            child: Text(_isSessionActive
                                ? 'Stop Attendance Session'
                                : 'Start Attendance Session',
                                style: const TextStyle(color: Colors.white)),
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 20),

                // Loading Indicator
                if (isLoading)
                  Center(
                    child: CircularProgressIndicator(
                      valueColor: const AlwaysStoppedAnimation<Color>(Colors.indigo),
                    ),
                  ),

                // Mark Attendance UI
                if (!_useLocation && studentAttendance.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.2),
                          spreadRadius: 1,
                          blurRadius: 3,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(child: Text('Mark Attendance:', /*style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600)*/)), // Removed
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            ElevatedButton(
                              onPressed: () {
                                markAll(true);
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                //textStyle: GoogleFonts.poppins(fontWeight: FontWeight.w500, fontSize: 14), // Removed
                              ),
                              child: const Text('Mark All Present', style: TextStyle(color: Colors.white)),
                            ),
                            ElevatedButton(
                              onPressed: () {
                                markAll(false);
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.redAccent,
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                //textStyle: GoogleFonts.poppins(fontWeight: FontWeight.w500, fontSize: 14), // Removed
                              ),
                              child: const Text('Mark All Absent', style: TextStyle(color: Colors.white)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(), // Disable listview scrolling
                          itemCount: studentAttendance.length,
                          itemBuilder: (context, index) {
                            final uid = studentAttendance.keys.toList()[index];
                            final studentInfo = studentDataMap[uid];
                            final displayName = studentInfo != null
                                ? '${studentInfo['rollNumber']} - ${studentInfo['name']}'
                                : 'Unknown Student';
                            return Container(
                              margin: const EdgeInsets.symmetric(vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.grey[50], // Very light background for each list item
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: CheckboxListTile(
                                title: Text(displayName, /*style: GoogleFonts.poppins()*/), // Removed
                                value: studentAttendance[uid],
                                onChanged: (val) {
                                  setState(() {
                                    studentAttendance[uid] = val!;
                                  });
                                },
                                controlAffinity: ListTileControlAffinity.leading, // Checkbox on the left
                                activeColor: Colors.indigo, // Consistent checkbox color
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 20),
                        Center(
                          child: ElevatedButton(
                            onPressed: _saveAttendance,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.indigo,
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              //textStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 16), // Removed
                            ),
                            child: const Text('Save Attendance', style: TextStyle(color: Colors.white)),
                          ),
                        ),
                      ],
                    ),
                  ),

                // Attendance Lists
                if (_showAttendanceLists)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.2),
                          spreadRadius: 1,
                          blurRadius: 3,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                            'Present Students',),
                        const SizedBox(height: 8),
                        if (_presentStudents.isNotEmpty)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: _presentStudents.values.map((name) => Text(name, /*style: GoogleFonts.poppins()*/)).toList(), // Removed
                          )
                        else
                          Text('No present students.', /*style: GoogleFonts.poppins(color: Colors.grey[600])*/), // Removed
                        const SizedBox(height: 20),
                        Text(
                            'Absent Students',
                         ),
                        const SizedBox(height: 8),
                        if (_absentStudents.isNotEmpty)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: _absentStudents.values.map((name) => Text(name, /*style: GoogleFonts.poppins()*/)).toList(), // Removed
                          )
                        else
                          Text('No absent students.', /*style: GoogleFonts.poppins(color: Colors.grey[600])*/), // Removed
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

