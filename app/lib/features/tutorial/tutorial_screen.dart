import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../../core/settings/app_settings.dart';
import '../../core/settings/settings_scope.dart';
import '../../l10n/generated/app_localizations.dart';
import '../driving/pedal_mapping.dart';
import '../driving/tilt_steering.dart';
import '../driving/widgets/pedal_zones.dart';
import '../driving/widgets/steering_control.dart';
import '../driving/widgets/touch_wheel.dart';

/// Opens the tutorial: shown by itself on the first launch of a fresh
/// install, again from the settings or the home screen. Finishing or
/// skipping it marks it as seen.
/// [lockLandscape]: from the home screen, which turns freely; the driving
/// screen is already in landscape and keeps it.
Future<void> showTutorial(BuildContext context, {bool lockLandscape = true, Stream<AccelerometerEvent>? accelerometer}) =>
    Navigator.of(context).push(MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) => TutorialScreen(lockLandscape: lockLandscape, accelerometer: accelerometer),
    ));

/// Four pages, tried for real without a PC: what the app does, steering
/// (in the steering mode of the settings), the pedals, and the buttons.
class TutorialScreen extends StatefulWidget {
  /// Tilt samples for the steering page (tests inject them).
  final bool lockLandscape;
  final Stream<AccelerometerEvent>? accelerometer;
  const TutorialScreen({super.key, this.lockLandscape = true, this.accelerometer});

  static const int pageCount = 4;

  @override
  State<TutorialScreen> createState() => _TutorialScreenState();
}

class _TutorialScreenState extends State<TutorialScreen> {
  final PageController _pages = PageController();
  int _page = 0;

  @override
  void initState() {
    super.initState();
    // Like the driving screen: the phone is held as a wheel.
    if (widget.lockLandscape) {
      unawaited(SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]));
    }
  }

  @override
  void dispose() {
    _pages.dispose();
    if (widget.lockLandscape) unawaited(SystemChrome.setPreferredOrientations(DeviceOrientation.values));
    super.dispose();
  }

  Future<void> _close() async {
    final settings = SettingsScope.read(context);
    if (!settings.settings.tutorialSeen) unawaited(settings.update((s) => s.copyWith(tutorialSeen: true)));
    Navigator.of(context).pop();
  }

  void _next() {
    if (_page == TutorialScreen.pageCount - 1) {
      unawaited(_close());
    } else {
      unawaited(_pages.nextPage(duration: const Duration(milliseconds: 250), curve: Curves.easeOut));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final settings = SettingsScope.of(context).settings;
    final last = _page == TutorialScreen.pageCount - 1;
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(children: [
          Expanded(
            child: PageView(
              controller: _pages,
              onPageChanged: (page) => setState(() => _page = page),
              children: [
                _WelcomePage(l10n: l10n),
                _SteeringPage(settings: settings, accelerometer: widget.accelerometer),
                _PedalsPage(settings: settings),
                const _ButtonsPage(),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(children: [
              TextButton(onPressed: last ? null : () => unawaited(_close()), child: Text(last ? '' : l10n.tutorialSkip)),
              const Spacer(),
              for (var i = 0; i < TutorialScreen.pageCount; i++)
                Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(shape: BoxShape.circle, color: i == _page ? Colors.orangeAccent : Colors.white24),
                ),
              const Spacer(),
              FilledButton(onPressed: _next, child: Text(last ? l10n.tutorialDone : l10n.tutorialNext)),
            ]),
          ),
        ]),
      ),
    );
  }
}

/// Title and text of a page, over its interactive part.
class _Page extends StatelessWidget {
  final IconData icon;
  final String title;
  final String text;
  final Widget? child;
  const _Page({required this.icon, required this.title, required this.text, this.child});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
        child: Column(children: [
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, color: Colors.orangeAccent, size: 28),
            const SizedBox(width: 10),
            Flexible(child: Text(title, style: Theme.of(context).textTheme.titleLarge)),
          ]),
          const SizedBox(height: 8),
          Text(text, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70)),
          if (child != null) Expanded(child: child!),
        ]),
      );
}

class _WelcomePage extends StatelessWidget {
  final AppLocalizations l10n;
  const _WelcomePage({required this.l10n});

  @override
  Widget build(BuildContext context) => _Page(
        icon: Icons.sports_esports,
        title: l10n.tutorialWelcomeTitle,
        text: l10n.tutorialWelcomeText,
        child: const Center(child: Icon(Icons.phone_android, size: 96, color: Colors.white24)),
      );
}

/// Steering, tried with the steering mode of the settings: a wheel turns
/// with the phone, the bar or the thumb wheel.
class _SteeringPage extends StatefulWidget {
  final AppSettings settings;
  final Stream<AccelerometerEvent>? accelerometer;
  const _SteeringPage({required this.settings, this.accelerometer});

  @override
  State<_SteeringPage> createState() => _SteeringPageState();
}

class _SteeringPageState extends State<_SteeringPage> {
  /// 0 (full right) .. 1 (full left).
  double _steering = 0.5;

  void _onSteering(double value) {
    if (mounted && value != _steering) setState(() => _steering = value);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final s = widget.settings;
    final text = s.tiltSteering
        ? l10n.tutorialSteeringTilt
        : (s.touchWheel ? l10n.tutorialSteeringWheel : l10n.tutorialSteeringBar);
    final Widget control = s.tiltSteering
        ? SteeringControl(
            onSteering: _onSteering,
            rotationRangeDeg: s.rotationRangeDeg,
            invert: s.invertSteering,
            smoothing: s.steeringSmoothing,
            sensor: s.steeringSensor,
            accelerometer: widget.accelerometer,
          )
        : (s.touchWheel
            ? TouchWheel(onSteering: _onSteering, maxAngleDeg: TiltSteering.maxTiltDegFor(s.rotationRangeDeg))
            : SizedBox(width: 280, child: SteeringControl(onSteering: _onSteering, tiltMode: false)));
    return _Page(
      icon: Icons.screen_rotation,
      title: l10n.tutorialSteeringTitle,
      text: text,
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        // The car's wheel, turned like the game would.
        Transform.rotate(
          angle: (0.5 - _steering) * math.pi,
          child: const Icon(Icons.trip_origin, size: 84, color: Colors.lightBlueAccent),
        ),
        if (!s.tiltSteering) ...[const SizedBox(width: 32), control] else control,
      ]),
    );
  }
}

/// The real pedal zones: pressing them fills them.
class _PedalsPage extends StatelessWidget {
  final AppSettings settings;
  const _PedalsPage({required this.settings});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Stack(children: [
      Positioned.fill(
        child: PedalZones(
          mapping: PedalMapping.wide,
          onBrake: (_) {},
          onThrottle: (_) {},
          visible: true,
          swapped: settings.swapPedals,
        ),
      ),
      IgnorePointer(
        child: _Page(
          icon: Icons.swipe_up,
          title: l10n.tutorialPedalsTitle,
          text: settings.swapPedals ? l10n.tutorialPedalsTextSwapped : l10n.tutorialPedalsText,
        ),
      ),
    ]);
  }
}

class _ButtonsPage extends StatelessWidget {
  const _ButtonsPage();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    Widget row(IconData icon, String text) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(children: [
            Icon(icon, color: Colors.white54),
            const SizedBox(width: 12),
            Expanded(child: Text(text)),
          ]),
        );
    return _Page(
      icon: Icons.touch_app,
      title: l10n.tutorialButtonsTitle,
      text: l10n.tutorialButtonsText,
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(top: 12),
        child: Column(children: [
          row(Icons.volume_up, l10n.helpVolumeKeysDesc),
          row(Icons.restart_alt, l10n.tutorialButtonsReset),
          row(Icons.skip_next, l10n.helpVehicleDesc),
          row(Icons.settings, l10n.tutorialButtonsSettings),
        ]),
      ),
    );
  }
}
