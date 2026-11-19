import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'pages/home_page.dart';
import 'pages/login_page.dart';

/// ================== AUTH SERVICE ==================
class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DatabaseReference db = FirebaseDatabase.instance.ref();

  // REGISTER USER
  Future<String?> register(
      String name, String email, String password, String dob) async {
    try {
      UserCredential user = await _auth.createUserWithEmailAndPassword(
          email: email, password: password);

      await db.child("users").child(user.user!.uid).set({
        "name": name,
        "email": email,
        "dob": dob,
      });

      return null;
    } catch (e) {
      return e.toString();
    }
  }

  // LOGIN USER
  Future<String?> login(String email, String password) async {
    try {
      await _auth.signInWithEmailAndPassword(
          email: email, password: password);
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  // VERIFY DOB FOR FORGOT PASSWORD
  Future<bool> verifyDOB(String email, String dob) async {
    var snapshot = await db.child("users").get();

    for (var child in snapshot.children) {
      if (child.child("email").value == email &&
          child.child("dob").value == dob) {
        return true;
      }
    }
    return false;
  }

  // RESET PASSWORD EMAIL
  Future resetPassword(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }
}

/// ================== AUTH GATE ==================
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {

        // Loading
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // Logged in → Home
        if (snapshot.hasData) {
          return HomePage();
        }

        // Not logged in → Login page
        return LoginPage();
      },
    );
  }
}