import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../core/debug/debug_monitor.dart';
import '../../core/network/beamng_connection.dart';
import '../../core/platform/gesture_exclusion.dart';
import '../../core/platform/hardware_keys.dart';
import '../../core/settings/settings_scope.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../themes/theme_registry.dart';
import '../debug/debug_overlay.dart';
import '../help/help_sheet.dart';
import '../settings/settings_sheet.dart';
import 'driving_controller.dart';
import 'driving_view.dart';

/// Driving screen: owns the controller and the platform side effects
/// (immersive mode, wakelock, volume keys, gesture exclusion); the layout is
/// in [DrivingView].
class DrivingScreen extends StatefulWidget {
  final BeamngConnection connection;
  const DrivingScreen({super.key, required this.connection});

  @override
  State<DrivingScreen> createState() => _DrivingScreenState();
}

class _DrivingScreenState extends State<DrivingScreen> with WidgetsBindingObserver {
  late final DrivingController _controller;
  late final DebugMonitor _debug;
  int _recalibrate = 0;
  Timer? _immersiveTimer;

  @override
  void initState() {
    super.initState();
    final settings = SettingsScope.read(context).settings;
    _controller = DrivingController(
      link: widget.connection,
      settings: settings,
      onShiftPoint: HapticFeedback.mediumImpact,
    );
    _debug = DebugMonitor(widget.connection);
    widget.connection.setDebugAcks(settings.debugMode);
    WidgetsBinding.instance.addObserver(this);
    unawaited(WakelockPlus.enable());
    unawaited(SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]));
    _enterImmersive();
    // Some phones leave immersive mode on their own (notification shade...).
    _immersiveTimer = Timer.periodic(const Duration(seconds: 3), (_) => _enterImmersive());
    WidgetsBinding.instance.addPostFrameCallback((_) => _excludeSystemGestures());
    unawaited(HardwareKeys.capture(_controller.onHardwareKey));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final settings = SettingsScope.of(context).settings;
    if (!identical(settings, _controller.settings)) {
      _controller.settings = settings;
      widget.connection.setDebugAcks(settings.debugMode);
    }
  }

  void _enterImmersive() => unawaited(SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky));

  /// The whole screen is pedals: keep Android back/edge gestures away.
  void _excludeSystemGestures() {
    if (!mounted) return;
    final media = MediaQuery.of(context);
    final size = media.size * media.devicePixelRatio;
    unawaited(GestureExclusion.setRects([Offset.zero & size]));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _enterImmersive();
    if (state == AppLifecycleState.paused) _controller.releaseAllHolds();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _immersiveTimer?.cancel();
    unawaited(HardwareKeys.release());
    unawaited(WakelockPlus.disable());
    unawaited(SystemChrome.setPreferredOrientations(DeviceOrientation.values));
    unawaited(SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge));
    _controller.dispose();
    _debug.dispose();
    widget.connection.dispose();
    super.dispose();
  }

  void _showRecovered() {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(AppLocalizations.of(context).resetVehicleDone),
      duration: const Duration(seconds: 1),
      behavior: SnackBarBehavior.floating,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final settings = SettingsScope.of(context).settings;
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: DrivingView(
          controller: _controller,
          settings: settings,
          theme: themeByName(settings.themeName),
          recalibrateCounter: _recalibrate,
          hostButtons: _hostButtons(context),
          onRecovered: _showRecovered,
          debugOverlay: settings.debugMode ? DebugOverlay(monitor: _debug, link: widget.connection) : null,
        ),
      ),
    );
  }

  Widget _hostButtons(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // Always on top of every theme: the guaranteed way out of read-only mode.
    return Row(mainAxisSize: MainAxisSize.min, children: [
      IconButton(
        icon: const Icon(Icons.help_outline, color: Colors.white54),
        tooltip: l10n.helpTitle,
        onPressed: () => showHelpSheet(context),
      ),
      IconButton(
        icon: const Icon(Icons.settings, color: Colors.white70),
        tooltip: l10n.settingsTitle,
        onPressed: () => showSettingsSheet(
          context,
          readOnly: _controller.readOnly,
          onReadOnlyChanged: _controller.setReadOnly,
          onRecalibrate: () => setState(() => _recalibrate++),
        ),
      ),
    ]);
  }
}
