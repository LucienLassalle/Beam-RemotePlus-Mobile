import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../localization/app_strings.dart';
import '../platform/gesture_exclusion.dart';
import '../protocol/beamng_client.dart';
import '../protocol/mod_packets.dart';
import '../protocol/protocol_constants.dart';
import '../widgets/rpm_led_bar.dart';
import '../widgets/steering_control.dart';
import '../widgets/vehicle_switch_buttons.dart';
import '../widgets/zone_controls.dart';

class ControlScreen extends StatefulWidget {
  final BeamngClient client;

  const ControlScreen({super.key, required this.client});

  @override
  State<ControlScreen> createState() => _ControlScreenState();
}

class _ControlScreenState extends State<ControlScreen>
    with WidgetsBindingObserver {
  bool _tiltMode = true;
  double _sensitivity = 0.6;
  bool _invertSteering = true;
  bool _useKmh = true;
  bool _hapticsOnShift = false;
  bool _pitchGearShift = false;
  bool _modActive = false;
  bool _wasShiftLightOn = false;
  Duration? _latency;

  // Recalibration : incrémenter déclenche un reset dans SteeringControl.
  int _recalibrateCounter = 0;

  // Flash visuel au changement de rapport.
  Color? _gearFlashColor;
  Timer? _gearFlashTimer;

  StreamSubscription<bool>? _modActiveSub;
  StreamSubscription<ModTelemetryPacket>? _modTelemetrySub;
  Timer? _immersiveReasserTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WakelockPlus.enable();
    _applyImmersiveMode();
    SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeLeft]);
    // Réaffirmation périodique : certains appareils sortent du mode immersif
    // lors d'un appui prolongé malgré immersiveSticky.
    _immersiveReasserTimer = Timer.periodic(
      const Duration(milliseconds: 800),
      (_) => _applyImmersiveMode(),
    );
    // Exclure toute la zone de contrôle des gestes système Android au
    // prochain frame (taille réelle disponible après layout).
    WidgetsBinding.instance.addPostFrameCallback((_) => _setFullScreenExclusion());
    Future.delayed(const Duration(milliseconds: 600), _setFullScreenExclusion);

    _modActive = widget.client.modActive;
    widget.client.latencyStream.listen((d) {
      if (mounted) setState(() => _latency = d);
    });
    _modActiveSub = widget.client.modActiveStream.listen((active) {
      if (mounted) setState(() => _modActive = active);
    });
    _modTelemetrySub = widget.client.modTelemetryStream.listen((t) {
      if (_hapticsOnShift && t.shiftLight && !_wasShiftLightOn) {
        HapticFeedback.mediumImpact();
      }
      _wasShiftLightOn = t.shiftLight;
    });
  }

  void _applyImmersiveMode() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  void _setFullScreenExclusion() {
    if (!mounted) return;
    final size = MediaQuery.of(context).size;
    final ratio = MediaQuery.of(context).devicePixelRatio;
    // Exclut la totalité de l'écran : empêche les gestes système (bord
    // gauche/droit/bas) d'interférer avec les zones de frein/accélérateur
    // qui occupent les côtés de l'affichage.
    final rect = Rect.fromLTWH(0, 0, size.width * ratio, size.height * ratio);
    GestureExclusion.setRects([rect]).catchError((Object e) {
      debugPrint('GestureExclusion error: $e');
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _applyImmersiveMode();
  }

  void _triggerGearFlash({required bool isUp}) {
    _gearFlashTimer?.cancel();
    setState(() => _gearFlashColor = isUp ? Colors.cyanAccent : Colors.orangeAccent);
    _gearFlashTimer = Timer(const Duration(milliseconds: 280), () {
      if (mounted) setState(() => _gearFlashColor = null);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _gearFlashTimer?.cancel();
    WakelockPlus.disable();
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _immersiveReasserTimer?.cancel();
    _modActiveSub?.cancel();
    _modTelemetrySub?.cancel();
    widget.client.dispose();
    super.dispose();
  }

  void _openSettings() {
    showModalBottomSheet(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  Strings.t('settings_title'),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                SwitchListTile(
                  title: Text(Strings.t('settings_tilt_title')),
                  subtitle: Text(Strings.t('settings_tilt_subtitle')),
                  value: _tiltMode,
                  onChanged: (v) {
                    setSheetState(() => _tiltMode = v);
                    setState(() => _tiltMode = v);
                  },
                ),
                ListTile(
                  title: Text(Strings.t('settings_sensitivity_title')),
                  subtitle: Slider(
                    min: 0.2,
                    max: 1.0,
                    value: _sensitivity,
                    onChanged: (v) {
                      setSheetState(() => _sensitivity = v);
                      setState(() => _sensitivity = v);
                    },
                  ),
                ),
                SwitchListTile(
                  title: Text(Strings.t('settings_invert_title')),
                  value: _invertSteering,
                  onChanged: (v) {
                    setSheetState(() => _invertSteering = v);
                    setState(() => _invertSteering = v);
                  },
                ),
                SwitchListTile(
                  title: Text(Strings.t('settings_unit_title')),
                  subtitle: Text(Strings.t('settings_unit_subtitle')),
                  value: _useKmh,
                  onChanged: (v) {
                    setSheetState(() => _useKmh = v);
                    setState(() => _useKmh = v);
                  },
                ),
                SwitchListTile(
                  title: Text(Strings.t('settings_haptics_title')),
                  subtitle: Text(Strings.t('settings_haptics_subtitle')),
                  value: _hapticsOnShift,
                  onChanged: !_modActive
                      ? null
                      : (v) {
                          setSheetState(() => _hapticsOnShift = v);
                          setState(() => _hapticsOnShift = v);
                        },
                ),
                SwitchListTile(
                  title: Text(Strings.t('settings_pitch_gear_title')),
                  subtitle: Text(Strings.t('settings_pitch_gear_subtitle')),
                  value: _pitchGearShift,
                  onChanged: !_tiltMode
                      ? null
                      : (v) {
                          setSheetState(() => _pitchGearShift = v);
                          setState(() => _pitchGearShift = v);
                        },
                ),
                // ── Options avancées ──────────────────────────────────────
                const Divider(height: 24),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 16, bottom: 4),
                    child: Text(
                      Strings.t('settings_advanced_title'),
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: Colors.white38,
                            letterSpacing: 1.2,
                          ),
                    ),
                  ),
                ),
                ListTile(
                  title: Text(Strings.t('settings_recalibrate_title')),
                  subtitle: Text(Strings.t('settings_recalibrate_subtitle')),
                  enabled: _tiltMode,
                  trailing: const Icon(Icons.my_location, size: 20),
                  onTap: !_tiltMode
                      ? null
                      : () {
                          setState(() => _recalibrateCounter++);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content:
                                  Text(Strings.t('settings_recalibrate_done')),
                              duration: const Duration(seconds: 2),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _sendCmd(String cmd) => widget.client.sendCommand(cmd);

  void _openHelp() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Text(
                  Strings.t('help_title'),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              const SizedBox(height: 12),
              _HelpRow(
                icon: Icons.swipe_left_alt,
                color: Colors.redAccent,
                title: Strings.t('help_brake'),
                desc: Strings.t('help_brake_desc'),
              ),
              _HelpRow(
                icon: Icons.swipe_right_alt,
                color: Colors.greenAccent,
                title: Strings.t('help_throttle'),
                desc: Strings.t('help_throttle_desc'),
              ),
              if (_tiltMode)
                _HelpRow(
                  icon: Icons.screen_rotation,
                  color: Colors.blueAccent,
                  title: Strings.t('help_steering_tilt'),
                  desc: Strings.t('help_steering_tilt_desc'),
                )
              else
                _HelpRow(
                  icon: Icons.drag_handle,
                  color: Colors.blueAccent,
                  title: Strings.t('help_steering_touch'),
                  desc: Strings.t('help_steering_touch_desc'),
                ),
              if (_tiltMode && _pitchGearShift)
                _HelpRow(
                  icon: Icons.arrow_upward,
                  color: Colors.cyanAccent,
                  title: Strings.t('help_gear_pitch'),
                  desc: Strings.t('help_gear_pitch_desc'),
                  modRequired: true,
                ),
              _HelpRow(
                icon: Icons.skip_previous,
                color: Colors.white54,
                title: Strings.t('help_vehicle'),
                desc: Strings.t('help_vehicle_desc'),
                modRequired: true,
              ),
              _HelpRow(
                icon: Icons.flip_camera_android,
                color: Colors.white54,
                title: Strings.t('help_camera'),
                desc: Strings.t('help_camera_desc'),
                modRequired: true,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            // ── Couche 0 : zones tactiles frein / accélérateur ──────────
            Positioned.fill(
              child: ZoneControls(
                onBrakeChanged: (v) => widget.client.updateControls(brake: v),
                onThrottleChanged: (v) =>
                    widget.client.updateControls(throttle: v),
              ),
            ),

            // ── Couche 1 : tableau de bord centré ───────────────────────
            Center(
              child: _modActive
                  ? _FullDashboard(client: widget.client, useKmh: _useKmh)
                  : const _MinimalDashboard(),
            ),

            // ── Couche 2 : volant ────────────────────────────────────────
            if (!_tiltMode)
              Positioned(
                bottom: 20,
                left: MediaQuery.of(context).size.width * 0.33,
                right: MediaQuery.of(context).size.width * 0.33,
                child: SteeringControl(
                  tiltMode: false,
                  sensitivity: _sensitivity,
                  invert: _invertSteering,
                  recalibrateCounter: _recalibrateCounter,
                  onSteeringChanged: (v) =>
                      widget.client.updateControls(steering: v),
                ),
              )
            else
              Positioned(
                width: 0,
                height: 0,
                child: SteeringControl(
                  tiltMode: true,
                  sensitivity: _sensitivity,
                  invert: _invertSteering,
                  recalibrateCounter: _recalibrateCounter,
                  onSteeringChanged: (v) =>
                      widget.client.updateControls(steering: v),
                  onGearUp: (_pitchGearShift && _modActive)
                      ? () {
                          _sendCmd(ModProtocol.cmdGearUp);
                          _triggerGearFlash(isUp: true);
                        }
                      : null,
                  onGearDown: (_pitchGearShift && _modActive)
                      ? () {
                          _sendCmd(ModProtocol.cmdGearDown);
                          _triggerGearFlash(isUp: false);
                        }
                      : null,
                ),
              ),

            // ── Couche 3 : boutons caméra (centre, bas) ─────────────────
            if (_modActive)
              Positioned(
                bottom: 8,
                left: 0,
                right: 0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _CamButton(
                      icon: Icons.photo_camera_back,
                      tooltip: Strings.t('cam_prev'),
                      onTap: () => _sendCmd(ModProtocol.cmdCamPrev),
                    ),
                    const SizedBox(width: 8),
                    _CamButton(
                      icon: Icons.flip_camera_android,
                      tooltip: Strings.t('cam_next'),
                      onTap: () => _sendCmd(ModProtocol.cmdCamNext),
                    ),
                  ],
                ),
              ),

            // ── Couche 3b : flash visuel changement de rapport ──────────
            if (_gearFlashColor != null)
              Positioned.fill(
                child: IgnorePointer(
                  child: Container(
                    color: _gearFlashColor!.withValues(alpha: 0.22),
                  ),
                ),
              ),

            // ── Couche 4 : statut + réglages + aide (haut droite) ───────
            Positioned(
              top: 4,
              right: 4,
              child: Row(
                children: [
                  _StatusChip(
                    connectionState: widget.client.state,
                    latency: _latency,
                  ),
                  IconButton(
                    icon: const Icon(Icons.help_outline, color: Colors.white54),
                    iconSize: 20,
                    onPressed: _openHelp,
                    tooltip: '?',
                  ),
                  IconButton(
                    icon: const Icon(Icons.settings, color: Colors.white70),
                    onPressed: _openSettings,
                  ),
                ],
              ),
            ),

            // ── Couche 5 : changement de véhicule (haut gauche) ─────────
            Positioned(
              top: 4,
              left: 4,
              child: VehicleSwitchButtons(
                enabled: _modActive,
                onPrev: () => _sendCmd(ModProtocol.cmdPrevVehicle),
                onNext: () => _sendCmd(ModProtocol.cmdNextVehicle),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────

class _FullDashboard extends StatelessWidget {
  final BeamngClient client;
  final bool useKmh;

  const _FullDashboard({required this.client, required this.useKmh});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<ModTelemetryPacket>(
      stream: client.modTelemetryStream,
      builder: (context, snapshot) {
        final t = snapshot.data;
        final speed =
            t == null ? 0 : (useKmh ? t.speedKmh : t.speedMph).round();
        final unit = useKmh ? 'km/h' : 'mph';

        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            RpmLedBar(
              rpm: t?.rpm ?? 0,
              redlineRpm: t?.redlineRpm ?? 7000,
            ),
            const SizedBox(height: 4),
            Text(
              '${(t?.rpm ?? 0).round()} RPM',
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$speed',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 88,
                    fontWeight: FontWeight.bold,
                    height: 1,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 18, left: 6),
                  child: Text(
                    unit,
                    style: const TextStyle(color: Colors.white70, fontSize: 20),
                  ),
                ),
                const SizedBox(width: 28),
                Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Text(
                    t?.gearLabel ?? '-',
                    style: const TextStyle(
                      color: Colors.orangeAccent,
                      fontSize: 44,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                _MiniGauge(
                  label: Strings.t('gauge_fuel'),
                  value: (t?.fuel ?? 0) * 100,
                  max: 100,
                ),
                const SizedBox(width: 16),
                _MiniGauge(
                  label: Strings.t('gauge_temp'),
                  value: t?.engineTemp ?? 0,
                  max: 120,
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _MinimalDashboard extends StatelessWidget {
  const _MinimalDashboard();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.info_outline, color: Colors.white24, size: 28),
          const SizedBox(height: 8),
          Text(
            Strings.t('mod_banner'),
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white38, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final BeamngConnectionState connectionState;
  final Duration? latency;

  const _StatusChip({required this.connectionState, required this.latency});

  @override
  Widget build(BuildContext context) {
    final label = switch (connectionState) {
      BeamngConnectionState.connected => latency != null
          ? '${latency!.inMilliseconds}ms'
          : Strings.t('status_connected'),
      BeamngConnectionState.discovering => Strings.t('status_connecting'),
      BeamngConnectionState.timeout => Strings.t('status_timeout'),
      BeamngConnectionState.error => Strings.t('status_error'),
      BeamngConnectionState.idle => Strings.t('status_idle'),
    };
    final color = connectionState == BeamngConnectionState.connected
        ? Colors.greenAccent
        : Colors.redAccent;
    return Text(label, style: TextStyle(color: color, fontSize: 12));
  }
}

class _MiniGauge extends StatelessWidget {
  final String label;
  final double value;
  final double max;

  const _MiniGauge({
    required this.label,
    required this.value,
    required this.max,
  });

  @override
  Widget build(BuildContext context) {
    final ratio = max == 0 ? 0.0 : (value / max).clamp(0.0, 1.0);
    return SizedBox(
      width: 120,
      child: Row(
        children: [
          SizedBox(
            width: 44,
            child: Text(
              label,
              style: const TextStyle(color: Colors.white54, fontSize: 11),
            ),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: ratio,
                minHeight: 6,
                backgroundColor: Colors.white12,
                color:
                    ratio > 0.85 ? Colors.redAccent : Colors.blueAccent,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HelpRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String desc;
  final bool modRequired;

  const _HelpRow({
    required this.icon,
    required this.color,
    required this.title,
    required this.desc,
    this.modRequired = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 13)),
                    if (modRequired) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: Colors.white12,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          Strings.t('help_mod_required'),
                          style: const TextStyle(
                              fontSize: 9, color: Colors.white38),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(desc,
                    style: const TextStyle(
                        fontSize: 12, color: Colors.white54)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CamButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _CamButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.black38,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Icon(icon, color: Colors.white54, size: 22),
          ),
        ),
      ),
    );
  }
}
