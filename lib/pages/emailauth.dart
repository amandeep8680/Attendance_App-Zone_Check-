  import 'package:firebase_auth/firebase_auth.dart';
  import 'package:flutter/material.dart';
  import '../utility/routes.dart';
  import 'dart:async';
  import 'package:firebase_database/firebase_database.dart';


  class EmailVerificationPage extends StatefulWidget {
    const EmailVerificationPage({super.key});

    @override
    State<EmailVerificationPage> createState() => _VerifyEmailPageState();
  }

  class _VerifyEmailPageState extends State<EmailVerificationPage> {
    bool isEmailVerified = false;
    bool canResendEmail = false;
    bool loading = false;

    @override
    void initState() {
      super.initState();

      isEmailVerified = FirebaseAuth.instance.currentUser!.emailVerified;

      if (!isEmailVerified) {
        sendVerificationEmail();

        // Check every 3 seconds if email gets verified
        Timer.periodic(Duration(seconds: 3), (timer) async {
          await FirebaseAuth.instance.currentUser!.reload();
          setState(() {
            isEmailVerified = FirebaseAuth.instance.currentUser!.emailVerified;
          });

          if (isEmailVerified) {
            timer.cancel();
            await updateVerificationStatusInDB();  // ✅ Update DB when verified
          }
        });
      }
    }

    Future sendVerificationEmail() async {
      try {
        final user = FirebaseAuth.instance.currentUser!;
        await user.sendEmailVerification();
        setState(() => canResendEmail = false);
        await Future.delayed(Duration(seconds: 5));
        setState(() => canResendEmail = true);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to send verification email")),
        );
      }
    }
    Future<void> updateVerificationStatusInDB() async {
      final user = FirebaseAuth.instance.currentUser!;
      final uid = user.uid;
      final dbRef = FirebaseDatabase.instance.ref();

      // Try to update under students
      final studentRef = dbRef.child('users/students/$uid');
      final teacherRef = dbRef.child('users/teachers/$uid');

      final DataSnapshot studentSnapshot = await studentRef.get();
      if (studentSnapshot.exists) {
        await studentRef.update({'isVerified': true});
      } else {
        final DataSnapshot teacherSnapshot = await teacherRef.get();
        if (teacherSnapshot.exists) {
          await teacherRef.update({'isVerified': true});
        }
      }
    }

    @override
    Widget build(BuildContext context) {
      if (isEmailVerified) {

        // Navigate once after the frame is built
        Future.microtask(() {
          if (!mounted) return;
          Navigator.pushNamed(context, MyRoutes.studentDashRoute);
        });
        return const Center(child: CircularProgressIndicator());
      }

      return Scaffold(
        appBar: AppBar(title: Text("Email Verification")),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'A verification email has been sent to your email.',
                style: TextStyle(fontSize: 20),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  minimumSize: Size.fromHeight(50),
                ),
                icon: Icon(Icons.email),
                label: Text('Resend Email'),
                onPressed: canResendEmail ? sendVerificationEmail : null,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  minimumSize: Size.fromHeight(50),
                ),
                child: Text('I have verified'),
                  onPressed: () async {
                    setState(() => loading = true);
                    await FirebaseAuth.instance.currentUser!.reload();
                    setState(() {
                      isEmailVerified = FirebaseAuth.instance.currentUser!.emailVerified;
                      loading = false;
                    });

                    if (!isEmailVerified) {
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("Please verify your email first."),
                        ),
                      );
                    }
                  }

              ),
              if (loading) const SizedBox(height: 20),
              if (loading) CircularProgressIndicator(),
            ],
          ),
        )
      );
    }
  }
