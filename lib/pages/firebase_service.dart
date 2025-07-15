import 'dart:developer';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

class FirebaseService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseDatabase _database = FirebaseDatabase.instance;

  /// Registers a new user, sends email verification, and stores user data
  /// under `users/students/uid` or `users/teachers/uid` based on role.
  Future<void> registerUser({
    required String name,
    required String email,
    required String password,
    required String role,
    String? studentClass,
    String? semester,
    String? rollNumber,
    String? teacherCode,
  }) async {
    try {
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      await userCredential.user!.sendEmailVerification();

      final uid = userCredential.user!.uid;
      final path = role == "student" ? "users/students/$uid" : "users/teachers/$uid";

      Map<String, dynamic> userData = {
        'name': name,
        'email': email,
        'role': role,
        'isVerified': false,
      };

      if (role == 'student') {
        userData['studentClass'] = studentClass ?? '';
        userData['semester'] = semester ?? '';
        userData['rollNo'] = rollNumber ?? '';

        // Fetch and assign subjects from admin-defined data
        final subjectsSnapshot = await _database
            .ref('subjects/$studentClass/$semester')
            .get();

        if (subjectsSnapshot.exists) {
          final subjects = subjectsSnapshot.value;

          if (subjects is Map) {
            // Convert subjects Map to List of subject names
            userData['subjects'] = subjects.values.toList();
          } else {
            userData['subjects'] = []; // No subjects available
          }
        } else {
          userData['subjects'] = []; // No subjects available
        }
      } else if (role == 'teacher') {
        userData['teacherCode'] = teacherCode ?? '';
      }

      await _database.ref(path).set(userData);
    } catch (e) {
      log("Registration error: $e");
      rethrow;
    }
  }

  /// Fetches user data by role from `users/students/uid` or `users/teachers/uid`.
  Future<Map<String, dynamic>?> getUserData(String uid, String role) async {
    try {
      final path = role == "student" ? "users/students/$uid" : "users/teachers/$uid";
      final snapshot = await _database.ref(path).get();

      if (snapshot.exists) {
        return Map<String, dynamic>.from(snapshot.value as Map);
      }
    } catch (e) {
      log("Fetch user error: $e");
    }
    return null;
  }

  /// Fetches subjects from the database based on the student's class and semester
  Future<List<String>> fetchSubjects(String studentClass, String semester) async {
    try {
      final subjectsRef = _database.ref('subjects/$studentClass/$semester');
      final snapshot = await subjectsRef.get();

      if (snapshot.exists) {
        final value = snapshot.value;
        if (value is List) {
          return List<String>.from(value);
        } else if (value is Map) {
          // If it's a Map, extract the subject values
          return List<String>.from(value.values.map((e) => e.toString()));
        } else {
          return [];
        }
      }
    } catch (e) {
      log("Failed to fetch subjects: $e");
    }
    return [];
  }
}
