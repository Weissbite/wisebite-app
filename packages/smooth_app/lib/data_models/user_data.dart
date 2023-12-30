import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:smooth_app/data_models/firestore_model.dart';
import 'package:smooth_app/providers/activity_level_provider.dart';

class UserData extends FirestoreModel<UserData> {
  final int? age;
  final int? weight;
  final int? height;
  final ActivityLevel? activityLevel;

  UserData({
    this.age,
    this.weight,
    this.height,
    this.activityLevel,
  });

  @override
  UserData fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
    SnapshotOptions? options,
  ) {
    final data = snapshot.data();
    return UserData(
      age: data?['age'],
      weight: data?['weight'],
      height: data?['height'],
      activityLevel: ActivityLevel.values[data?['activity_level'] ?? 0],
    );
  }

  @override
  Map<String, dynamic> toFirestore() {
    return {
      if (age != null) "age": age,
      if (weight != null) "weight": weight,
      if (height != null) "height": height,
      if (activityLevel != null) "activity_level": activityLevel!.index,
    };
  }
}
