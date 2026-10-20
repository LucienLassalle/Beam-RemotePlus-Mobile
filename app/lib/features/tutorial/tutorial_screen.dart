import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../../core/settings/app_settings.dart';
import '../../core/settings/settings_scope.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../themes/default/default_theme.dart';
import '../driving/driving_controller.dart';
import '../driving/pedal_mapping.dart';
import '../driving/tilt_steering.dart';
import '../driving/widgets/hold_button.dart';
import '../driving/widgets/pedal_zones.dart';
import '../driving/widgets/steering_control.dart';
import '../driving/widgets/touch_wheel.dart';
import '../settings/settings_sheet.dart' show ThemePreview;

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

/// Seven pages, tried for real without a PC: what the app does, steering (in
/// the steering mode of the settings), the pedals, the volume buttons, the
/// reset and vehicle buttons, the camera (and the video's), and where the
/// settings are.
class TutorialScreen extends StatefulWidget {
  /// Tilt samples for the steering page (tests inject them).
  final bool lockLandscape;
  final Stream<AccelerometerEvent>? accelerometer;
  const TutorialScreen({super.key, this.lockLandscape = true, this.accelerometer});

  static const int pageCount = 7;

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
                const _VolumePage(),
                const _HoldButtonsPage(),
                const _CameraPage(),
                const _SettingsPage(),
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
  /// As sent to the game: 0 (full left) .. 0.5 .. 1 (full right).
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
            realWheel: s.realWheel,
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
        // The car's wheel, turned as the game would turn it (full lock = a
        // half turn each way here).
        CustomPaint(
          size: const Size.square(120),
          painter: SteeringWheelPainter(angleDeg: (_steering - 0.5) * 180, color: Colors.lightBlueAccent),
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

/// What the phone's volume buttons do while driving, and that a theme may
/// change it.
class _VolumePage extends StatelessWidget {
  const _VolumePage();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    Widget key(IconData icon, String name, String action) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(border: Border.all(color: Colors.white38), borderRadius: BorderRadius.circular(8)),
              child: Icon(icon, color: Colors.white70),
            ),
            const SizedBox(width: 12),
            Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
            const Icon(Icons.arrow_right_alt, color: Colors.white38),
            Text(action, style: const TextStyle(color: Colors.amberAccent)),
          ]),
        );
    return _Page(
      icon: Icons.volume_up,
      title: l10n.tutorialVolumeTitle,
      text: l10n.tutorialVolumeText,
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        // Left-aligned together, like the two buttons on the side of a phone.
        IntrinsicWidth(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            key(Icons.volume_up, l10n.tutorialVolumeUp, l10n.tutorialVolumeHorn),
            key(Icons.volume_down, l10n.tutorialVolumeDown, l10n.tutorialVolumeFlash),
          ]),
        ),
        const SizedBox(height: 8),
        Text(l10n.tutorialVolumeThemes, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white54)),
      ]),
    );
  }
}

/// The buttons that must be held (so a resting thumb does nothing), to try:
/// reset the vehicle, previous / next vehicle.
class _HoldButtonsPage extends StatelessWidget {
  const _HoldButtonsPage();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return _Page(
      icon: Icons.touch_app,
      title: l10n.tutorialHoldTitle,
      text: l10n.tutorialHoldText,
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
        _HoldDemo(
          icon: Icons.restart_alt,
          color: Colors.orangeAccent,
          hold: const Duration(seconds: 1),
          label: l10n.tutorialHoldReset,
          done: l10n.tutorialHoldResetDone,
        ),
        _HoldDemo(
          icon: Icons.skip_previous,
          color: Colors.white70,
          hold: const Duration(milliseconds: 600),
          label: l10n.vehiclePrev,
          done: l10n.tutorialHoldPrevDone,
        ),
        _HoldDemo(
          icon: Icons.skip_next,
          color: Colors.white70,
          hold: const Duration(milliseconds: 600),
          label: l10n.vehicleNext,
          done: l10n.tutorialHoldNextDone,
        ),
      ]),
    );
  }
}

/// A button like the driving screen's: held for [hold], a ring fills up,
/// then [done] says what the game would do.
class _HoldDemo extends StatefulWidget {
  final IconData icon;
  final Color color;
  final Duration hold;
  final String label;
  final String done;
  const _HoldDemo({required this.icon, required this.color, required this.hold, required this.label, required this.done});

  @override
  State<_HoldDemo> createState() => _HoldDemoState();
}

class _HoldDemoState extends State<_HoldDemo> with SingleTickerProviderStateMixin {
  late final AnimationController _progress = AnimationController(vsync: this, duration: widget.hold)
    ..addStatusListener((status) {
      if (status != AnimationStatus.completed) return;
      HapticFeedback.mediumImpact();
      setState(() => _done = true);
    });
  bool _done = false;

  @override
  void dispose() {
    _progress.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Listener(
          onPointerDown: (_) {
            setState(() => _done = false);
            _progress.forward(from: 0);
          },
          onPointerUp: (_) => _progress.reset(),
          onPointerCancel: (_) => _progress.reset(),
          child: AnimatedBuilder(
            animation: _progress,
            builder: (context, _) => Stack(alignment: Alignment.center, children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _done ? widget.color : Colors.black.withValues(alpha: 0.45),
                  border: Border.all(color: widget.color.withValues(alpha: 0.5)),
                ),
                child: Icon(widget.icon, color: _done ? Colors.black : widget.color),
              ),
              if (_progress.value > 0)
                SizedBox(
                  width: 64,
                  height: 64,
                  child: CircularProgressIndicator(value: _progress.value, strokeWidth: 3, color: widget.color),
                ),
            ]),
          ),
        ),
        const SizedBox(height: 8),
        Text(widget.label, style: const TextStyle(color: Colors.white70)),
        SizedBox(
          height: 22,
          child: _done ? Text(widget.done, style: TextStyle(color: widget.color, fontWeight: FontWeight.bold)) : null,
        ),
      ]);
}

/// The camera button (tap: next, hold: previous), looking around the video
/// with a finger, and the free camera button held 1 s.
class _CameraPage extends StatelessWidget {
  const _CameraPage();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return _Page(
      icon: Icons.cameraswitch,
      title: l10n.tutorialCameraTitle,
      text: l10n.tutorialCameraText,
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
        const _CameraButtonDemo(),
        const _LookDemo(),
        _HoldDemo(
          icon: Icons.control_camera,
          color: Colors.lightBlueAccent,
          hold: const Duration(seconds: 1),
          label: l10n.helpFreeCamera,
          done: l10n.tutorialFreeCameraDone,
        ),
      ]),
    );
  }
}

/// The camera button of the driving screen: says which camera it would show.
class _CameraButtonDemo extends StatefulWidget {
  const _CameraButtonDemo();

  @override
  State<_CameraButtonDemo> createState() => _CameraButtonDemoState();
}

class _CameraButtonDemoState extends State<_CameraButtonDemo> {
  String? _done;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      HoldButton(
        icon: Icons.cameraswitch,
        tooltip: l10n.camSwitch,
        color: Colors.white70,
        size: 56,
        onPressed: () => setState(() => _done = l10n.tutorialCameraNextDone),
        onLongPress: () {
          HapticFeedback.selectionClick();
          setState(() => _done = l10n.tutorialCameraPrevDone);
        },
      ),
      const SizedBox(height: 8),
      Text(l10n.helpCamera, style: const TextStyle(color: Colors.white70)),
      SizedBox(
        height: 22,
        child: _done == null ? null : Text(_done!, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    ]);
  }
}

/// A window on the video: a swipe turns the view, which comes back to the
/// centre a moment after the finger leaves (like a seat camera), or at once
/// on a double tap.
class _LookDemo extends StatefulWidget {
  const _LookDemo();

  static const Size size = Size(180, 110);

  @override
  State<_LookDemo> createState() => _LookDemoState();
}

class _LookDemoState extends State<_LookDemo> with SingleTickerProviderStateMixin {
  Offset _view = Offset.zero;
  Timer? _recenter;
  late final AnimationController _back = AnimationController(vsync: this, duration: const Duration(milliseconds: 450))
    ..addListener(() => setState(() => _view = _from * (1 - Curves.easeOut.transform(_back.value))));
  Offset _from = Offset.zero;

  void _recentre() {
    _recenter?.cancel();
    _from = _view;
    unawaited(_back.forward(from: 0));
  }

  @override
  void dispose() {
    _recenter?.cancel();
    _back.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final limit = Offset(_LookDemo.size.width / 2 - 20, _LookDemo.size.height / 2 - 20);
    return Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      GestureDetector(
        onPanUpdate: (d) {
          _recenter?.cancel();
          _back.stop();
          setState(() => _view = Offset(
                (_view.dx + d.delta.dx).clamp(-limit.dx, limit.dx),
                (_view.dy + d.delta.dy).clamp(-limit.dy, limit.dy),
              ));
        },
        onPanEnd: (_) => _recenter = Timer(DrivingController.recenterDelay, _recentre),
        onDoubleTap: _recentre,
        child: Container(
          width: _LookDemo.size.width,
          height: _LookDemo.size.height,
          decoration: BoxDecoration(border: Border.all(color: Colors.white38), borderRadius: BorderRadius.circular(10)),
          child: Center(
            child: Transform.translate(
              offset: _view,
              child: const Icon(Icons.visibility, color: Colors.lightBlueAccent, size: 32),
            ),
          ),
        ),
      ),
      const SizedBox(height: 8),
      Text(l10n.tutorialLookLabel, style: const TextStyle(color: Colors.white70)),
      const SizedBox(height: 22),
    ]);
  }
}

/// The driving screen with its gear, top right, pointed at: the settings.
class _SettingsPage extends StatelessWidget {
  const _SettingsPage();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return _Page(
      icon: Icons.settings,
      title: l10n.tutorialSettingsTitle,
      text: l10n.tutorialSettingsText,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Stack(clipBehavior: Clip.none, children: [
            // A phone in landscape showing the driving screen.
            Container(
              padding: const EdgeInsets.fromLTRB(10, 28, 10, 10),
              decoration: BoxDecoration(
                color: Colors.black,
                border: Border.all(color: Colors.white38, width: 2),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const ThemePreview(theme: DefaultTheme(), width: 420),
            ),
            // The real buttons of the top right corner, the gear highlighted.
            Positioned(
              top: 6,
              right: 12,
              child: Row(children: [
                const Icon(Icons.radar, size: 16, color: Colors.white38),
                const SizedBox(width: 8),
                const Icon(Icons.help_outline, size: 16, color: Colors.white38),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.amberAccent, width: 2)),
                  child: const Icon(Icons.settings, size: 18, color: Colors.white),
                ),
              ]),
            ),
            Positioned(
              top: 2,
              right: -112,
              child: Row(children: [
                const Icon(Icons.west, color: Colors.amberAccent, size: 20),
                const SizedBox(width: 4),
                Text(l10n.settingsTitle, style: const TextStyle(color: Colors.amberAccent, fontWeight: FontWeight.bold)),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}
