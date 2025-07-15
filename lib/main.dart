import 'package:attendance_aap/pages/emailauth.dart';
import 'package:attendance_aap/pages/forgot_password.dart';
import 'package:attendance_aap/pages/home_page.dart';
import 'package:attendance_aap/pages/login_page.dart';
import 'package:attendance_aap/pages/manage_subject.dart';
import 'package:attendance_aap/pages/student_dash.dart';
import 'package:attendance_aap/pages/student_profilepage.dart';
import 'package:attendance_aap/pages/teacher_dash.dart';
import 'package:attendance_aap/pages/marked.dart';
import 'package:attendance_aap/pages/report.dart';
import 'package:attendance_aap/pages/signup.dart';
import 'package:attendance_aap/utility/routes.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp().then((value) {
    runApp(MyApp());
  }).catchError((e) {
    print("Firebase initialization failed: $e");
  });
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
        title: "Zone Check",
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.white70),
          useMaterial3: false,
        ),
        initialRoute: "/MyHomePage",
        routes: {
          MyRoutes.homeRoute: (context) => MyHomePage(),
          MyRoutes.loginRoute: (context) => LoginPage(),
          MyRoutes.signupRoute: (context) => NewUsers(),
          MyRoutes.studentDashRoute: (context) => StudentDash(),
          MyRoutes.teacherDashRoute: (context) => TeacherDash(),
          MyRoutes.reportRoute: (context) => Reports(),
          MyRoutes.markedRoute: (context) => Marked(),
          MyRoutes.emailAuth: (context) => EmailVerificationPage(),
          MyRoutes.forgotPass: (context) => ForgotPassword(),
          MyRoutes.studentProfile: (context) => StudentProfilePage(),
          MyRoutes.manageSubjectsRoute: (context) => ManageSubjects(),
        });
  }
}
