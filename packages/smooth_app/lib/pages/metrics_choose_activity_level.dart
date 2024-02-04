import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
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
    final AppLocalizations appLocalizations = AppLocalizations.of(context);

    return UserPreferencesMultipleChoicesItem<String>(
      title: appLocalizations.activity_level,
      leadingBuilder: <WidgetBuilder>[
        (_) => const Icon(Icons.chair),
        (_) => const Icon(Icons.directions_walk),
        (_) => const Icon(Icons.directions_bike_sharp),
        (_) => const Icon(Icons.fitness_center),
      ],
      labels: ACTIVITY_LEVELS_LABELS,
      values: ACTIVITY_LEVELS_LABELS,
      longDescriptions: <String>[
        appLocalizations.sedentary_description,
        appLocalizations.lightly_active_description,
        appLocalizations.moderetaly_active_description,
        appLocalizations.very_active_description,
      ],
      currentValue: activityLevel.current,
      onChanged: (String? newValue) => activityLevel.setLevel(newValue!),
    );
  }
}
