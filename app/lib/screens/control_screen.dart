import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../localization/app_strings.dart';
import '../platform/gesture_exclusion.dart';
import '../protocol/beamng_client.dart';
import '../protocol/mod_packets.dart';
import '../widgets/pedal_control.dart';
import '../widgets/rpm_led_bar.dart';
import '../widgets/steering_control.dart';

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
  bool _modActive = false;
  bool _wasShiftLightOn = false;
  Duration? _latency;

  final GlobalKey _controlsRowKey = GlobalKey();
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
    // Sur certains appareils/versions d'Android, une pression prolongée
    // (n'importe où, pas seulement en bord d'écran) refait réapparaître les
    // barres système malgré le mode immersif. On le réaffirme donc en
    // continu plutôt qu'une seule fois, pour limiter la fenêtre visible de
    // la perturbation au lieu de compter sur un seul appel initial.
    _immersiveReasserTimer = Timer.periodic(
      const Duration(milliseconds: 800),
      (_) => _applyImmersiveMode(),
    );

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

    WidgetsBinding.instance.addPostFrameCallback((_) => _updateGestureExclusion());
    // Rejoue la mesure après que la mise en page se soit stabilisée (les
    // insets système peuvent encore bouger juste après le premier frame),
    // au cas où le premier calcul aurait capturé une taille transitoire.
    Future.delayed(const Duration(milliseconds: 600), _updateGestureExclusion);
  }

  void _applyImmersiveMode() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  /// Exclut la zone des pédales/volant (avec une marge généreuse) des
  /// gestes système Android (retour arrière, panneaux latéraux
  /// constructeur...), qui sinon interceptent le toucher lors d'un appui
  /// prolongé près des bords/coins de l'écran et interrompent l'affichage
  /// de l'app.
  void _updateGestureExclusion() {
    if (!mounted) return;
    final renderObject = _controlsRowKey.currentContext?.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.hasSize) return;

    const margin = 40.0;
    final topLeft = renderObject.localToGlobal(Offset.zero);
    final size = renderObject.size;
    final pixelRatio = MediaQuery.of(context).devicePixelRatio;

    final rect = Rect.fromLTWH(
      (topLeft.dx - margin) * pixelRatio,
      (topLeft.dy - margin) * pixelRatio,
      (size.width + margin * 2) * pixelRatio,
      (size.height + margin * 2) * pixelRatio,
    );

    GestureExclusion.setRects([rect]).catchError((Object e) {
      debugPrint('GestureExclusion.setRects failed: $e');
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Android peut ressortir du mode immersif après une révélation
    // temporaire des barres système (geste depuis le bord de l'écran) ;
    // on le réaffirme à chaque retour au premier plan.
    if (state == AppLifecycleState.resumed) {
      _applyImmersiveMode();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
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
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            // En paysage sur téléphone, la hauteur disponible est faible :
            // sans défilement, les derniers réglages étaient tronqués
            // (invisibles) sans aucune erreur visible.
            return SafeArea(
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
                ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Stack(
                children: [
                  Center(
                    child: _modActive
                        ? _FullDashboard(
                            client: widget.client,
                            useKmh: _useKmh,
                          )
                        : const _MinimalDashboard(),
                  ),
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
                          icon: const Icon(
                            Icons.settings,
                            color: Colors.white70,
                          ),
                          onPressed: _openSettings,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              key: _controlsRowKey,
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  PedalControl(
                    label: Strings.t('pedal_brake'),
                    color: Colors.redAccent,
                    onChanged: (v) => widget.client.updateControls(brake: v),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: SteeringControl(
                      tiltMode: _tiltMode,
                      sensitivity: _sensitivity,
                      invert: _invertSteering,
                      onSteeringChanged: (v) =>
                          widget.client.updateControls(steering: v),
                    ),
                  ),
                  const SizedBox(width: 16),
                  PedalControl(
                    label: Strings.t('pedal_throttle'),
                    color: Colors.greenAccent,
                    onChanged: (v) => widget.client.updateControls(throttle: v),
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

/// Tableau de bord complet, affiché uniquement quand le mod optionnel est
/// détecté (seule source fiable de télémétrie aujourd'hui).
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
        final speed = t == null ? 0 : (useKmh ? t.speedKmh : t.speedMph).round();
        final unit = useKmh ? 'km/h' : 'mph';

        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            RpmLedBar(rpm: t?.rpm ?? 0, redlineRpm: t?.redlineRpm ?? 7000),
            const SizedBox(height: 4),
            Text(
              '${(t?.rpm ?? 0).round()} RPM',
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
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
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 20,
                    ),
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

/// Affiché tant que le mod optionnel n'est pas détecté : seuls la
/// direction et l'accélération/freinage natifs sont disponibles, donc
/// aucune télémétrie n'est montrée (le canal natif n'en fournit pas).
class _MinimalDashboard extends StatelessWidget {
  const _MinimalDashboard();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.info_outline, color: Colors.white38, size: 36),
          const SizedBox(height: 12),
          Text(
            Strings.t('mod_banner'),
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white54, fontSize: 13),
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
      BeamngConnectionState.connected =>
        latency != null ? '${latency!.inMilliseconds}ms' : Strings.t('status_connected'),
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
                color: ratio > 0.85 ? Colors.redAccent : Colors.blueAccent,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
