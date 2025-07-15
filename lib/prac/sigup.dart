import 'package:flutter/material.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Attendance App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.deepPurple,
      ),
      home: SignUpPage(),
    );
  }
}

class SignUpPage extends StatefulWidget {
  @override
  _SignUpPageState createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final classController = TextEditingController();
  final rollNumberController = TextEditingController();

  String? selectedRole;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Sign Up')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            children: [
              // Full Name
              TextField(
                controller: nameController,
                decoration: InputDecoration(labelText: 'Full Name'),
              ),

              // Email
              TextField(
                controller: emailController,
                decoration: InputDecoration(labelText: 'Email'),
                keyboardType: TextInputType.emailAddress,
              ),

              // Password
              TextField(
                controller: passwordController,
                decoration: InputDecoration(labelText: 'Password'),
                obscureText: true,
              ),

              // Role Dropdown
              DropdownButtonFormField<String>(
                decoration: InputDecoration(labelText: 'Role'),
                value: selectedRole,
                items: ['Student', 'Teacher','Stuent'].map((role) {
                  return DropdownMenuItem(
                    value: role.toLowerCase(),
                    child: Text(role),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    selectedRole = value;
                  });
                },
              ),

              // Show class & roll number only if student is selected
              if (selectedRole == 'student') ...[
                TextField(
                  controller: classController,
                  decoration: InputDecoration(labelText: 'Class Name'),
                ),
                TextField(
                  controller: rollNumberController,
                  decoration: InputDecoration(labelText: 'Roll Number'),
                ),
              ],

              


              SizedBox(height: 20),

              ElevatedButton(
                onPressed: () {
                  print("Sign up clicked");
                  print("Name: ${nameController.text}");
                  print("Email: ${emailController.text}");
                  print("Password: ${passwordController.text}");
                  print("Role: $selectedRole");

                  if (selectedRole == 'student') {
                    print("Class: ${classController.text}");
                    print("Roll No: ${rollNumberController.text}");
                  }
                },
                child: Text('Sign Up'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
