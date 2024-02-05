import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import 'package:smooth_app/data_models/continuous_scan_model.dart';
import 'package:smooth_app/data_models/preferences/user_preferences.dart';
import 'package:smooth_app/data_models/user_management_provider.dart';
import 'package:smooth_app/helpers/camera_helper.dart';
import 'package:smooth_app/helpers/haptic_feedback_helper.dart';
import 'package:smooth_app/pages/scan/camera_scan_page.dart';
import 'package:smooth_app/widgets/smooth_product_carousel.dart';
import 'package:smooth_app/widgets/smooth_scaffold.dart';

class ScanPage extends StatefulWidget {
  const ScanPage();

  @override
  State<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<ScanPage> {
  /// Audio player to play the beep sound on scan
  /// This attribute is only initialized when a camera is available AND the
  /// setting is set to ON
  AudioPlayer? _musicPlayer;

  late UserPreferences _userPreferences;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (mounted) {
      _userPreferences = context.watch<UserPreferences>();
    }
  }

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _incrementMainScreenCounter();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (context.watch<ContinuousScanModel?>() == null) {
      return const Center(child: CircularProgressIndicator.adaptive());
    }

    final AppLocalizations appLocalizations = AppLocalizations.of(context);
    final TextDirection direction = Directionality.of(context);

    return SmoothScaffold(
      brightness:
          Theme.of(context).brightness == Brightness.light && Platform.isIOS
              ? Brightness.dark
              : null,
      body: Container(
        color: Colors.white,
        child: SafeArea(
          child: Container(
            color: Theme.of(context).colorScheme.background,
            child: Center(
              child: SizedBox(
                width: double.infinity,
                height: MediaQuery.of(context).size.height,
                child: Padding(
                  padding: const EdgeInsetsDirectional.only(bottom: 300),
                  child: SmoothProductCarousel(
                    containSearchCard: true,
                    onPageChangedTo: (int page, String? barcode) async {
                      if (barcode == null) {
                        // We only notify for new products
                        return;
                      }

                      // Both are Future methods, but it doesn't matter to wait here
                      SmoothHapticFeedback.lightNotification();

                      if (_userPreferences.playCameraSound) {
                        await _initSoundManagerIfNecessary();
                        await _musicPlayer!.stop();
                        await _musicPlayer!.play(
                          AssetSource('audio/beep.wav'),
                          volume: 0.5,
                          ctx: const AudioContext(
                            android: AudioContextAndroid(
                              isSpeakerphoneOn: false,
                              stayAwake: false,
                              contentType: AndroidContentType.sonification,
                              usageType: AndroidUsageType.notification,
                              audioFocus:
                                  AndroidAudioFocus.gainTransientMayDuck,
                            ),
                            iOS: AudioContextIOS(
                              category: AVAudioSessionCategory.soloAmbient,
                              options: <AVAudioSessionOptions>[
                                AVAudioSessionOptions.mixWithOthers,
                              ],
                            ),
                          ),
                        );
                      }

                      SemanticsService.announce(
                        appLocalizations.scan_announce_new_barcode(barcode),
                        direction,
                        assertiveness: Assertiveness.assertive,
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(CupertinoIcons.barcode),
        label: Text(appLocalizations.scan_navbar_label),
        onPressed: () {
          Navigator.push(
              context,
              MaterialPageRoute<Widget>(
                  builder: (BuildContext context) => ScannerPage()));
        },
      ),
    );
  }

  Future<void> _incrementMainScreenCounter() async {
    if (UserManagementProvider.user == null) {
      return;
    }

    final bool areMetricsFilled =
        await UserManagementProvider().areMetricFieldsFilled();
    if (areMetricsFilled) {
      return;
    }

    int mainScreenCounter = _userPreferences.mainScreenCounter;
    if (mainScreenCounter == 5 && context.mounted) {
      Navigator.pop(context);
      showCompleteProfileDialog(context);
    }

    mainScreenCounter++;
    if (mainScreenCounter > 5) {
      mainScreenCounter = 0;
    }

    _userPreferences.setMainScreenCounter(mainScreenCounter);
  }

  /// Only initialize the "beep" player when needed
  /// (at least one camera available + settings set to ON)
  Future<void> _initSoundManagerIfNecessary() async {
    if (_musicPlayer != null) {
      return;
    }

    _musicPlayer = AudioPlayer(playerId: '1');
  }

  Future<void> _disposeSoundManager() async {
    await _musicPlayer?.release();
    await _musicPlayer?.dispose();
    _musicPlayer = null;
  }

  @override
  void dispose() {
    _disposeSoundManager();
    super.dispose();
  }
}
