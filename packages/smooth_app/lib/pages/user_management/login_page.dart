import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:matomo_tracker/matomo_tracker.dart';
import 'package:provider/provider.dart';
import 'package:smooth_app/data_models/preferences/user_preferences.dart';
import 'package:smooth_app/data_models/user_management_provider.dart';
import 'package:smooth_app/database/local_database.dart';
import 'package:smooth_app/generic_lib/buttons/service_sign_in_button.dart';
import 'package:smooth_app/generic_lib/design_constants.dart';
import 'package:smooth_app/generic_lib/dialogs/smooth_alert_dialog.dart';
import 'package:smooth_app/helpers/app_helper.dart';
import 'package:smooth_app/helpers/launch_url_helper.dart';
import 'package:smooth_app/helpers/user_feedback_helper.dart';
import 'package:smooth_app/services/smooth_services.dart';
import 'package:smooth_app/widgets/smooth_app_bar.dart';
import 'package:smooth_app/widgets/smooth_scaffold.dart';

class LoginPage extends StatefulWidget {
  const LoginPage();

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> with TraceableClientMixin {
  bool _runningQuery = false;

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final TextEditingController userIdController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  @override
  String get actionName => 'Opened login_page';

  @override
  void dispose() {
    userIdController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppLocalizations appLocalizations = AppLocalizations.of(context);
    final Size size = MediaQuery.of(context).size;

    return SmoothScaffold(
      statusBarBackgroundColor: SmoothScaffold.semiTranslucentStatusBar,
      contentBehindStatusBar: true,
      fixKeyboard: true,
      appBar: SmoothAppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
      body: Form(
        key: _formKey,
        child: Scrollbar(
          child: SingleChildScrollView(
            child: Container(
              alignment: Alignment.topCenter,
              width: double.infinity,
              padding: EdgeInsetsDirectional.only(
                start: size.width * 0.15,
                end: size.width * 0.15,
                bottom: size.width * 0.05,
              ),
              child: AutofillGroup(
                child: Center(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      SvgPicture.asset(
                        'assets/preferences/login.svg',
                        height: MediaQuery.of(context).size.height * .15,
                        package: AppHelper.APP_PACKAGE,
                      ),
                      Text(
                        appLocalizations.sign_in_text,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.displayLarge?.copyWith(
                          fontSize: VERY_LARGE_SPACE,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(
                        height: LARGE_SPACE * 4,
                      ),
                      Column(
                        children: _runningQuery
                            ? <Widget>[
                                const CircularProgressIndicator.adaptive(),
                                const SizedBox(
                                  height: LARGE_SPACE,
                                ),
                                Text(appLocalizations.signing_in,
                                    textAlign: TextAlign.center,
                                    style:
                                        theme.textTheme.displayLarge?.copyWith(
                                      fontSize: VERY_LARGE_SPACE,
                                      fontWeight: FontWeight.w700,
                                    )),
                              ]
                            : <Widget>[
                                ServiceSignInButton(
                                  onPressed: () async {
                                    setState(() => _runningQuery = true);

                                    await UserManagementProvider().signIn(
                                        provider: SignInProvider.Google,
                                        context: context,
                                        askUserSavingNewProducts: true,
                                        localDb: context.read<LocalDatabase>());

                                    if (context.mounted &&
                                        UserManagementProvider.user != null) {
                                      Navigator.pop(context);
                                    } else {
                                      setState(() => _runningQuery = false);
                                    }
                                  },
                                  backgroundColor: Colors.white,
                                  iconPath: 'assets/icons/google.svg',
                                  text: appLocalizations.sign_in_with_google,
                                  fontColor: Colors.black,
                                ),
                                const SizedBox(
                                  height: LARGE_SPACE,
                                ),
                                ServiceSignInButton(
                                  onPressed: () async {
                                    setState(() => _runningQuery = true);

                                    await UserManagementProvider().signIn(
                                        provider: SignInProvider.Facebook,
                                        context: context,
                                        askUserSavingNewProducts: true,
                                        localDb: context.read<LocalDatabase>());

                                    if (context.mounted &&
                                        UserManagementProvider.user != null) {
                                      Navigator.pop(context);
                                    } else {
                                      setState(() => _runningQuery = false);
                                    }
                                  },
                                  backgroundColor:
                                      const Color.fromARGB(255, 24, 119, 242),
                                  iconPath: 'assets/icons/facebook.svg',
                                  text: appLocalizations.sign_in_with_facebook,
                                  fontColor: Colors.white,
                                ),
                              ],
                      )
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> showInAppReviewIfNecessary(BuildContext context) async {
    final UserPreferences preferences = context.read<UserPreferences>();
    if (!preferences.inAppReviewAlreadyAsked) {
      assert(mounted);
      final bool? enjoyingApp = await showDialog<bool>(
        context: context,
        builder: (BuildContext context) {
          final AppLocalizations appLocalizations =
              AppLocalizations.of(context);

          return SmoothAlertDialog(
            body: Text(appLocalizations.app_rating_dialog_title_enjoying_app),
            positiveAction: SmoothActionButton(
              text: appLocalizations
                  .app_rating_dialog_title_enjoying_positive_actions,
              onPressed: () => Navigator.of(context).pop(true),
            ),
            negativeAction: SmoothActionButton(
              text: appLocalizations.not_really,
              onPressed: () => Navigator.of(context).pop(false),
            ),
          );
        },
      );
      if (enjoyingApp != null && !enjoyingApp) {
        if (!context.mounted) {
          return;
        }
        await showDialog<bool>(
          context: context,
          builder: (BuildContext context) {
            final AppLocalizations appLocalizations =
                AppLocalizations.of(context);

            return SmoothAlertDialog(
              body: Text(
                  appLocalizations.app_rating_dialog_title_not_enjoying_app),
              positiveAction: SmoothActionButton(
                text: appLocalizations.okay,
                onPressed: () async {
                  final String formLink =
                      UserFeedbackHelper.getFeedbackFormLink();
                  LaunchUrlHelper.launchURL(formLink, false);
                  Navigator.of(context).pop();
                },
              ),
              negativeAction: SmoothActionButton(
                text: appLocalizations.not_really,
                onPressed: () => Navigator.of(context).pop(),
              ),
            );
          },
        );
      }
      bool? userRatedApp;
      if (enjoyingApp != null && enjoyingApp) {
        if (!context.mounted) {
          return;
        }
        userRatedApp = await showDialog<bool>(
          context: context,
          builder: (BuildContext context) {
            final AppLocalizations appLocalizations =
                AppLocalizations.of(context);

            return SmoothAlertDialog(
              body: Text(appLocalizations.app_rating_dialog_title),
              positiveAction: SmoothActionButton(
                text: appLocalizations.app_rating_dialog_positive_action,
                onPressed: () async => Navigator.of(context).pop(
                  await ApplicationStore.openAppReview(),
                ),
              ),
              negativeAction: SmoothActionButton(
                text: appLocalizations.ask_me_later_button_label,
                onPressed: () => Navigator.of(context).pop(false),
              ),
            );
          },
        );
      }
      if (userRatedApp != null && userRatedApp) {
        await preferences.markInAppReviewAsShown();
      }
    }
  }
}
