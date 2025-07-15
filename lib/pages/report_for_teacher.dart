import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';
import '../widgets/drawer.dart';
import 'package:fl_chart/fl_chart.dart';

class ReportForTeacher extends StatefulWidget {
  @override
  _TeacherReportsState createState() => _TeacherReportsState();
}

class _TeacherReportsState extends State<ReportForTeacher> {
  String? selectedClass;
  String? selectedSemester;
  String? selectedSubject;
  bool _isReportView = false;
  DateTime? singleDate;
  DateTime? startDate;
  DateTime? endDate;

  List<String> subjectList = [];
  List<String> classList = [];
  List<Map<String, dynamic>> _attendanceReport = [];
  Map<String, dynamic> _classStats = {};

  final _dbRef = FirebaseDatabase.instance.ref();

  // Load available classes from database
  Future<void> _loadClasses() async {
    final snapshot = await _dbRef.child('subjects').get();
    if (snapshot.exists) {
      final data = snapshot.value as Map<dynamic, dynamic>;
      List<String> loadedClasses = [];
      data.forEach((classKey, value) {
        loadedClasses.add(classKey);
      });

      setState(() {
        classList = loadedClasses;
      });
    }
  }

  // Load subjects based on selected class and semester
  Future<void> _loadSubjects() async {
    if (selectedClass != null && selectedSemester != null) {
      final path = 'subjects/$selectedClass/$selectedSemester';
      final snapshot = await _dbRef.child(path).get();

      if (snapshot.exists) {
        final data = snapshot.value as Map<dynamic, dynamic>;
        List<String> loadedSubjects = [];

        data.forEach((key, value) {
          if (value is String) {
            loadedSubjects.add(value);
          }
        });

        setState(() {
          subjectList = loadedSubjects;
          selectedSubject = null;
        });
      } else {
        setState(() {
          subjectList = [];
          selectedSubject = null;
        });
      }
    }
  }

  // Fetch attendance report based on selected date range
  Future<void> _fetchReport({required bool showStats}) async {
    if (selectedClass != null && selectedSubject != null) {
      Map<String, Map<String, dynamic>> studentSummary = {};

      if (singleDate != null) {
        String formattedDate = DateFormat('yyyy-MM-dd').format(singleDate!);
        await _fetchAttendanceForDate(formattedDate, studentSummary,
            isSingleDate: true); // Pass isSingleDate
      } else if (startDate != null && endDate != null) {
        DateTime date = startDate!;
        while (!date.isAfter(endDate!)) {
          String formatted = DateFormat('yyyy-MM-dd').format(date);
          await _fetchAttendanceForDate(formatted, studentSummary,
              isSingleDate: false); // Pass isSingleDate
          date = date.add(const Duration(days: 1));
        }
      }

      List<Map<String, dynamic>> finalList = studentSummary.values.toList();

      setState(() {
        _attendanceReport = finalList;
        _isReportView = showStats;
        if (showStats && singleDate == null) {
          _generateClassStatistics(finalList);
        } else {
          _classStats = {};
        }
      });

      if (finalList.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("No attendance data found.")),
        );
      }
    }
  }

  // Fetch attendance for a specific date
  Future<void> _fetchAttendanceForDate(
      String date, Map<String, Map<String, dynamic>> studentMap,
      {required bool isSingleDate}) async {
    // Add isSingleDate parameter
    final path = 'attendance/$selectedClass/$date/$selectedSubject';
    final snapshot = await _dbRef.child(path).get();

    if (snapshot.exists) {
      final data = snapshot.value as Map<dynamic, dynamic>;
      data.forEach((studentId, value) {
        if (value is Map<dynamic, dynamic>) {
          String roll = value['rollNumber'] ?? 'NA';
          String name = value['name'] ?? 'Unknown';

          // Safe handling of 'isPresent'
          bool isPresent =
          value['isPresent'] == null ? false : value['isPresent'] as bool;

          if (!studentMap.containsKey(roll)) {
            studentMap[roll] = {
              'rollNumber': roll,
              'name': name,
              'presentCount': 0,
              'absentCount': 0,
            };
            if (isSingleDate) {
              // Initialize isPresent only for single date
              studentMap[roll]!['isPresent'] = isPresent;
            }
          }

          if (!isSingleDate) {
            //  Count only for date ranges.
            if (isPresent) {
              studentMap[roll]!['presentCount'] += 1;
            } else {
              studentMap[roll]!['absentCount'] += 1;
            }
          } else {
            studentMap[roll]!['isPresent'] = isPresent;
          }
        }
      });
    }
  }

  // Generate class statistics based on attendance
  void _generateClassStatistics(List<Map<String, dynamic>> studentList) {
    int total = 0;
    int present = 0;
    int absent = 0;

    for (var student in studentList) {
      int p = student['presentCount'] ?? 0;
      int a = student['absentCount'] ?? 0;
      total += (p + a);
      present += p;
      absent += a;
    }

    double percentage = total > 0 ? (present / total) * 100 : 0;

    setState(() {
      _classStats = {
        'total': total,
        'present': present,
        'absent': absent,
        'percentage': percentage.toStringAsFixed(1),
      };
    });
  }

  // Show date selection popup to user
  Future<void> _showDateSelectionPopup({required bool showStats}) async {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Select Date Option"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ElevatedButton(
                child: const Text("Particular Date"),
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now(),
                    firstDate: DateTime(2024),
                    lastDate: DateTime.now(),
                  );
                  if (picked != null) {
                    setState(() {
                      singleDate = picked;
                      startDate = null;
                      endDate = null;
                    });
                    Navigator.pop(context);
                    await _fetchReport(showStats: showStats);
                  }
                },
              ),
              ElevatedButton(
                child: const Text("Between Dates"),
                onPressed: () async {
                  final pickedStart = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now(),
                    firstDate: DateTime(2024),
                    lastDate: DateTime.now(),
                  );
                  if (pickedStart != null) {
                    final pickedEnd = await showDatePicker(
                      context: context,
                      initialDate: pickedStart,
                      firstDate: pickedStart,
                      lastDate: DateTime.now(),
                    );
                    if (pickedEnd != null) {
                      setState(() {
                        startDate = pickedStart;
                        endDate = pickedEnd;
                        singleDate = null;
                      });
                      Navigator.pop(context);
                      await _fetchReport(showStats: showStats);
                    }
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  String _calculatePercentage(Map<String, dynamic> student) {
    int present = student['presentCount'] ?? 0;
    int absent = student['absentCount'] ?? 0;
    int total = present + absent;
    if (total == 0) return "0.0";
    double percentage = (present / total) * 100;
    return percentage.toStringAsFixed(1);
  }

  @override
  void initState() {
    super.initState();
    _loadClasses(); // Load the classes dynamically when the page is first loaded
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Teacher Report"),
        centerTitle: true,
      ),
      drawer: MyDrawer(),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(15),
        child: Column(
          children: [
            // Class Dropdown dynamically fetched from DB
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(hintText: "Select Class"),
              value: selectedClass,
              items: classList
                  .map((className) => DropdownMenuItem(
                value: className,
                child: Text(className),
              ))
                  .toList(),
              onChanged: (value) async {
                setState(() {
                  selectedClass = value;
                  selectedSemester = null;
                  subjectList = [];
                  selectedSubject = null;
                  _attendanceReport = [];
                  _classStats = {};
                });
                await _loadSubjects(); // Load subjects when class is selected
              },
            ),
            const SizedBox(height: 8),
            // Semester Dropdown
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(hintText: "Select Semester"),
              value: selectedSemester,
              items: const [
                DropdownMenuItem(value: "1", child: Text("Semester 1")),
                DropdownMenuItem(value: "2", child: Text("Semester 2")),
                DropdownMenuItem(value: "3", child: Text("Semester 3")),
                DropdownMenuItem(value: "4", child: Text("Semester 4")),
              ],
              onChanged: (value) async {
                setState(() {
                  selectedSemester = value;
                  selectedSubject = null;
                  subjectList = [];
                  _attendanceReport = [];
                  _classStats = {};
                });
                await _loadSubjects();
              },
            ),
            const SizedBox(height: 8),
            // Subject Dropdown dynamically fetched from DB
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(hintText: "Select Subject"),
              value: selectedSubject,
              items: subjectList
                  .map((subject) => DropdownMenuItem(
                value: subject,
                child: Text(subject),
              ))
                  .toList(),
              onChanged: (value) {
                setState(() {
                  selectedSubject = value;
                  _attendanceReport = [];
                  _classStats = {};
                });
              },
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: () => _showDateSelectionPopup(showStats: true),
                  child: const Text("See Report"),
                ),
              ],
            ),
            const SizedBox(height: 20),
            if (_isReportView && _classStats.isNotEmpty && singleDate == null)
              Column(
                children: [
                  Card(
                    elevation: 4,
                    margin: const EdgeInsets.only(bottom: 12),
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Class Attendance Summary",
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            height: 200,
                            child: PieChart(
                              PieChartData(
                                sectionsSpace: 2,
                                centerSpaceRadius: 40,
                                sections: [
                                  PieChartSectionData(
                                    color: Colors.green,
                                    value:
                                    _classStats['present']?.toDouble() ?? 0,
                                    title:
                                    "${((_classStats['present'] / _classStats['total']) * 100).toStringAsFixed(1)}%",
                                    titleStyle: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white),
                                  ),
                                  PieChartSectionData(
                                    color: Colors.red,
                                    value: _classStats['absent']?.toDouble() ?? 0,
                                    title:
                                    "${((_classStats['absent'] / _classStats['total']) * 100).toStringAsFixed(1)}%",
                                    titleStyle: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            "Total Attendance: ${_classStats['total']}",
                            style: const TextStyle(fontSize: 16),
                          ),
                          Text(
                            "Present: ${_classStats['present']} / Absent: ${_classStats['absent']}",
                            style: const TextStyle(fontSize: 16),
                          ),
                          Text(
                            "Attendance Percentage: ${_classStats['percentage']}%",
                            style: const TextStyle(fontSize: 16),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            // Attendance Report List
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _attendanceReport.length,
              itemBuilder: (ctx, index) {
                // Sort the students based on roll number in ascending order
                _attendanceReport.sort((a, b) {
                  int rollA = int.tryParse(a['rollNumber'] ?? '0') ?? 0;
                  int rollB = int.tryParse(b['rollNumber'] ?? '0') ?? 0;
                  return rollA.compareTo(rollB);
                });

                final student = _attendanceReport[index];

                // Check if it's a single date view
                bool isSingleDateView = singleDate != null;

                return Padding(
                  padding: const EdgeInsets.all(10.0),
                  child: Card(
                    margin: const EdgeInsets.symmetric(vertical: 5),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.white,
                        child: Text(student['rollNumber'] ?? 'NA'),
                      ),
                      title: Text(student['name']),
                      // Conditionally display either full attendance data or just present/absent based on the date range
                      trailing: isSingleDateView
                          ? Text(student['isPresent'] == true
                          ? 'Present'
                          : 'Absent') // Only "Present" or "Absent" for single date
                          : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text("Present: ${student['presentCount']}"),
                          Text("Absent: ${student['absentCount']}"),
                          Text(
                              "Attendance: ${_calculatePercentage(student)}%"),
                        ],
                      ),
                    ),
                  ),
                );
              },
            )
          ],
        ),
      ),
    );
  }}

