import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String name;
  final String email;
  final String phone;
  final String? photoUrl;
  final bool isGoogleAuth;

  UserModel({
    required this.name,
    required this.email,
    required this.phone,
    this.photoUrl,
    this.isGoogleAuth = false,
  });

  UserModel copyWith({
    String? name,
    String? email,
    String? phone,
    String? photoUrl,
    bool? isGoogleAuth,
  }) {
    return UserModel(
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      photoUrl: photoUrl ?? this.photoUrl,
      isGoogleAuth: isGoogleAuth ?? this.isGoogleAuth,
    );
  }
}

class AuthService extends ChangeNotifier {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  UserModel? _currentUser;
  UserModel? get currentUser => _currentUser;
  bool get isAuthenticated => _currentUser != null;

  // Real Firestore-backed User Registration
  Future<String?> register({
    required String name,
    required String email,
    required String phone,
    required String password,
  }) async {
    try {
      final cleanPhone = phone.trim();
      final cleanEmail = email.trim().toLowerCase();
      final cleanName = name.trim();

      // Check if user with this phone already exists
      final existingPhoneDoc = await FirebaseFirestore.instance.collection('users').doc(cleanPhone).get();
      if (existingPhoneDoc.exists) {
        return 'An account with mobile +91 $cleanPhone already exists. Please log in.';
      }

      // Check if email already registered
      final emailQuery = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: cleanEmail)
          .limit(1)
          .get();

      if (emailQuery.docs.isNotEmpty) {
        return 'An account with email $cleanEmail already exists. Please log in.';
      }

      // Check if there are existing applications with a selfie
      String? selfie;
      final appsQuery = await FirebaseFirestore.instance
          .collection('applications')
          .where('userPhone', isEqualTo: cleanPhone)
          .limit(1)
          .get();

      if (appsQuery.docs.isNotEmpty) {
        selfie = appsQuery.docs.first.data()['selfieUrl'] as String?;
      }

      // Save user to Firestore 'users' collection
      await FirebaseFirestore.instance.collection('users').doc(cleanPhone).set({
        'name': cleanName,
        'email': cleanEmail,
        'phone': cleanPhone,
        'password': password,
        'photoUrl': selfie,
        'createdAt': FieldValue.serverTimestamp(),
        'lastLoginAt': FieldValue.serverTimestamp(),
        'isBlocked': false,
      });

      _currentUser = UserModel(
        name: cleanName,
        email: cleanEmail,
        phone: cleanPhone,
        photoUrl: selfie,
      );

      notifyListeners();
      return null; // Null indicates success
    } catch (e) {
      return 'Registration failed: $e';
    }
  }

  // Real Firestore-backed User Login (by Mobile or Email)
  Future<String?> login({
    required String identifier, // Can be phone or email
    required String password,
  }) async {
    try {
      final cleanId = identifier.trim().toLowerCase();

      DocumentSnapshot<Map<String, dynamic>>? userDoc;

      // 1. Check if identifier is phone (by document ID)
      final phoneDoc = await FirebaseFirestore.instance.collection('users').doc(cleanId).get();
      if (phoneDoc.exists) {
        userDoc = phoneDoc;
      } else {
        // 2. Query by phone or email field
        final phoneQuery = await FirebaseFirestore.instance
            .collection('users')
            .where('phone', isEqualTo: cleanId)
            .limit(1)
            .get();

        if (phoneQuery.docs.isNotEmpty) {
          userDoc = phoneQuery.docs.first;
        } else {
          final emailQuery = await FirebaseFirestore.instance
              .collection('users')
              .where('email', isEqualTo: cleanId)
              .limit(1)
              .get();

          if (emailQuery.docs.isNotEmpty) {
            userDoc = emailQuery.docs.first;
          }
        }
      }

      if (userDoc == null || !userDoc.exists || userDoc.data() == null) {
        return 'No account found with this mobile number or email. Please create an account.';
      }

      final data = userDoc.data()!;

      // Check account suspension status
      if (data['isBlocked'] == true) {
        return 'This account has been suspended by administration. Please contact support.';
      }

      // Verify password
      final storedPassword = data['password']?.toString() ?? '';
      if (storedPassword.isNotEmpty && storedPassword != password) {
        return 'Incorrect password. Please verify and try again.';
      }

      // Check if user has an uploaded selfie
      String? photoUrl = data['photoUrl'] as String?;
      if (photoUrl == null || photoUrl.isEmpty) {
        final phone = data['phone']?.toString() ?? userDoc.id;
        final apps = await FirebaseFirestore.instance
            .collection('applications')
            .where('userPhone', isEqualTo: phone)
            .limit(1)
            .get();

        if (apps.docs.isNotEmpty) {
          photoUrl = apps.docs.first.data()['selfieUrl'] as String?;
        }
      }

      // Update last login
      await userDoc.reference.update({
        'lastLoginAt': FieldValue.serverTimestamp(),
      });

      _currentUser = UserModel(
        name: data['name'] ?? 'Loan Customer',
        email: data['email'] ?? '',
        phone: data['phone'] ?? userDoc.id,
        photoUrl: photoUrl,
      );

      notifyListeners();
      return null; // Null indicates success
    } catch (e) {
      return 'Login failed: $e';
    }
  }

  // Update Profile
  void updateProfile({String? name, String? email, String? phone, String? photoUrl}) {
    if (_currentUser != null) {
      _currentUser = _currentUser!.copyWith(
        name: name,
        email: email,
        phone: phone,
        photoUrl: photoUrl,
      );
    } else {
      _currentUser = UserModel(
        name: name ?? 'Loan Customer',
        email: email ?? '',
        phone: phone ?? '',
        photoUrl: photoUrl,
      );
    }

    // Persist photoUrl and details to Firestore
    final p = _currentUser?.phone;
    if (p != null && p.isNotEmpty) {
      FirebaseFirestore.instance.collection('users').doc(p).set({
        if (name != null) 'name': name,
        if (email != null) 'email': email,
        if (photoUrl != null) 'photoUrl': photoUrl,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }

    notifyListeners();
  }

  // Logout
  void logout() {
    _currentUser = null;
    notifyListeners();
  }
}
