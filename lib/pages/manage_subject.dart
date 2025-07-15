import 'package:attendance_aap/pages/teacher_dash.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

import '../widgets/drawer.dart';

class ManageSubjects extends StatefulWidget {
  @override
  _ManageSubjectsPageState createState() => _ManageSubjectsPageState();
}

class _ManageSubjectsPageState extends State<ManageSubjects> {
  final _formKey = GlobalKey<FormState>();
  TextEditingController subjectController = TextEditingController();
  String selectedClass = "BCA";
  String selectedSemester = "1";
  List<String> subjectList = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchSubjects();
  }

  Future<void> fetchSubjects() async {
    setState(() => isLoading = true);
    final ref =
    FirebaseDatabase.instance.ref('subjects/$selectedClass/$selectedSemester');
    final snapshot = await ref.get();

    subjectList.clear();

    if (snapshot.exists && snapshot.value is Map) {
      Map<dynamic, dynamic> data = snapshot.value as Map<dynamic, dynamic>;
      // Null check and type check within the map
      data.forEach((key, value) {
        if (value != null && value is String) {
          subjectList.add(value);
        }
        else if (value != null) {
          subjectList.add(value.toString());
        }
      });
    }

    setState(() => isLoading = false);
  }

  Future<void> addSubject() async {
    if (_formKey.currentState!.validate()) {
      final subject = subjectController.text.trim();
      if (subject.isNotEmpty) {
        final ref =
        FirebaseDatabase.instance.ref('subjects/$selectedClass/$selectedSemester');
        await ref.push().set(subject);
        subjectController.clear();
        fetchSubjects();
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Subject added successfully!")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
        onWillPop: () async {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => TeacherDash()),
      );
      return false;
    },
    child: Scaffold(
      appBar: AppBar(title: Text("Manage Subjects"),
        centerTitle: true,),
      drawer: MyDrawer(),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            DropdownButtonFormField<String>(
              value: selectedClass,
              onChanged: (val) async {
                setState(() => selectedClass = val!);
                await fetchSubjects();
              },
              items: ['BCA', 'MCA']
                  .map((cls) =>
                  DropdownMenuItem(value: cls, child: Text(cls)))
                  .toList(),
              decoration: InputDecoration(labelText: "Select Class"),
            ),
            SizedBox(height: 10),
            DropdownButtonFormField<String>(
              value: selectedSemester,
              onChanged: (val) async {
                setState(() => selectedSemester = val!);
                await fetchSubjects();
              },
              items: ['1', '2', '3', '4', '5', '6']
                  .map((sem) => DropdownMenuItem(
                  value: sem, child: Text("Semester $sem")))
                  .toList(),
              decoration: InputDecoration(labelText: "Select Semester"),
            ),
            SizedBox(height: 20),
            Form(
              key: _formKey,
              child: TextFormField(
                controller: subjectController,
                decoration: InputDecoration(
                  labelText: "Enter Subject",
                  border: OutlineInputBorder(),
                ),
                validator: (val) =>
                val!.isEmpty ? "Please enter subject" : null,
              ),
            ),
            SizedBox(height: 10),
            ElevatedButton(
              onPressed: addSubject,
              child: Text("Add Subject"),
            ),
            SizedBox(height: 20),
            isLoading
                ? CircularProgressIndicator()
                : Expanded(
              child: subjectList.isEmpty
                  ? Text("No subjects found.")
                  : ListView.builder(
                itemCount: subjectList.length,
                itemBuilder: (context, index) {
                  return Card(
                    child: ListTile(
                      leading: Icon(Icons.book),
                      title: Text(subjectList[index]),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    ),
    );
  }
}

