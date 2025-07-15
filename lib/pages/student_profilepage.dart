import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:attendance_aap/widgets/drawer.dart';
import 'package:attendance_aap/utility/texts.dart';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import '../utility/routes.dart';
import 'package:shimmer/shimmer.dart';
import '../models/user_model.dart'; // Import the UserModel

class StudentProfilePage extends StatefulWidget {
  @override
  _StudentProfilePageState createState() => _StudentProfilePageState();
}

class _StudentProfilePageState extends State<StudentProfilePage> {
  UserModel? currentUser;
  List<String> _subjects = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    loadUserDetails();
  }

  Future<void> loadUserDetails() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final uid = user.uid;
        final studentSnapshot =
        await FirebaseDatabase.instance.ref('users/students/$uid').get();
        final teacherSnapshot =
        await FirebaseDatabase.instance.ref('users/teachers/$uid').get();

        Map<String, dynamic>? userData;

        if (studentSnapshot.exists) {
          userData =
          Map<String, dynamic>.from(studentSnapshot.value as Map);
        } else if (teacherSnapshot.exists) {
          userData =
          Map<String, dynamic>.from(teacherSnapshot.value as Map);
        }

        if (userData != null) {
          final userModel = UserModel.fromMap(userData, uid);
          List<String> subjects = [];
          if (userModel.role == 'student') {
            subjects = await _fetchSubjects(
                userData['semester'], userData['class']); // Ensure 'class' matches
          }
          setState(() {
            currentUser = userModel;
            _subjects = subjects;
            _isLoading = false;
          });
        } else {
          setState(() {
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      print("Error loading user: $e");
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<List<String>> _fetchSubjects(
      String? semester, String? studentClass) async {
    if (semester == null || studentClass == null) return [];
    final snapshot = await FirebaseDatabase.instance
        .ref('subjects/$studentClass/$semester').get();
    if (snapshot.exists) {
      final Map<dynamic, dynamic>? subjectsData =
      snapshot.value as Map?;
      if (subjectsData != null) {
        return subjectsData.values.toList().cast<String>();
      }
    }
    return [];
  }

  String _generateGravatarUrl(String email) {
    final emailHash =
    md5.convert(utf8.encode(email.trim().toLowerCase())).toString();
    return 'https://www.gravatar.com/avatar/$emailHash?d=identicon&s=200';
  }

  Future<void> _showImageOptionsDialog() async {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(15))),
      builder: (BuildContext context) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text("Choose Profile Picture Option",
                  style: TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            ListTile(
              leading:
              Icon(Icons.face_rounded, color: Colors.indigo),
              title: Text("Use Gravatar",
                  style: TextStyle(fontSize: 16)),
              onTap: () {
                Navigator.of(context).pop();
                _setGravatarProfile();
              },
            ),
            ListTile(
              leading: Icon(Icons.text_fields_rounded,
                  color: Colors.indigo),
              title: Text("Use First Letter of Name",
                  style: TextStyle(fontSize: 16)),
              onTap: () {
                Navigator.of(context).pop();
                _setFirstLetterProfile();
              },
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text("Cancel",
                    style: TextStyle(
                        fontSize: 16, color: Colors.grey)),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _setGravatarProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final gravatarUrl = _generateGravatarUrl(user.email!);
      final uid = user.uid;
      final userRef =
      FirebaseDatabase.instance.ref('users/${currentUser!.role}s/$uid');
      await userRef.update({'profilePicUrl': gravatarUrl});
      setState(() {
        currentUser =
            currentUser!.copyWith(profilePicUrl: gravatarUrl);
      });
    }
  }

  Future<void> _setFirstLetterProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final uid = user.uid;
      final firstLetter =
      currentUser?.name.isNotEmpty ?? false
          ? currentUser!.name[0].toUpperCase()
          : "N";
      final userRef =
      FirebaseDatabase.instance.ref('users/${currentUser!.role}s/$uid');
      await userRef.update({
        'profilePicUrl': null,
        'firstLetter': firstLetter,
      });
      setState(() {
        currentUser = currentUser!.copyWith(
          profilePicUrl: "",
          firstLetter: firstLetter,
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (currentUser?.role == 'teacher') {
          Navigator.of(context)
              .pushReplacementNamed(MyRoutes.teacherDashRoute);
        } else {
          Navigator.of(context)
              .pushReplacementNamed(MyRoutes.studentDashRoute);
        }
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text("My Profile"),
          centerTitle: true,
          elevation: 0, // Remove shadow for a cleaner look
        ),
        drawer: MyDrawer(),
        body: _isLoading
            ? Padding(
          padding: EdgeInsets.all(20),
          child: Shimmer.fromColors(
            baseColor: Colors.grey[300]!,
            highlightColor: Colors.grey[100]!,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment:
                CrossAxisAlignment.center,
                children: [
                  CircleAvatar(
                      radius: 60,
                      backgroundColor: Colors.grey),
                  SizedBox(height: 20),
                  Container(
                      width: 150,
                      height: 20,
                      color: Colors.grey),
                  SizedBox(height: 10),
                  Container(
                      width: 200,
                      height: 20,
                      color: Colors.grey),
                  SizedBox(height: 30),
                  Container(
                      width: 100,
                      height: 16,
                      color: Colors.grey),
                  SizedBox(height: 8),
                  Container(
                      width: double.infinity,
                      height: 16,
                      color: Colors.grey),
                  SizedBox(height: 8),
                  Container(
                      width: double.infinity,
                      height: 16,
                      color: Colors.grey),
                  SizedBox(height: 40),
                  Container(
                      width: double.infinity,
                      height: 45,
                      color: Colors.grey),
                ],
              ),
            ),
          ),
        )
            : (currentUser == null
            ? Center(
            child: Text("No user data found.",
                style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[600])))
            : SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
              horizontal: 20, vertical: 30),
          physics: BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment:
            CrossAxisAlignment.center,
            children: [
              // Profile Picture Section
              Container(
                decoration: BoxDecoration(
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey
                          .withOpacity(0.3),
                      spreadRadius: 2,
                      blurRadius: 5,
                      offset: Offset(0, 3),
                    ),
                  ],
                  shape: BoxShape.circle,
                ),
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 60,
                      backgroundColor:
                      Colors.indigo.shade200,
                      backgroundImage: currentUser!
                          .profilePicUrl !=
                          null &&
                          currentUser!
                              .profilePicUrl!
                              .isNotEmpty
                          ? NetworkImage(
                          currentUser!.profilePicUrl!)
                          : null,
                      child: (currentUser!.profilePicUrl ==
                          null ||
                          currentUser!
                              .profilePicUrl!
                              .isEmpty)
                          ? Text(
                        currentUser!.firstLetter ??
                            "N",
                        style: TextStyle(
                            fontSize: 40,
                            color: Colors.white,
                            fontWeight:
                            FontWeight.bold),
                      )
                          : null,
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: InkWell(
                        onTap:
                        _showImageOptionsDialog,
                        borderRadius:
                        BorderRadius.circular(20),
                        child: Container(
                          padding:
                          EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape:
                            BoxShape.circle,
                            border: Border.all(
                                color: Colors
                                    .grey
                                    .shade300),
                          ),
                          child: Icon(
                              Icons.edit,
                              color: Colors
                                  .indigo,
                              size: 20),
                        ),
                      ),
                    )
                  ],
                ),
              ),
              SizedBox(height: 20),
              Text(currentUser!.name,
                  style: style3()),
              SizedBox(height: 8),
              Text(
                currentUser!.email,
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[700]),
              ),
              Divider(
                  height: 40,
                  thickness: 1,
                  color: Colors.grey[300]),
              // Conditional Rendering based on Role
              if (currentUser!.role == 'student') ...[
                _buildProfileDetailCard(
                    "Class",
                    currentUser!.studentClass ??
                        "N/A",
                    Icons.school_rounded),
                _buildProfileDetailCard(
                    "Roll Number",
                    currentUser!.rollNo ?? "N/A",
                    Icons
                        .format_list_numbered_rounded),
                _buildProfileDetailCard(
                    "Semester",
                    currentUser!.semester ?? "N/A",
                    Icons
                        .calendar_month_rounded),
                _buildProfileDetailCard(
                    "Role",
                    currentUser!.role,
                    Icons.person_rounded),
                SizedBox(height: 30),
                // Subject List
                if (_subjects.isNotEmpty) ...[
                  Text(
                    "Subjects:",
                    style: TextStyle(
                        fontSize: 24,
                        color: Colors.indigo,
                        fontWeight: FontWeight.w700),
                  ),
                  SizedBox(height: 10),
                  Container(
                    decoration: BoxDecoration(
                      borderRadius:
                      BorderRadius.circular(12),
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey
                              .withOpacity(0.2),
                          spreadRadius: 1,
                          blurRadius: 3,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    padding: EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment:
                      CrossAxisAlignment
                          .start,
                      children: _subjects
                          .map((subject) {
                        return Padding(
                          padding:
                          const EdgeInsets
                              .symmetric(
                              vertical:
                              8.0),
                          child: Row(
                            children: [
                              Icon(
                                  Icons
                                      .book_rounded,
                                  color: Colors
                                      .indigo
                                      .shade300,
                                  size: 22),
                              SizedBox(
                                  width: 12),
                              Text(
                                subject,
                                style: TextStyle(
                                    fontSize:
                                    18,
                                    color: Colors
                                        .black87),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ] else ...[
                  Padding(
                    padding:
                    const EdgeInsets.only(
                        top: 10.0),
                    child: Text(
                        "No subjects assigned yet.",
                        style: TextStyle(
                            fontSize: 16,
                            color: Colors
                                .grey[600])),
                  ),
                ],
              ] else if (currentUser!.role ==
                  'teacher') ...[
                _buildProfileDetailCard(
                    "Role",
                    currentUser!.role,
                    Icons.badge_rounded),
                _buildProfileDetailCard(
                    "Teacher Code",
                    currentUser!.rollNo ?? "SPECIAL123",
                    Icons.qr_code_rounded),
              ],
              SizedBox(height: 40),
              // Back to Dashboard Button
              ElevatedButton.icon(
                onPressed: () {
                  if (currentUser?.role ==
                      'teacher') {
                    Navigator.of(context)
                        .pushReplacementNamed(
                        MyRoutes
                            .teacherDashRoute);
                  } else {
                    Navigator.of(context)
                        .pushReplacementNamed(
                        MyRoutes
                            .studentDashRoute);
                  }
                },
                icon: Icon(
                    Icons.home_rounded,
                    color: Colors.white),
                label: Text("Back to Dashboard",
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 16)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.indigo,
                  padding: EdgeInsets.symmetric(
                      horizontal: 30,
                      vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius:
                      BorderRadius.circular(10)),
                  elevation: 2,
                  shadowColor:
                  Colors.indigo.shade200,
                ),
              ),
            ],
          ),
        )),
      ),
    );
  }

  // Refactored Profile Detail Card
  Widget _buildProfileDetailCard(
      String title, String value, IconData icon) {
    return Card(
      elevation: 3,
      margin: EdgeInsets.symmetric(vertical: 8, horizontal: 10),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(
            vertical: 14, horizontal: 18),
        child: Row(
          children: [
            Icon(icon, color: Colors.indigo, size: 26),
            SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment:
                CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          fontSize: 15,
                          color: Colors.grey[700])),
                  SizedBox(height: 6),
                  Text(value,
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                          color: Colors.black87)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

