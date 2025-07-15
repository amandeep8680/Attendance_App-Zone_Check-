import 'package:attendance_aap/pages/login_page.dart';
import 'package:attendance_aap/utility/texts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import '../utility/routes.dart';

class ForgotPassword extends StatefulWidget {
  @override
  State<ForgotPassword> createState() => _ForgotPasswordState();
}

class _ForgotPasswordState extends State<ForgotPassword> {
  String email = "";
  TextEditingController emailcontroller = TextEditingController();
  final _formkey = GlobalKey<FormState>();
  final _auth = FirebaseAuth.instance;
  final _database = FirebaseDatabase.instance.ref();

  resetPassword() async {
    if (_formkey.currentState!.validate()) {
      setState(() {
        email = emailcontroller.text;
      });

      // First, check if the email exists in the database
      bool emailExists = await _checkEmailExists(email);
      if (!emailExists) {
        _showMessage("No user found with this email.");
        return; // Stop the process if the email doesn't exist
      }

      try {
        await _auth.sendPasswordResetEmail(email: email);
        _showMessage("Password Reset Email has been sent");
      } on FirebaseAuthException catch (e) {
        // Handle other Firebase Auth errors (optional, for more specific feedback)
        if (e.code == 'invalid-email') {
          _showMessage("Invalid email address.");
        } else {
          _showMessage("Error: ${e.message}");
        }
      } catch (e) {
        _showMessage("An unexpected error occurred.");
      }
    }
  }

  // Helper function to check if the email exists in the database
  Future<bool> _checkEmailExists(String email) async {
    // Check in both students and teachers nodes.
    DatabaseEvent studentSnapshot = await _database.child('users/students').orderByChild('email').equalTo(email).once();
    DatabaseEvent teacherSnapshot = await _database.child('users/teachers').orderByChild('email').equalTo(email).once();

    if (studentSnapshot.snapshot.value != null || teacherSnapshot.snapshot.value != null) {
      return true; // Email exists in either students or teachers
    }
    return false;
  }

  _showMessage(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(
        msg,
        style: const TextStyle(
          fontSize: 16,
        ),
      ),
    ));
  }

  @override
  void dispose() {
    emailcontroller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => LoginPage()),
        );
        return false;
      },
      child: Scaffold(
          body: Center(
            child: Container(
              width: 350,
              child: Center(
                child: Form(
                 key: _formkey,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "Password Recovery",
                        style: style1(),
                      ),
                      const SizedBox(
                        height: 20,
                      ),
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: TextFormField(
                          controller: emailcontroller,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please Enter Email';
                            }
                            return null;
                          },
                          decoration: InputDecoration(
                            hintText: "Enter your e-mail",
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(
                        height: 10,
                      ),
                      Padding(
                        padding: const EdgeInsets.only(left: 15.0, right: 15.0),
                        child: Container(
                          width: double.infinity,
                          child: ElevatedButton(
                              onPressed: () {
                                if (_formkey.currentState!.validate()) {
                                  resetPassword();
                                }
                              },
                              child: Text(
                                "Send Email",
                                style: style2(),
                              )),
                        ),
                      ),
                      const SizedBox(
                        height: 20,
                      ),
                      Container(
                        width: double.infinity,
                        // color: Colors.red,
                        child: Center(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text("Don't have an account?"),
                              // SizedBox(width:2),
                              ElevatedButton(
                                onPressed: () {
                                  Navigator.pushNamed(context, MyRoutes.signupRoute);
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  elevation: 0,
                                ),
                                child: const Text(
                                  "Sign Up",
                                  style: TextStyle(color: Colors.blueGrey, fontSize: 15),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Container(
                        width: double.infinity,
                        // color: Colors.red,
                        child: Center(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text("Click here to"),
                              // SizedBox(width:2),
                              ElevatedButton(
                                onPressed: () {
                                  Navigator.pushNamed(context, MyRoutes.loginRoute);
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  elevation: 0,
                                ),
                                child: const Text(
                                  "Login",
                                  style: TextStyle(color: Colors.blueGrey, fontSize: 15),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          )),
    );
  }
}
