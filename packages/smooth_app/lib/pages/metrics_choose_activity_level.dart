import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smooth_app/pages/preferences/user_preferences_item.dart';
import 'package:smooth_app/pages/preferences/user_preferences_widgets.dart';
import 'package:smooth_app/providers/activity_level_provider.dart';

const List<String> ACTIVITY_LEVELS_LABELS = <String>[
  ACTIVITY_LEVEL_SEDENTARY,
  ACTIVITY_LEVEL_LIGHTLY_ACTIVE,
  ACTIVITY_LEVEL_MODERATELY_ACTIVE,
  ACTIVITY_LEVEL_VERY_ACTIVE,
];

class MetricsChooseActivityLevel extends StatelessWidget {
  const MetricsChooseActivityLevel();

  static UserPreferencesItem getUserPreferencesItem(
      final BuildContext context) {
    return UserPreferencesItemSimple(
      labels: ACTIVITY_LEVELS_LABELS,
      builder: (_) => const MetricsChooseActivityLevel(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ActivityLevelProvider activityLevel =
        context.watch<ActivityLevelProvider>();

    return UserPreferencesMultipleChoicesItem<String>(
      title: 'Activity Level',
      leadingBuilder: <WidgetBuilder>[
        (_) => const Icon(Icons.chair),
        (_) => const Icon(Icons.directions_walk),
        (_) => const Icon(Icons.directions_bike_sharp),
        (_) => const Icon(Icons.fitness_center),
      ],
      labels: ACTIVITY_LEVELS_LABELS,
      values: ACTIVITY_LEVELS_LABELS,
      longDescriptions: const <String>[
        "- You do less than 30 minutes a day of intentional exercise and you don't do anything that can be considered moderate or vigorous\n - Daily living activities like walking the dog, shopping, mowing the lawn, taking out the trash, or gardening don't count as intentional exercise\n - You spend most of your day sitting",
        '- You do intentional exercise every day for at least 30 minutes\nThe baseline for this is walking for 30 minutes at ~6km/h - this is walking at a brisk pace\n- You can also do exercise for a shorter period of time providing the exercise is vigorous. An example of vigorous activity is jogging.\n- You will also usually spend a large part of your day on your feet',
        '- You do intentional exercise every day that is equivalent to briskly walking for at least one hour and 45 minutes - briskly walking is walking at ~6km/h\n- Alternatively, you can do exercise for a shorter period of time providing the exercise is vigorous. An example of vigorous activity is jogging, i.e. you would need to jog for a minimum of 50 minutes to be considered moderately active.\n- You will also probably spend a large part of your day doing something physical - examples include being a mailman or waitress\n',
        '- You do intentional exercise every day that is equivalent to briskly walking for at least four hours and 15 minutes - briskly walking is walking at ~6km/h\n- You can also do exercise for a shorter period of time providing the exercise is vigorous - an example of vigorous activity is jogging - you would need to jog for a minimum of two hours a day to be considered very active.\n- You will also probably spend most of your day doing something physical - examples include carpenters or bike messengers',
      ],
      currentValue: activityLevel.current,
      onChanged: (String? newValue) => activityLevel.setLevel(newValue!),
    );
  }
}
