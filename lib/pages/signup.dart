import 'package:attendance_aap/pages/login_page.dart';
import 'package:attendance_aap/utility/texts.dart';
import 'package:attendance_aap/utility/routes.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'dart:developer';

class NewUsers extends StatefulWidget {
  const NewUsers({super.key});

  @override
  State<NewUsers> createState() => _NewUsersState();
}

class _NewUsersState extends State<NewUsers> {
  final _formkey = GlobalKey<FormState>();

  // Common fields
  TextEditingController nameController = TextEditingController();
  TextEditingController emailController = TextEditingController();
  TextEditingController passwordController = TextEditingController();
  TextEditingController confirmPasswordController = TextEditingController();

  // Student-specific
  TextEditingController sclassController = TextEditingController();
  TextEditingController rollController = TextEditingController();

  // Teacher-specific
  TextEditingController codeController = TextEditingController();
  TextEditingController semesterController = TextEditingController();

  String role = "student";
  String selectedClass = "BCA"; // Default value
  String selectedSemester = "1"; // Default value
  List<String> availableSubjects = [];

  // Password validation function
  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter password';
    }
    if (value.length < 8) {
      return 'Password must be at least 8 characters';
    }
    if (!value.contains(RegExp(r'[0-9]'))) {
      return 'Password must contain at least one number';
    }
    if (!value.contains(RegExp(r'[a-z]'))) {
      return 'Password must contain at least one lowercase letter';
    }
    if (!value.contains(RegExp(r'[A-Z]'))) {
      return 'Password must contain at least one uppercase letter';
    }
    // Removed special character requirement
    return null;
  }

  void registration() async {
    if (_formkey.currentState!.validate()) {
      String name = nameController.text.trim();
      String email = emailController.text.trim();
      String password = passwordController.text;
      String confirmPassword = confirmPasswordController.text;
      String teacherCode = codeController.text.trim(); // Get teacher code

      if (password != confirmPassword) {
        _showMessage("Passwords do not match");
        log("Error: Passwords do not match");
        return;
      }

      try {
        final auth = FirebaseAuth.instance;
        final dbRef = FirebaseDatabase.instance.ref();

        // Check teacher code for teacher role
        if (role == "teacher") {
          final teacherCodeSnapshot = await dbRef.child('teacherCodes/$teacherCode').get();
          if (!teacherCodeSnapshot.exists || teacherCodeSnapshot.value != true) {
            _showMessage("Invalid Teacher Code");
            log("Error: Invalid Teacher Code: $teacherCode");
            return;
          }
        }

        UserCredential userCred = await auth.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );
        log("User created with email: $email, UID: ${userCred.user?.uid}");

        User? user = userCred.user;

        if (user != null) {
          await user.sendEmailVerification();
          log("Email verification sent to: $email");

          String uid = user.uid;
          String path = role == "student" ? "users/students/$uid" : "users/teachers/$uid";

          Map<String, dynamic> userData = {
            'name': name,
            'email': email,
            'role': role,
            'isVerified': false,
          };

          if (role == "student") {
            String studentClass = selectedClass;
            String semester = selectedSemester;

            userData['class'] = studentClass;
            userData['rollNumber'] = rollController.text.trim();
            userData['semester'] = semester;

            // Fetch subjects for that class + semester
            final subjectSnapshot = await dbRef.child('subjects/$studentClass/$semester').get();

            if (subjectSnapshot.exists) {
              // If it's a map, convert its values to a list
              final subjectMap = subjectSnapshot.value as Map<Object?, Object?>;
              List<String> subjectList = subjectMap.values.map((e) => e.toString()).toList();
              userData['subjects'] = subjectList;
              log("Subjects fetched for student: $subjectList");
            } else {
              userData['subjects'] = [];
              log("No subjects found for class: $studentClass, semester: $semester");
            }
          } else if (role == "teacher") {
            userData['teacherCode'] = teacherCode; // Store the teacher code
            log("Teacher code stored: $teacherCode");
          }

          await dbRef.child(path).set(userData);
          log("User data stored in database at: $path");

          _showMessage("Registered Successfully! Please verify your email.");
          Navigator.pushNamed(context, MyRoutes.emailAuth);
        }
      } on FirebaseAuthException catch (e) {
        log("FirebaseAuthException: ${e.code} - ${e.message}");
        if (e.code == 'weak-password') {
          _showMessage("Password is too weak");
        } else if (e.code == 'email-already-in-use') {
          _showMessage("Account already exists with this email");
        } else {
          _showMessage("Firebase Error: ${e.message}");
        }
      } catch (e) {
        log("Exception: $e");
        _showMessage("Something went wrong. Try again");
      }
    } else {
      _showMessage("Please fill all fields correctly");
      log("Error: Form validation failed");
    }
  }

  void _showMessage(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          msg,
          style: const TextStyle(fontSize: 16),
        ),
      ),
    );
  }

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    semesterController.dispose();
    sclassController.dispose();
    rollController.dispose();
    codeController.dispose();
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
        appBar: AppBar(
          title: const Text("Zone Check"),
          centerTitle: true,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formkey,
            child: Column(
              children: [
                Text("Signup", style: style3()),
                const SizedBox(height: 20),

                // Full Name
                TextFormField(
                  controller: nameController,
                  decoration: const InputDecoration(hintText: "Full Name"),
                  validator: (value) => value!.isEmpty ? 'Please enter name' : null,
                ),
                const SizedBox(height: 20),

                // Email
                TextFormField(
                  controller: emailController,
                  decoration: const InputDecoration(hintText: "Email"),
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) => value!.isEmpty ? 'Please enter email' : null,
                ),
                const SizedBox(height: 20),

                // Password
                TextFormField(
                  controller: passwordController,
                  decoration: const InputDecoration(hintText: "Password"),
                  obscureText: true,
                  validator: _validatePassword, // Use the new validation function
                ),
                const SizedBox(height: 20),

                // Confirm Password
                TextFormField(
                  controller: confirmPasswordController,
                  decoration: const InputDecoration(hintText: "Confirm Password"),
                  obscureText: true,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please confirm password';
                    }
                    if (value != passwordController.text) {
                      return 'Passwords do not match';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                // Role Selection
                DropdownButtonFormField<String>(
                  value: role,
                  decoration: const InputDecoration(hintText: "Select Role"),
                  items: [
                    DropdownMenuItem(value: "student", child: Text("Student")),
                    DropdownMenuItem(value: "teacher", child: Text("Teacher")),
                  ],
                  onChanged: (value) {
                    setState(() {
                      role = value!;
                    });
                  },
                ),
                const SizedBox(height: 20),

                // Role-specific fields
                if (role == 'student') ...[
                  // Class Dropdown
                  DropdownButtonFormField<String>(
                    value: selectedClass,
                    decoration: const InputDecoration(hintText: "Select Class"),
                    items: [
                      DropdownMenuItem(value: "BCA", child: Text("BCA")),
                      DropdownMenuItem(value: "MCA", child: Text("MCA")),
                    ],
                    onChanged: (value) {
                      setState(() {
                        selectedClass = value!;
                      });
                    },
                  ),
                  const SizedBox(height: 20),

                  // Semester Dropdown
                  DropdownButtonFormField<String>(
                    value: selectedSemester,
                    decoration: const InputDecoration(hintText: "Select Semester"),
                    items: [
                      DropdownMenuItem(value: "1", child: Text("Semester 1")),
                      DropdownMenuItem(value: "2", child: Text("Semester 2")),
                      DropdownMenuItem(value: "3", child: Text("Semester 3")),
                      DropdownMenuItem(value: "4", child: Text("Semester 4")),
                    ],
                    onChanged: (value) {
                      setState(() {
                        selectedSemester = value!;
                      });
                    },
                  ),
                  const SizedBox(height: 20),

                  // Roll Number
                  TextFormField(
                    controller: rollController,
                    decoration: const InputDecoration(hintText: "Roll Number"),
                  ),
                  const SizedBox(height: 20),
                ] else if (role == 'teacher') ...[
                  // Teacher Code
                  TextFormField(
                    controller: codeController,
                    decoration: const InputDecoration(hintText: "Teacher Code"),
                    validator: (value) =>
                    value!.isEmpty ? 'Please enter teacher code' : null,
                  ),
                  const SizedBox(height: 20),
                ],

                // Submit Button
                GestureDetector(
                  onTap: registration,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
                    decoration: BoxDecoration(
                      color: Colors.blue,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      "Sign Up",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
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

