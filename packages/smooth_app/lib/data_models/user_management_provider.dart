import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:openfoodfacts/openfoodfacts.dart';
import 'package:smooth_app/data_models/login_result.dart' as off;
import 'package:smooth_app/data_models/user_data.dart';
import 'package:smooth_app/database/dao_secured_string.dart';
import 'package:smooth_app/database/firebase/product_lists_manager.dart';
import 'package:smooth_app/database/local_database.dart';
import 'package:smooth_app/generic_lib/dialogs/smooth_alert_dialog.dart';
import 'package:smooth_app/helpers/analytics_helper.dart';
import 'package:smooth_app/pages/navigator/app_navigator.dart';
import 'package:smooth_app/query/product_query.dart';
import 'package:smooth_app/services/firebase_firestore_service.dart';
import 'package:smooth_app/services/smooth_services.dart';

enum SignInProvider {
  Google,
  Facebook,
  Apple,
}

class UserManagementProvider with ChangeNotifier {
  static fb.User? get user => fb.FirebaseAuth.instance.currentUser;
  static const String _USER_ID = 'user_id';
  static const String _PASSWORD = 'pasword';

  /// Checks credentials and conditionally saves them.
  Future<off.LoginResult> login() async {
    // TODO(yavor): Delete internal account once self-hosting OpenFoodFacts Database.
    const User user = User(
      userId: '%OPENFOODFACTS_USERNAME%',
      password: '%OPENFOODFACTS_PASSWORD%',
    );
    final off.LoginResult loginResult =
        await off.LoginResult.getLoginResult(user);
    if (loginResult.type != off.LoginResultType.successful) {
      return loginResult;
    }
    await putUser(loginResult.user!);
    await credentialsInStorage();
    return loginResult;
  }

  /// Deletes saved credentials from storage
  Future<bool> logout() async {
    OpenFoodAPIConfiguration.globalUser = null;
    DaoSecuredString.remove(key: _USER_ID);
    DaoSecuredString.remove(key: _PASSWORD);
    notifyListeners();
    final bool contains = await credentialsInStorage();
    return !contains;
  }

  /// Mounts already stored credentials, called at app startup
  ///
  /// We can use optional parameters to mock in tests
  static Future<void> mountCredentials(
      {String? userId, String? password}) async {
    String? effectiveUserId;
    String? effectivePassword;

    try {
      effectiveUserId = userId ?? await DaoSecuredString.get(_USER_ID);
      effectivePassword = password ?? await DaoSecuredString.get(_PASSWORD);
    } on PlatformException {
      /// Decrypting the values can go wrong if, for example, the app was
      /// manually overwritten from an external apk.
      DaoSecuredString.remove(key: _USER_ID);
      DaoSecuredString.remove(key: _PASSWORD);
      Logs.e('Credentials query failed, you have been logged out');
    }

    if (effectiveUserId == null || effectivePassword == null) {
      return;
    }

    final User user =
        User(userId: effectiveUserId, password: effectivePassword);
    OpenFoodAPIConfiguration.globalUser = user;
  }

  /// Checks if any credentials exist in storage
  Future<bool> credentialsInStorage() async {
    final String? userId = await DaoSecuredString.get(_USER_ID);
    final String? password = await DaoSecuredString.get(_PASSWORD);

    return userId != null && password != null;
  }

  /// Saves user to storage
  Future<void> putUser(User user) async {
    OpenFoodAPIConfiguration.globalUser = user;
    await DaoSecuredString.put(
      key: _USER_ID,
      value: user.userId,
    );
    await DaoSecuredString.put(
      key: _PASSWORD,
      value: user.password,
    );
    notifyListeners();
  }

  /// Check if the user is still logged in and the credentials are still valid
  /// If not, the user is logged out
  Future<void> checkUserLoginValidity() async {
    if (!ProductQuery.isLoggedIn()) {
      return;
    }
    final User user = ProductQuery.getUser();
    final off.LoginResult loginResult = await off.LoginResult.getLoginResult(
      User(
        userId: user.userId,
        password: user.password,
      ),
    );
    switch (loginResult.type) {
      case off.LoginResultType.successful:
      case off.LoginResultType.serverIssue:
      case off.LoginResultType.exception:
        return;
      case off.LoginResultType.unsuccessful:
        // TODO(m123): Notify the user
        await logout();
    }
  }

  void listenToFirebase() {
    fb.FirebaseAuth.instance.authStateChanges().listen((fb.User? user) {
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
    final fb.FirebaseAuth auth = fb.FirebaseAuth.instance;

    try {
      // Trigger the authentication flow
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();

      // Obtain the auth details from the request
      final GoogleSignInAuthentication? googleAuth =
          await googleUser?.authentication;

      // Create a new credential
      final fb.OAuthCredential credential = fb.GoogleAuthProvider.credential(
        accessToken: googleAuth?.accessToken,
        idToken: googleAuth?.idToken,
      );

      // Sign in to OpenFoodFacts to allow CRUD operations on products.
      final off.LoginResult offLoginResult = await login();
      if (offLoginResult.type == off.LoginResultType.successful) {
        Logs.d('Successfully signed in OpenFoodFacts.');
        AnalyticsHelper.trackEvent(AnalyticsEvent.loginAction);
        // TODO(yavor): Pop-up dialog for review.
        // await showInAppReviewIfNecessary(context);
      } else {
        Logs.e('Failed to sign in to OpenFoodFacts with Wisebite.');
      }

      // Sign In
      await auth.signInWithCredential(credential);
    } on fb.FirebaseAuthException catch (e) {
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
      final fb.OAuthCredential facebookAuthCredential =
          fb.FacebookAuthProvider.credential(loginResult.accessToken!.token);

      // Sign In
      await fb.FirebaseAuth.instance
          .signInWithCredential(facebookAuthCredential);

      // Sign in to OpenFoodFacts to allow CRUD operations on products.
      final off.LoginResult offLoginResult = await login();
      if (offLoginResult.type == off.LoginResultType.successful) {
        Logs.d('Successfully signed in OpenFoodFacts.');
        AnalyticsHelper.trackEvent(AnalyticsEvent.loginAction);
        // TODO(yavor): Pop-up dialog for review.
        // await showInAppReviewIfNecessary(context);
      } else {
        Logs.e('Failed to sign in to OpenFoodFacts with Wisebite.');
      }
    } on fb.FirebaseAuthException catch (e) {
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
    required final LocalDatabase localDb,
  }) async {
    switch (provider) {
      case SignInProvider.Google:
        await _signInWithGoogle();
      case SignInProvider.Facebook:
        await _signInWithFacebook();
      case SignInProvider.Apple:
        await _signInWithApple();
    }

    final ProductListFirebaseManager firebaseManager =
        ProductListFirebaseManager();
    firebaseManager.saveAllProductLists(localDB: localDb).then((_) {
      firebaseManager.fetchUserProductLists(localDB: localDb);
    });
  }

  // signOut: implements logout for our custom accounts management.
  Future<void> signOut() async {
    try {
      await fb.FirebaseAuth.instance.signOut();
      await logout();
    } on fb.FirebaseAuthException catch (e) {
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
