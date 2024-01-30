import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart' hide Listener;
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:matomo_tracker/matomo_tracker.dart';
import 'package:provider/provider.dart';
import 'package:scanner_shared/scanner_shared.dart';
import 'package:smooth_app/data_models/continuous_scan_model.dart';
import 'package:smooth_app/data_models/preferences/user_preferences.dart';
import 'package:smooth_app/generic_lib/design_constants.dart' hide EMPTY_WIDGET;
import 'package:smooth_app/generic_lib/dialogs/smooth_alert_dialog.dart';
import 'package:smooth_app/generic_lib/widgets/smooth_card.dart';
import 'package:smooth_app/helpers/analytics_helper.dart';
import 'package:smooth_app/helpers/camera_helper.dart';
import 'package:smooth_app/helpers/global_vars.dart';
import 'package:smooth_app/helpers/haptic_feedback_helper.dart';
import 'package:smooth_app/helpers/permission_helper.dart';
import 'package:smooth_app/pages/scan/scan_header.dart';
import 'package:smooth_app/widgets/smooth_scaffold.dart';

class _PermissionDeniedCard extends StatelessWidget {
  const _PermissionDeniedCard({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final AppLocalizations localizations = AppLocalizations.of(context);

    return SafeArea(
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          return Container(
            alignment: Alignment.topCenter,
            constraints: BoxConstraints.tightForFinite(
              width: constraints.maxWidth,
              height: math.min(constraints.maxHeight * 0.9, 200),
            ),
            child: SmoothCard(
              padding: const EdgeInsetsDirectional.only(
                top: 10.0,
                start: SMALL_SPACE,
                end: SMALL_SPACE,
                bottom: 5.0,
              ),
              child: Align(
                alignment: Alignment.topCenter,
                child: Column(
                  children: <Widget>[
                    Text(
                      localizations.permission_photo_denied_title,
                      style: const TextStyle(
                        fontSize: 18.0,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10.0,
                            vertical: 10.0,
                          ),
                          child: Text(
                            localizations.permission_photo_denied_message(
                              APP_NAME,
                            ),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              height: 1.4,
                              fontSize: 15.5,
                            ),
                          ),
                        ),
                      ),
                    ),
                    SmoothActionButtonsBar.single(
                      action: SmoothActionButton(
                        text: localizations.permission_photo_denied_button,
                        onPressed: () => _askPermission(context),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _askPermission(BuildContext context) {
    return Provider.of<PermissionListener>(
      context,
      listen: false,
    ).askPermission(onRationaleNotAvailable: () async {
      return showDialog(
          context: context,
          builder: (BuildContext context) {
            final AppLocalizations localizations = AppLocalizations.of(context);

            return SmoothAlertDialog(
              title:
                  localizations.permission_photo_denied_dialog_settings_title,
              body: Text(
                localizations.permission_photo_denied_dialog_settings_message,
                style: const TextStyle(
                  height: 1.6,
                ),
              ),
              negativeAction: SmoothActionButton(
                text: localizations
                    .permission_photo_denied_dialog_settings_button_cancel,
                onPressed: () => Navigator.of(context).pop(false),
                lines: 2,
              ),
              positiveAction: SmoothActionButton(
                text: localizations
                    .permission_photo_denied_dialog_settings_button_open,
                onPressed: () => Navigator.of(context).pop(true),
                lines: 2,
              ),
              actionsAxis: Axis.vertical,
            );
          });
    });
  }
}

class ScannerPage extends StatelessWidget {
  /// Percentage of the bottom part of the screen that hosts the carousel.
  static const int _carouselHeightPct = 55;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations appLocalizations = AppLocalizations.of(context);

    return SmoothScaffold(
        brightness:
            Theme.of(context).brightness == Brightness.light && Platform.isIOS
                ? Brightness.dark
                : null,
        appBar: AppBar(
          title: Text(appLocalizations.scan_navbar_label),
        ),
        body: Container(
          color: Colors.white,
          child: SafeArea(
            child: Container(
              color: Theme.of(context).colorScheme.background,
              child: Column(
                children: <Widget>[
                  Expanded(
                    flex: 100 - _carouselHeightPct,
                    child: Consumer<PermissionListener>(
                      builder: (
                        BuildContext context,
                        PermissionListener listener,
                        _,
                      ) {
                        switch (listener.value.status) {
                          case DevicePermissionStatus.checking:
                            return EMPTY_WIDGET;
                          case DevicePermissionStatus.granted:
                            return const CameraScannerPage();
                          default:
                            return const _PermissionDeniedCard();
                        }
                      },
                    ),
                  )
                ],
              ),
            ),
          ),
        ));
  }
}

/// A page showing the camera feed and decoding barcodes.
class CameraScannerPage extends StatefulWidget {
  const CameraScannerPage();

  @override
  CameraScannerPageState createState() => CameraScannerPageState();
}

class CameraScannerPageState extends State<CameraScannerPage>
    with TraceableClientMixin {
  final GlobalKey<State<StatefulWidget>> _headerKey = GlobalKey();

  late ContinuousScanModel _model;
  late UserPreferences _userPreferences;
  double? _headerHeight;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (mounted) {
      _model = context.watch<ContinuousScanModel>();
      _userPreferences = context.watch<UserPreferences>();
    }

    _detectHeaderHeight();
  }

  /// In some cases, the size may be null
  /// (Mainly when the app is launched for the first time AND in release mode)
  void _detectHeaderHeight([int retries = 0]) {
    // Let's try during 5 frames (should be enough, as 2 or 3 seems to be an average)
    if (retries > 5) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        _headerHeight =
            (_headerKey.currentContext?.findRenderObject() as RenderBox?)
                ?.size
                .height;
      } catch (_) {
        _headerHeight = null;
      }

      if (_headerHeight == null) {
        _detectHeaderHeight(retries + 1);
      } else {
        setState(() {});
      }
    });
  }

  @override
  String get actionName => 'Opened ${GlobalVars.barcodeScanner.getType()}_page';

  @override
  Widget build(BuildContext context) {
    final AppLocalizations appLocalizations = AppLocalizations.of(context);

    if (!CameraHelper.hasACamera) {
      return Center(
        child: Text(appLocalizations.permission_photo_none_found),
      );
    }

    return ScreenVisibilityDetector(
      child: Stack(
        children: <Widget>[
          GlobalVars.barcodeScanner.getScanner(
            onScan: _onNewBarcodeDetected,
            hapticFeedback: () => SmoothHapticFeedback.click(),
            onCameraFlashError: _onCameraFlashError,
            trackCustomEvent: AnalyticsHelper.trackCustomEvent,
            hasMoreThanOneCamera: CameraHelper.hasMoreThanOneCamera,
            toggleCameraModeTooltip: appLocalizations.camera_toggle_camera,
            toggleFlashModeTooltip: appLocalizations.camera_toggle_flash,
            contentPadding: _model.compareFeatureEnabled
                ? EdgeInsets.only(top: _headerHeight ?? 0.0)
                : null,
          ),
          Align(
            alignment: Alignment.topCenter,
            child: ScanHeader(
              key: _headerKey,
            ),
          ),
        ],
      ),
    );
  }

  Future<bool> _onNewBarcodeDetected(final String barcode) async {
    final bool isNewScan = await _model.onScan(barcode);

    if (isNewScan) {
      _userPreferences.incrementScanCount();
    }

    return isNewScan;
  }

  void _onCameraFlashError(BuildContext context) {
    final AppLocalizations appLocalizations = AppLocalizations.of(context);

    showDialog<void>(
      context: context,
      builder: (_) => SmoothAlertDialog(
        title: appLocalizations.camera_flash_error_dialog_title,
        body: Text(appLocalizations.camera_flash_error_dialog_message),
      ),
    );
  }
}
