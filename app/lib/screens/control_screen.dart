import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../localization/app_strings.dart';
import '../platform/gesture_exclusion.dart';
import '../protocol/beamng_client.dart';
import '../protocol/mod_packets.dart';
import '../protocol/protocol_constants.dart';
import '../themes/control_theme.dart';
import '../themes/theme_registry.dart';
import '../widgets/reset_vehicle_button.dart';
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
  bool _readOnly = false;
  String _themeId = 'default';
  bool _tiltMode = true;
  double _rotationRangeDeg = 900;
  bool _invertSteering = true;
  bool _steeringSmoothing = true;
  static const List<double> _rotationRangeOptions = [360, 540, 720, 900];
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
                  title: Text(Strings.t('settings_readonly_title')),
                  subtitle: Text(Strings.t('settings_readonly_subtitle')),
                  secondary: const Icon(Icons.visibility_outlined),
                  value: _readOnly,
                  onChanged: (v) {
                    setSheetState(() => _readOnly = v);
                    _setReadOnly(v);
                  },
                ),
                ListTile(
                  title: Text(Strings.t('settings_theme_title')),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(Strings.t('settings_theme_subtitle')),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          for (final t in availableThemes)
                            ChoiceChip(
                              label: Text(t.displayName),
                              selected: _themeId == t.id,
                              onSelected: (_) {
                                setSheetState(() => _themeId = t.id);
                                setState(() => _themeId = t.id);
                              },
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                const Divider(height: 24),
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
                  title: Text(Strings.t('settings_rotation_range_title')),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(Strings.t('settings_rotation_range_subtitle')),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: [
                          for (final r in _rotationRangeOptions)
                            ChoiceChip(
                              label: Text('${r.round()}°'),
                              selected: _rotationRangeDeg == r,
                              onSelected: (_) {
                                setSheetState(() => _rotationRangeDeg = r);
                                setState(() => _rotationRangeDeg = r);
                              },
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        Strings.t('settings_rotation_range_hint').replaceFirst(
                          '{deg}',
                          SteeringControl.maxTiltDegFor(_rotationRangeDeg)
                              .round()
                              .toString(),
                        ),
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.white38,
                        ),
                      ),
                    ],
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
                  title: Text(Strings.t('settings_smoothing_title')),
                  subtitle: Text(Strings.t('settings_smoothing_subtitle')),
                  value: _steeringSmoothing,
                  onChanged: !_tiltMode
                      ? null
                      : (v) {
                          setSheetState(() => _steeringSmoothing = v);
                          setState(() => _steeringSmoothing = v);
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

  // ── Mode lecture seule ────────────────────────────────────────────────
  // Coupe uniquement les entrées qui font bouger le véhicule (volant,
  // frein, accélérateur, changement de rapport, caméra, véhicule, reset) ;
  // les réglages et l'aide restent toujours accessibles, quel que soit le
  // thème actif (voir ControlSurface / chrome obligatoire dans build()).
  void _setReadOnly(bool v) {
    setState(() => _readOnly = v);
    if (v) {
      widget.client.updateControls(steering: 0.5, throttle: 0, brake: 0);
    }
  }

  void _updateSteering(double v) {
    if (_readOnly) return;
    widget.client.updateControls(steering: v);
  }

  void _updateBrake(double v) {
    if (_readOnly) return;
    widget.client.updateControls(brake: v);
  }

  void _updateThrottle(double v) {
    if (_readOnly) return;
    widget.client.updateControls(throttle: v);
  }

  void _recoverStart() => _sendCmd(ModProtocol.cmdRecoverStart);

  void _recoverStop() {
    _sendCmd(ModProtocol.cmdRecoverStop);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(Strings.t('reset_vehicle_done')),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

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
              _HelpRow(
                icon: Icons.restart_alt,
                color: Colors.white54,
                title: Strings.t('help_reset_vehicle'),
                desc: Strings.t('help_reset_vehicle_desc'),
                modRequired: true,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Widgets de contrôle pré-câblés, fournis à n'importe quel thème via
  // ControlSurface : la logique (capteurs, gating lecture-seule, mod actif)
  // vit ici une seule fois, un thème ne fait que les positionner. ────────

  Widget get _steeringWidget => IgnorePointer(
        ignoring: _readOnly,
        child: SteeringControl(
          tiltMode: _tiltMode,
          rotationRangeDeg: _rotationRangeDeg,
          invert: _invertSteering,
          smoothing: _steeringSmoothing,
          recalibrateCounter: _recalibrateCounter,
          onSteeringChanged: _updateSteering,
          onGearUp: (_pitchGearShift && _modActive && !_readOnly)
              ? () {
                  _sendCmd(ModProtocol.cmdGearUp);
                  _triggerGearFlash(isUp: true);
                }
              : null,
          onGearDown: (_pitchGearShift && _modActive && !_readOnly)
              ? () {
                  _sendCmd(ModProtocol.cmdGearDown);
                  _triggerGearFlash(isUp: false);
                }
              : null,
        ),
      );

  Widget get _pedalsWidget => IgnorePointer(
        ignoring: _readOnly,
        child: ZoneControls(
          onBrakeChanged: _updateBrake,
          onThrottleChanged: _updateThrottle,
        ),
      );

  Widget get _pedalsWidgetInvisible => IgnorePointer(
        ignoring: _readOnly,
        child: ZoneControls(
          onBrakeChanged: _updateBrake,
          onThrottleChanged: _updateThrottle,
          showChrome: false,
        ),
      );

  Widget get _cameraButtonsWidget {
    if (!_modActive) return const SizedBox.shrink();
    return IgnorePointer(
      ignoring: _readOnly,
      child: AnimatedOpacity(
        opacity: _readOnly ? 0.3 : 1.0,
        duration: const Duration(milliseconds: 200),
        child: Row(
          mainAxisSize: MainAxisSize.min,
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
    );
  }

  Widget get _vehicleSwitchWidget => VehicleSwitchButtons(
        enabled: _modActive && !_readOnly,
        onPrev: () => _sendCmd(ModProtocol.cmdPrevVehicle),
        onNext: () => _sendCmd(ModProtocol.cmdNextVehicle),
      );

  Widget get _resetVehicleWidget => ResetVehicleButton(
        enabled: _modActive && !_readOnly,
        onRecoverStart: _recoverStart,
        onRecoverStop: _recoverStop,
      );

  @override
  Widget build(BuildContext context) {
    final surface = ControlSurface(
      telemetry: widget.client.modTelemetryStream,
      modActive: _modActive,
      connectionState: widget.client.state,
      latency: _latency,
      useKmh: _useKmh,
      readOnly: _readOnly,
      gearFlashColor: _gearFlashColor,
      steeringWidget: _steeringWidget,
      pedalsWidget: _pedalsWidget,
      pedalsWidgetInvisible: _pedalsWidgetInvisible,
      cameraButtonsWidget: _cameraButtonsWidget,
      vehicleSwitchWidget: _vehicleSwitchWidget,
      resetVehicleWidget: _resetVehicleWidget,
    );

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            themeById(_themeId).build(context, surface),

            // ── Chrome obligatoire : Paramètres + Aide. Toujours posé
            // par-dessus le thème actif, jamais masquable par lui — c'est
            // le seul moyen garanti de sortir du mode lecture seule ou de
            // changer de thème. ─────────────────────────────────────────
            Positioned(
              top: 4,
              right: 4,
              child: Row(
                children: [
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
          ],
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────

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
