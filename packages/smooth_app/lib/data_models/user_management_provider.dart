import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:smooth_app/services/smooth_services.dart';

class UserManagementProvider with ChangeNotifier {
  static User? get user => FirebaseAuth.instance.currentUser;

  void listenToFirebase() {
    FirebaseAuth.instance.authStateChanges().listen((user) {
      notifyListeners();
    });
  }

  Future<void> signInWithGoogle(BuildContext context) async {
    try {
      // Trigger the authentication flow
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();

      // Obtain the auth details from the request
      final GoogleSignInAuthentication? googleAuth =
          await googleUser?.authentication;

      // Create a new credential
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth?.accessToken,
        idToken: googleAuth?.idToken,
      );

      // Sign In
      await FirebaseAuth.instance.signInWithCredential(credential);
    } on FirebaseAuthException catch (e) {
      Logs.e(
        'An error occurred while trying to Sign In. ${e.message}',
        ex: e,
      );
    }
  }

  Future<void> signInWithFacebook(BuildContext context) async {
    try {
      // Trigger the sign-in flow
      final LoginResult? loginResult = await FacebookAuth.instance.login();
      if (loginResult == null) {
        print(loginResult);
        return;
      }

      // Create a credential from the access token
      final OAuthCredential facebookAuthCredential =
          FacebookAuthProvider.credential(loginResult.accessToken!.token);

      // Sign In
      await FirebaseAuth.instance.signInWithCredential(facebookAuthCredential);
    } on FirebaseAuthException catch (e) {
      Logs.e(
        'An error occurred while trying to Sign In. ${e.message}',
        ex: e,
      );
    }
  }

  Future<void> signInWithApple(BuildContext context) async {
    // Can't implement this without an Apple Developer Account
  }

  // SIGN OUT
  Future<void> signOut(BuildContext context) async {
    try {
      await FirebaseAuth.instance.signOut();
    } on FirebaseAuthException catch (e) {
      Logs.e(
        'An error occurred while trying to Sign Out. ${e.message}',
        ex: e,
      );
    }
  }
}
