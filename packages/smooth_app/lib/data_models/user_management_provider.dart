import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:smooth_app/data_models/user_data.dart';
import 'package:smooth_app/database/firebase/product_lists_manager.dart';
import 'package:smooth_app/generic_lib/dialogs/smooth_alert_dialog.dart';
import 'package:smooth_app/pages/navigator/app_navigator.dart';
import 'package:smooth_app/services/firebase_firestore_service.dart';
import 'package:smooth_app/services/smooth_services.dart';

enum SignInProvider {
  Google,
  Facebook,
  Apple,
}

class UserManagementProvider with ChangeNotifier {
  static User? get user => FirebaseAuth.instance.currentUser;

  void listenToFirebase() {
    FirebaseAuth.instance.authStateChanges().listen((User? user) {
      notifyListeners();
    });
  }

  // We're going to look for a document inside "user_data" collection with the id of user's UID
  // if there's no such document, we'll return false and prompt the user for filling the metrics
  Future<bool> areMetricFieldsFilled() async {
    if (user == null) {
      return true;
    }

    final FirestoreService<UserData> service = FirestoreService<UserData>(
      collectionPath: 'user_data',
      fromFirestore: UserData().fromFirestore,
    );

    final UserData? data = await service.getDocument(documentId: user!.uid);
    if (data == null) {
      return false;
    }

    return true;
  }

  Future<void> _signInWithGoogle() async {
    final FirebaseAuth auth = FirebaseAuth.instance;

    try {
      // Trigger the authentication flow
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();

      // Obtain the auth details from the request
      final GoogleSignInAuthentication? googleAuth =
          await googleUser?.authentication;

      // Create a new credential
      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth?.accessToken,
        idToken: googleAuth?.idToken,
      );

      // Sign In
      await auth.signInWithCredential(credential);
    } on FirebaseAuthException catch (e) {
      Logs.e(
        'An error occurred while trying to Sign In. ${e.message}',
        ex: e,
      );
    }

    FirebaseAnalytics.instance.logLogin(loginMethod: 'Google');
  }

  Future<void> _signInWithFacebook() async {
    try {
      // Trigger the sign-in flow
      final LoginResult loginResult = await FacebookAuth.instance.login();
      if (loginResult.accessToken == null) {
        Logs.d('signInWithFacebook: $loginResult');
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

    FirebaseAnalytics.instance.logLogin(loginMethod: 'Facebook');
  }

  Future<void> _signInWithApple() async {}

  Future<void> signIn({
    required final SignInProvider provider,
    required final BuildContext context,
    required final bool askUserSavingNewProducts,
  }) async {
    switch (provider) {
      case SignInProvider.Google:
        await _signInWithGoogle();
      case SignInProvider.Facebook:
        await _signInWithFacebook();
      case SignInProvider.Apple:
        await _signInWithApple();
    }

    ProductListFirebaseManager().saveAllProductLists().then((_) {
      ProductListFirebaseManager().fetchUserProductLists();
    });
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

void showCompleteProfileDialog(BuildContext context) {
  final AppLocalizations appLocalizations = AppLocalizations.of(context);

  showDialog(
      context: context,
      builder: (BuildContext context) {
        return SmoothAlertDialog(
          title: appLocalizations.complete_profile,
          body: Column(
            children: <Widget>[
              Text(appLocalizations.complete_profile_prompt),
              const SizedBox(
                height: 10,
              ),
            ],
          ),
          positiveAction: SmoothActionButton(
            text: appLocalizations.complete,
            onPressed: () {
              AppNavigator.of(context).push(AppRoutes.METRICS);
              Navigator.of(context, rootNavigator: true).pop('dialog');
            },
          ),
          negativeAction: SmoothActionButton(
            onPressed: () {
              Navigator.of(context, rootNavigator: true).pop('dialog');
            },
            text: 'Close',
            minWidth: 100,
          ),
          actionsAxis: Axis.vertical,
          actionsOrder: SmoothButtonsBarOrder.auto,
        );
      });
}
