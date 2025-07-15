import 'package:attendance_aap/pages/student_dash.dart';
import 'package:attendance_aap/utility/texts.dart';
import 'package:attendance_aap/widgets/drawer.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:firebase_database/firebase_database.dart';
import 'firebase_service.dart';

class Reports extends StatefulWidget {
  @override
  _ReportsState createState() => _ReportsState();
}

class _ReportsState extends State<Reports> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseService _firebaseService = FirebaseService();
  final FirebaseDatabase _database = FirebaseDatabase.instance;
  final DateFormat _dateFormat = DateFormat('yyyy-MM-dd');

  List<String> _subjects = [];
  Map<String, Map<String, bool>> _attendanceData = {};
  bool _isLoading = true;
  String _error = '';
  DateTime? _selectedStartDate;
  DateTime? _selectedEndDate;
  String _selectedSubject = '';
  String _reportType = '';

  @override
  void initState() {
    super.initState();
    _loadSubjects();
  }

  Future<void> _loadSubjects() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        setState(() {
          _isLoading = false;
          _error = "User not logged in.";
        });
        return;
      }

      final userData = await _firebaseService.getUserData(user.uid, 'student');
      if (userData == null) {
        setState(() {
          _isLoading = false;
          _error = "Could not retrieve user data.";
        });
        return;
      }

      final String? studentClass = userData['class'];
      final String? semester = userData['semester'];

      if (studentClass == null || semester == null) {
        setState(() {
          _isLoading = false;
          _error = "Student class or semester not defined.";
        });
        return;
      }

      final subjects = await _firebaseService.fetchSubjects(studentClass, semester);
      setState(() {
        _subjects = subjects;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = "Error loading subjects: $e";
      });
    }
  }

  Future<void> _fetchAttendance(String subject, {required bool fullReport}) async {
    if (_reportType == 'range' && (_selectedStartDate == null || _selectedEndDate == null)) {
      setState(() {
        _error = "Please select start and end dates.";
        _attendanceData.clear();
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = '';
      _attendanceData.clear();
      _selectedSubject = subject;
    });

    try {
      final user = _auth.currentUser;
      if (user == null) {
        setState(() {
          _isLoading = false;
          _error = "User not logged in.";
        });
        return;
      }

      final studentClass = await _getUserClass();
      if (studentClass == null) {
        setState(() {
          _isLoading = false;
          _error = "Student Class not found.";
        });
        return;
      }

      final String studentId = user.uid;
      final String classPath = 'attendance/$studentClass';
      final snapshot = await _database.ref(classPath).get();

      if (snapshot.value == null) {
        setState(() {
          _isLoading = false;
          _attendanceData = {};
        });
        return;
      }

      Map<String, Map<String, bool>> processedData = {};
      Map<dynamic, dynamic> allDates = snapshot.value as Map<dynamic, dynamic>;

      allDates.forEach((date, subjectsMap) {
        final dateObj = _dateFormat.parse(date);
        if (_reportType == 'full' ||
            (_reportType == 'range' && _dateInRange(date)) ||
            (_reportType == 'single' && _selectedStartDate != null && _dateFormat.format(dateObj) == _dateFormat.format(_selectedStartDate!))) {
          final subjectData = subjectsMap[subject];
          if (subjectData is Map) {
            final studentAttendance = subjectData[studentId];
            if (studentAttendance != null &&
                studentAttendance is Map &&
                studentAttendance.containsKey('isPresent')) {
              processedData[date] ??= {};
              processedData[date]![studentId] = studentAttendance['isPresent'] == true;
            }
          }
        }
      });

      setState(() {
        _attendanceData = processedData;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = "Error fetching attendance: $e";
        _attendanceData.clear();
      });
    }
  }

  bool _dateInRange(String dateString) {
    try {
      final date = _dateFormat.parse(dateString);
      return _selectedStartDate != null &&
          _selectedEndDate != null &&
          date.isAfter(_selectedStartDate!.subtract(Duration(days: 1))) &&
          date.isBefore(_selectedEndDate!.add(Duration(days: 1)));
    } catch (_) {
      return false;
    }
  }

  void _showReportOptions(String subject) {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(15))),
      builder: (context) {
        String selectedOption = 'full';
        return StatefulBuilder(
          builder: (context, setState) {
            return Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Choose Report Type", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  SizedBox(height: 10),
                  RadioListTile<String>(
                    title: Text("Full Report"),
                    value: 'full',
                    groupValue: selectedOption,
                    onChanged: (value) {
                      setState(() {
                        selectedOption = value!;
                      });
                    },
                  ),
                  RadioListTile<String>(
                    title: Text("Date Range"),
                    value: 'range',
                    groupValue: selectedOption,
                    onChanged: (value) {
                      setState(() {
                        selectedOption = value!;
                      });
                    },
                  ),
                  RadioListTile<String>(
                    title: Text("Particular Date"),
                    value: 'single',
                    groupValue: selectedOption,
                    onChanged: (value) {
                      setState(() {
                        selectedOption = value!;
                      });
                    },
                  ),
                  SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text("Cancel", style: TextStyle(fontSize: 16)),
                      ),
                      SizedBox(width: 10),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: () async {
                          setState(() {
                            _reportType = selectedOption;
                          });
                          Navigator.of(context).pop();

                          if (selectedOption == 'single') {
                            await _selectDate(context, true);
                            _fetchAttendance(subject, fullReport: false);
                          } else if (selectedOption == 'range') {
                            await _showDateRangeSelector(subject);
                          } else {
                            _fetchAttendance(subject, fullReport: true);
                          }
                        },
                        child: Text("Show Report", style: TextStyle(fontSize: 16)),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _selectDate(BuildContext context, bool isStartDate) async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isStartDate ? (_selectedStartDate ?? DateTime.now()) : (_selectedEndDate ?? DateTime.now()),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        if (isStartDate) {
          _selectedStartDate = picked;
        } else {
          _selectedEndDate = picked;
        }
      });
    }
  }

  Future<void> _showDateRangeSelector(String subject) async {
    await _selectDate(context, true);
    if (_selectedStartDate != null) {
      await _selectDate(context, false);
      if (_selectedEndDate != null) {
        _fetchAttendance(subject, fullReport: false);
      }
    }
  }

  Future<String?> _getUserClass() async {
    final user = _auth.currentUser;
    if (user == null) return null;
    final userData = await _firebaseService.getUserData(user.uid, 'student');
    return userData?['class'];
  }

  Widget _buildSubjectList() {
    return ListView.separated(
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      itemCount: _subjects.length,
      separatorBuilder: (context, index) => SizedBox(height: 8),
      itemBuilder: (context, index) {
        final subject = _subjects[index];
        return Card(
          elevation: 3,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            title: Text(subject, style: TextStyle(fontWeight: FontWeight.w500, fontSize: 16)),
            trailing: Icon(Icons.arrow_forward_ios, size: 18, color: Colors.grey[600]),
            onTap: () => _showReportOptions(subject),
          ),
        );
      },
    );
  }

  Widget _buildAttendanceReport() {
    int totalDays = _attendanceData.length;
    int totalPresent = 0;
    int totalAbsent = 0;

    _attendanceData.forEach((_, studentAttendance) {
      studentAttendance.forEach((_, isPresent) {
        if (isPresent) totalPresent++;
        else totalAbsent++;
      });
    });

    double percentage = totalDays > 0 ? (totalPresent / totalDays) * 100 : 0;

    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Attendance Summary", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Total Days:", style: TextStyle(fontSize: 16, color: Colors.grey[700])),
              Text("$totalDays", style: TextStyle(fontSize: 16)),
            ],
          ),
          SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Present:", style: TextStyle(fontSize: 16, color: Colors.green[700])),
              Text("$totalPresent", style: TextStyle(fontSize: 16)),
            ],
          ),
          SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Absent:", style: TextStyle(fontSize: 16, color: Colors.red[700])),
              Text("$totalAbsent", style: TextStyle(fontSize: 16)),
            ],
          ),
          SizedBox(height: 12),
          Divider(),
          SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Percentage:", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
              Text("${percentage.toStringAsFixed(2)}%", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
            ],
          ),
          SizedBox(height: 15),
          if (_attendanceData.isNotEmpty) ...[
            Text("Date-wise Details:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            SizedBox(height: 8),
            ListView.builder(
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              itemCount: _attendanceData.length,
              itemBuilder: (context, index) {
                final entry = _attendanceData.entries.toList()[index];
                final date = entry.key;
                final present = entry.value.values.first;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(date, style: TextStyle(fontSize: 14)),
                      Text(present ? 'Present' : 'Absent', style: TextStyle(fontSize: 14, color: present ? Colors.green[600] : Colors.red[600])),
                    ],
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => StudentDash()),
        );
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text("Attendance Report"),
          centerTitle: true,
          elevation: 1,
        ),
        drawer: MyDrawer(),
        body: RefreshIndicator(
          onRefresh: _loadSubjects,
          child: SingleChildScrollView(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(child: Text("View Your Attendance", style: style1())),
                SizedBox(height: 20),
                Text("Available Subjects", style: style3()),
                SizedBox(height: 15),
                if (_isLoading)
                  Center(
                    child: Column(
                      children: [
                        CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Colors.indigo)),
                        SizedBox(height: 10),
                        Text("Loading subjects...", style: TextStyle(color: Colors.grey[600])),
                      ],
                    ),
                  )
                else if (_error.isNotEmpty)
                  Center(child: Text("Error: $_error", style: TextStyle(color: Colors.red)))
                else if (_subjects.isEmpty)
                    Center(child: Text("No subjects found for your class.", style: TextStyle(color: Colors.grey[600])))
                  else
                    _buildSubjectList(),
                SizedBox(height: 25),
                if (_selectedSubject.isNotEmpty) ...[
                  Text("Attendance Details for $_selectedSubject", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  SizedBox(height: 15),
                  if (_attendanceData.isNotEmpty)
                    _buildAttendanceReport()
                  else if (!_isLoading && _error.isEmpty)
                    Text("No attendance data available for the selected criteria.", style: TextStyle(color: Colors.grey[600]))
                ]
              ],
            ),
          ),
        ),
      ),
    );
  }
}