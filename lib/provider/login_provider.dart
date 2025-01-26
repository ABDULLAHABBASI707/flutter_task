import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_task/utils/utils.dart';

class LoginProvider with ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  User? _user;
  bool _loading = false;
  bool _isResendDisabled = false;

  bool get loading => _loading;
  bool get isResendDisabled => _isResendDisabled;
  User? get user => _user;

  void setLoading(bool value) {
    _loading = value;
    notifyListeners();
  }

  void startResendCooldown() {
    _isResendDisabled = true;
    notifyListeners();
    Future.delayed(const Duration(seconds: 60), () {
      _isResendDisabled = false;
      notifyListeners();
    });
  }

  Future<void> login(
      String email, String password, BuildContext context) async {
    setLoading(true);
    try {
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );

      User? user = userCredential.user;
      if (user != null) {
        if (!user.emailVerified) {
          await _showVerifyEmailDialog(context, user);
          await _auth.signOut();
        } else {
          DocumentSnapshot userDoc =
              await _firestore.collection('users').doc(user.uid).get();

          SharedPreferences prefs = await SharedPreferences.getInstance();
          await prefs.setString('name', userDoc['name']);
          await prefs.setString('email', userDoc['email']);
          await prefs.setString('uid', user.uid);

          Utils().toastMessage('Login successful!');
        }
      }
    } catch (e) {
      Utils().toastMessage(e.toString());
    } finally {
      setLoading(false);
    }
  }

  Future<void> _showVerifyEmailDialog(BuildContext context, User user) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: const Text('Verify Your Email'),
          content: const Text(
            'A verification email has been sent to your email address. Please verify your email to proceed.',
          ),
          actions: [
            TextButton(
              onPressed: isResendDisabled
                  ? null
                  : () async {
                      try {
                        await user.sendEmailVerification();
                        Utils().toastMessage(
                            'Verification email resent. Please check your inbox.');
                        startResendCooldown();
                      } catch (error) {
                        Utils().toastMessage(
                            'Failed to resend verification email: $error');
                      }
                    },
              child: Text(
                isResendDisabled ? 'Wait' : 'Resend Email',
                style: TextStyle(
                  color: isResendDisabled ? Colors.grey : Colors.blue,
                ),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }
}
