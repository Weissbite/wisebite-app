import 'package:flutter/material.dart';

const String ACTIVITY_LEVEL_SEDENTARY = 'Sedentary';
const String ACTIVITY_LEVEL_LIGHTLY_ACTIVE = 'Lightly Active';
const String ACTIVITY_LEVEL_MODERATELY_ACTIVE = 'Moderately Active';
const String ACTIVITY_LEVEL_VERY_ACTIVE = 'Very Active';

enum ActivityLevel {
  Unknown,
  Sedentary,
  LightlyActive,
  ModeratelyActive,
  VeryActive,
}

class ActivityLevelProvider with ChangeNotifier {
  String current = ACTIVITY_LEVEL_SEDENTARY;

  final Map<ActivityLevel, String> activityLevelToString =
      <ActivityLevel, String>{
    ActivityLevel.Unknown: 'Unknown',
    ActivityLevel.Sedentary: ACTIVITY_LEVEL_SEDENTARY,
    ActivityLevel.LightlyActive: ACTIVITY_LEVEL_LIGHTLY_ACTIVE,
    ActivityLevel.ModeratelyActive: ACTIVITY_LEVEL_MODERATELY_ACTIVE,
    ActivityLevel.VeryActive: ACTIVITY_LEVEL_VERY_ACTIVE,
  };

  ActivityLevel get currentActivityLevel {
    for (final ActivityLevel level in ActivityLevel.values) {
      if (activityLevelToString[level] == current) {
        return level;
      }
    }

    return ActivityLevel.Unknown; // Default case, if no match is found
  }

  void setCurrent(ActivityLevel level) {
    setLevel(activityLevelToString[level]!);
  }

  void setLevel(String value) {
    current = value;
    notifyListeners();
  }
}
