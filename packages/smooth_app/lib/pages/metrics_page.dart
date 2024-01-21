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

class MerticsPageWidget extends StatefulWidget {
  const MerticsPageWidget({Key? key}) : super(key: key);

  @override
  State<MerticsPageWidget> createState() => _MerticsPageWidgetState();
}

class _MerticsPageWidgetState extends State<MerticsPageWidget> {
  final GlobalKey<ScaffoldState> scaffoldKey = GlobalKey<ScaffoldState>();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final TextEditingController _ageController = TextEditingController();
  final TextEditingController _heightController = TextEditingController();
  final TextEditingController _weightController = TextEditingController();

  @override
  void initState() {
    _loadData().then((ActivityLevel? activityLevel) {
      setState(() {
        activityLevel = activityLevel;
      });
    });
    super.initState();
  }

  Future<void> _submitForm() async {
    final ActivityLevel activityLevel =
        context.read<ActivityLevelProvider>().currentActivityLevel;

    final UserData userData = UserData(
      age: int.parse(_ageController.text),
      weight: int.parse(_weightController.text),
      height: int.parse(_heightController.text),
      activityLevel: activityLevel,
    );

    final String userId = UserManagementProvider.user!.uid;
    final FirestoreService<UserData> service = FirestoreService<UserData>(
      collectionPath: 'user_data',
      fromFirestore: UserData().fromFirestore,
    );

    await service.setDocument(
      documentId: userId,
      data: userData,
      merge: true,
    );
  }

  Future<ActivityLevel?> _loadData() async {
    final String userId = UserManagementProvider.user!.uid;
    final FirestoreService<UserData> service = FirestoreService<UserData>(
      collectionPath: 'user_data',
      fromFirestore: UserData().fromFirestore,
    );

    final UserData? data = await service.getDocument(documentId: userId);
    if (data == null) {
      return null;
    }

    _ageController.text = data.age!.toString();
    _weightController.text = data.weight!.toString();
    _heightController.text = data.height!.toString();

    // if (!context.mounted) {
    //   return null;
    // }
    // Navigator.of(context).pop();

    return data.activityLevel;
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
    final ThemeData themeData = Theme.of(context);

    return SmoothSharedAnimationController(
      child: SmoothScaffold(
        appBar: SmoothAppBar(
          backgroundColor: themeData.scaffoldBackgroundColor,
          elevation: 2,
          automaticallyImplyLeading: false,
          leading: const SmoothBackButton(),
          title: const Text('Metrics'),
        ),
        body: Form(
          key: _formKey,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                // Age Field
                TextFormField(
                  controller: _ageController,
                  decoration: const InputDecoration(labelText: 'Age'),
                  keyboardType: TextInputType.number,
                  inputFormatters: <TextInputFormatter>[
                    FilteringTextInputFormatter.digitsOnly
                  ],
                  validator: (String? value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your age';
                    }
                    return null;
                  },
                ),

                // Height Field
                TextFormField(
                  controller: _heightController,
                  decoration: const InputDecoration(labelText: 'Height (cm)'),
                  keyboardType: TextInputType.number,
                  inputFormatters: <TextInputFormatter>[
                    FilteringTextInputFormatter.digitsOnly
                  ],
                  validator: (String? value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your height';
                    }
                    return null;
                  },
                ),

                // Weight Field
                TextFormField(
                  controller: _weightController,
                  decoration: const InputDecoration(labelText: 'Weight (kg)'),
                  keyboardType: TextInputType.number,
                  inputFormatters: <TextInputFormatter>[
                    FilteringTextInputFormatter.digitsOnly
                  ],
                  validator: (String? value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your weight';
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
                          const SnackBar(content: Text('Processing Data')),
                        );
                        _submitForm();
                      }
                    },
                    child: const Text('Submit'),
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
