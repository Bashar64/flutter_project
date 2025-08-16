import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthProvider extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  User? _user;

  User? get user => _user;
  bool get isLoggedIn => _user != null;
  String? get username => _user?.displayName;
  String? get email => _auth.currentUser?.email;

  AuthProvider() {
    _auth.authStateChanges().listen((User? user) {
      _user = user;
      notifyListeners();
    });
  }

  Future<String?> login(String email, String password) async {
    try {
      await _auth.signInWithEmailAndPassword(email: email, password: password);
      return null;
    } catch (e) {
      return 'Login failed: $e';
    }
  }

  Future<String?> signUp(String email, String password, String username) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      await credential.user?.updateDisplayName(username);
      return null;
    } catch (e) {
      return 'Sign up failed: $e';
    }
  }

  Future<void> logout() async {
    await _auth.signOut();
  }

  Future<String?> updateUsername(String newUsername) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return 'No user logged in';
      await user.updateDisplayName(newUsername);
      return null;
    } catch (e) {
      return 'Failed to update username';
    }
  }
}
