import 'package:attendance_aap/pages/login_page.dart';
import 'package:attendance_aap/pages/report.dart';
import 'package:attendance_aap/pages/report_for_teacher.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:attendance_aap/utility/routes.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';
import '../pages/student_dash.dart';
import '../utility/texts.dart';

class MyDrawer extends StatefulWidget {
  @override
  _MyDrawerState createState() => _MyDrawerState();
}

class _MyDrawerState extends State<MyDrawer> {
  String userName = "";
  String userEmail = "";
  String userRole = "";
  String? profilePicUrl;
  String? firstLetter;

  @override
  void initState() {
    super.initState();
    loadUserDetails();
  }

  Future<void> loadUserDetails() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;

      if (currentUser != null) {
        final uid = currentUser.uid;

        final studentSnapshot =
        await FirebaseDatabase.instance.ref('users/students/$uid').get();
        final teacherSnapshot =
        await FirebaseDatabase.instance.ref('users/teachers/$uid').get();

        Map<String, dynamic>? userData;

        if (studentSnapshot.exists) {
          userData = Map<String, dynamic>.from(studentSnapshot.value as Map);
          userRole = "student";
        } else if (teacherSnapshot.exists) {
          userData = Map<String, dynamic>.from(teacherSnapshot.value as Map);
          userRole = "teacher";
        }

        if (userData != null) {
          final userModel = UserModel.fromMap(userData, uid);

          setState(() {
            userName = userModel.name;
            userEmail = userModel.email;
            profilePicUrl = userModel.profilePicUrl;
            firstLetter =
                userModel.firstLetter ?? userModel.name.substring(0, 1).toUpperCase();
          });
        } else {
          print("User data not found in database.");
        }
      } else {
        print("No user is logged in.");
      }
    } catch (e) {
      print("Failed to load user data: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: Container(
        color: Colors.cyan.shade800,
        child: ListView(
          children: [
            DrawerHeader(
              padding: EdgeInsets.zero,
              child: UserAccountsDrawerHeader(
                margin: EdgeInsets.zero,
                accountName: Text(
                  userName,
                  style: TextStyle(fontSize: 20),
                ),
                accountEmail: Text(
                  userEmail,
                  style: TextStyle(fontSize: 20),
                ),
                currentAccountPicture: CircleAvatar(
                  radius: 40,
                  backgroundColor: Colors.blueGrey,
                  backgroundImage: (profilePicUrl != null && profilePicUrl!.isNotEmpty)
                      ? NetworkImage(profilePicUrl!)
                      : null,
                  child: (profilePicUrl == null || profilePicUrl!.isEmpty)
                      ? Text(
                    firstLetter ?? "N",
                    style: TextStyle(fontSize: 30, color: Colors.white),
                  )
                      : null,
                ),
              ),
            ),

            // Profile - Always visible
            ListTile(
              leading: Icon(CupertinoIcons.profile_circled, color: Colors.white70),
              title: Text("Profile", style: style2()),
              onTap: () {
                Navigator.pushNamed(context, MyRoutes.studentProfile);
              },
            ),

            // Student-only options
            if (userRole == "student") ...[
              ListTile(
                leading: Icon(CupertinoIcons.add_circled, color: Colors.white70),
                title: Text("Do Attendance", style: style2()),
                onTap: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (context) => StudentDash()),
                  );
                },
              ),
              ListTile(
                leading: Icon(CupertinoIcons.check_mark_circled, color: Colors.white70),
                title: Text("Attendance Report", style: style2()),
                onTap: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (context) => Reports()),
                  );
                },
              ),
            ],

            // Teacher-only options
            if (userRole == "teacher") ...[
              ListTile(
                leading: Icon(CupertinoIcons.check_mark_circled, color: Colors.white70),
                title: Text("Take Attendance", style: style2()),
                onTap: () {
                  Navigator.pushNamed(context, MyRoutes.teacherDashRoute);
                },
              ),
              ListTile(
                leading: Icon(CupertinoIcons.check_mark_circled, color: Colors.white70),
                title: Text("Student's Report", style: style2()),
                onTap: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (context) => ReportForTeacher()),
                  );
                },
              ),
              ListTile(
                leading: Icon(CupertinoIcons.add_circled, color: Colors.white70),
                title: Text("Manage Subjects", style: style2()),
                onTap: () {
                  Navigator.pushNamed(context, MyRoutes.manageSubjectsRoute);
                },
              ),
            ],

            // Notes - Always visible
            // ListTile(
            //   leading: Icon(CupertinoIcons.book, color: Colors.white70),
            //   title: Text("Notes", style: style2()),
            // ),

            // Logout - Always visible
            ListTile(
              leading: Icon(CupertinoIcons.power, color: Colors.white70),
              title: Text("Logout", style: style2()),
              onTap: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => LoginPage()),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
