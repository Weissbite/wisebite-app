import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:smooth_app/data_models/user_data.dart';
import 'package:smooth_app/data_models/user_management_provider.dart';
import 'package:smooth_app/generic_lib/widgets/images/smooth_image.dart';
import 'package:smooth_app/generic_lib/widgets/smooth_back_button.dart';
import 'package:smooth_app/pages/metrics_choose_activity_level.dart';
import 'package:smooth_app/providers/activity_level_provider.dart';
import 'package:smooth_app/services/firebase_firestore_service.dart';
import 'package:smooth_app/widgets/smooth_app_bar.dart';
import 'package:smooth_app/widgets/smooth_scaffold.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class MerticsPageWidget extends StatefulWidget {
  const MerticsPageWidget({Key? key}) : super(key: key);

  @override
  _MerticsPageWidgetState createState() => _MerticsPageWidgetState();
}

class _MerticsPageWidgetState extends State<MerticsPageWidget> {
  final scaffoldKey = GlobalKey<ScaffoldState>();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final TextEditingController _ageController = TextEditingController();
  final TextEditingController _heightController = TextEditingController();
  final TextEditingController _weightController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _submitForm() async {
    final ActivityLevel activityLevel =
        context.read<ActivityLevelProvider>().currentActivityLevel;

    final userData = UserData(
      age: int.parse(_ageController.text),
      weight: int.parse(_weightController.text),
      height: int.parse(_heightController.text),
      activityLevel: activityLevel,
    );

    final user_id = UserManagementProvider.user!.uid;
    final FirestoreService<UserData> service = FirestoreService<UserData>(
      collectionPath: 'user_data',
      fromFirestore: UserData().fromFirestore,
    );

    await service.setDocument(
      documentId: user_id,
      data: userData,
      merge: true,
    );
  }

  Future<void> _loadData() async {
    final user_id = UserManagementProvider.user!.uid;
    final FirestoreService<UserData> service = FirestoreService<UserData>(
      collectionPath: 'user_data',
      fromFirestore: UserData().fromFirestore,
    );

    UserData? data = await service.getDocument(documentId: user_id);
    if (data == null) return;

    _ageController.text = data.age!.toString();
    _weightController.text = data.weight!.toString();
    _heightController.text = data.height!.toString();
    context.read<ActivityLevelProvider>().setCurrent(data.activityLevel!);

    setState(() {});
  }

  @override
  void dispose() {
    // Clean up the controller when the widget is disposed.
    _ageController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData _themeData = Theme.of(context);
    final AppLocalizations appLocalizations = AppLocalizations.of(context);

    return SmoothSharedAnimationController(
      child: SmoothScaffold(
        appBar: SmoothAppBar(
          backgroundColor: _themeData.scaffoldBackgroundColor,
          elevation: 2,
          automaticallyImplyLeading: false,
          leading: const SmoothBackButton(),
          title: Text(appLocalizations.metrics),
        ),
        body: Form(
          key: _formKey,
          child: Padding(
            padding: EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                // Age Field
                TextFormField(
                  controller: _ageController,
                  decoration: InputDecoration(labelText: appLocalizations.age),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return appLocalizations.please_enter_your_age;
                    }
                    return null;
                  },
                ),

                // Height Field
                TextFormField(
                  controller: _heightController,
                  decoration:
                      InputDecoration(labelText: appLocalizations.height),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return appLocalizations.please_enter_your_height;
                    }
                    return null;
                  },
                ),

                // Weight Field
                TextFormField(
                  controller: _weightController,
                  decoration:
                      InputDecoration(labelText: appLocalizations.weight),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return appLocalizations.please_enter_your_weight;
                    }
                    return null;
                  },
                ),

                MetricsChooseActivityLevel.getUserPreferencesItem(context)
                    .builder(context),

                // Submit Button
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16.0),
                  child: ElevatedButton(
                    onPressed: () {
                      // Validate and Process data
                      if (_formKey.currentState!.validate()) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(appLocalizations.processing)),
                        );
                        _submitForm();
                      }
                    },
                    child: Text(appLocalizations.submit),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
