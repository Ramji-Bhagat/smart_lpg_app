import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ForgotPasswordPage extends StatefulWidget {
  @override
  _ForgotPasswordPageState createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {

  final emailController = TextEditingController();
  final dobController = TextEditingController();

  Future verifyAndReset() async {
    try {
      var users = await FirebaseFirestore.instance
          .collection("users")
          .where("email", isEqualTo: emailController.text)
          .get();

      if (users.docs.isEmpty) {
        throw "User not found";
      }

      var userData = users.docs.first.data();

      if (userData["dob"] != dobController.text) {
        throw "DOB does not match";
      }

      await FirebaseAuth.instance.sendPasswordResetEmail(
        email: emailController.text,
      );

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Reset link sent")));

    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Reset Password")),
      body: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          children: [

            TextField(
              controller: emailController,
              decoration: InputDecoration(labelText: "Email"),
            ),

            TextField(
              controller: dobController,
              decoration: InputDecoration(labelText: "Enter DOB"),
            ),

            SizedBox(height: 20),

            ElevatedButton(
              onPressed: verifyAndReset,
              child: Text("Verify & Reset Password"),
            ),
          ],
        ),
      ),
    );
  }
}