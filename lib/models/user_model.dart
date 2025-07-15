// working
import 'package:firebase_auth/firebase_auth.dart';

class UserModel {
  String? id;
  String name;
  String email;
  String role;
  bool isVerified;

  // Student-specific fields
  String? rollNo;
  String? studentClass;
  String? semester; // Should store as "sem1", "sem2", etc.
  final String? firstLetter;
  // Optional for both
  String? profilePicUrl;

  UserModel({
    this.id,
    required this.name,
    required this.email,
    required this.role,
    this.isVerified = false,
    this.rollNo,
    this.studentClass,
    this.semester,
    this.profilePicUrl,
    this.firstLetter,
  });

  /// Convert UserModel to a map for Firebase
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'email': email,
      'role': role,
      'isVerified': isVerified,
      'rollNumber': rollNo, // Corrected key
      'class': studentClass, // Corrected key
      'semester': semester, // expected to be like "sem1", "sem2"
      'profilePicUrl': profilePicUrl,
    };
  }

  /// Create a UserModel from Firebase Map
  factory UserModel.fromMap(Map<dynamic, dynamic> map, String id) {
    return UserModel(
      id: id,
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      role: map['role'] ?? 'student',
      isVerified: map['isVerified'] ?? false,
      rollNo: map['rollNumber'], // Corrected key
      studentClass: map['class'], // Corrected key
      semester: map['semester'], // expected to be like "sem1", "sem2"
      profilePicUrl: map['profilePicUrl'],
      firstLetter: map['firstLetter'],
    );
  }

  /// Create from FirebaseAuth User (useful at signup)
  factory UserModel.fromFirebaseUser(
      User user,
      String role, {
        String? rollNo,
        String? studentClass,
        String? semester,
        String? profilePicUrl,
      }) {
    return UserModel(
      id: user.uid,
      name: user.displayName ?? '',
      email: user.email ?? '',
      role: role,
      isVerified: user.emailVerified,
      rollNo: rollNo,
      studentClass: studentClass,
      semester: semester,
      profilePicUrl: profilePicUrl,
    );
  }

  /// Get Firebase path based on role
  String getDatabasePath() {
    return role == 'teacher'
        ? 'users/teachers/$id'
        : 'users/students/$id';
  }

  /// Copy with method to create updated copies
  UserModel copyWith({
    String? id,
    String? name,
    String? email,
    String? role,
    bool? isVerified,
    String? rollNo,
    String? studentClass,
    String? semester,
    String? profilePicUrl,
    String? firstLetter, // <-- ADD THIS LINE
  }) {
    return UserModel(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      role: role ?? this.role,
      isVerified: isVerified ?? this.isVerified,
      rollNo: rollNo ?? this.rollNo,
      studentClass: studentClass ?? this.studentClass,
      semester: semester ?? this.semester,
      profilePicUrl: profilePicUrl ?? this.profilePicUrl,
      firstLetter: firstLetter ?? this.firstLetter, // <-- CORRECT
    );
  }
}