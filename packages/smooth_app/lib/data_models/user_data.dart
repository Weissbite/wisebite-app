import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:smooth_app/data_models/firestore_model.dart';
import 'package:smooth_app/providers/activity_level_provider.dart';

class UserData extends FirestoreModel<UserData> {
  UserData({
    this.age,
    this.weight,
    this.height,
    this.activityLevel,
  });
  final int? age;
  final int? weight;
  final int? height;
  final ActivityLevel? activityLevel;

  @override
  UserData fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> data,
    SnapshotOptions? options,
  ) {
    final Map<String, dynamic>? profile = data.data();
    return UserData(
      age: profile?['age'],
      weight: profile?['weight'],
      height: profile?['height'],
      activityLevel: ActivityLevel.values[profile?['activity_level'] ?? 0],
    );
  }

  @override
  Map<String, dynamic> toFirestore() {
    return <String, dynamic>{
      if (age != null) 'age': age,
      if (weight != null) 'weight': weight,
      if (height != null) 'height': height,
      if (activityLevel != null) 'activity_level': activityLevel!.index,
    };
  }
}
