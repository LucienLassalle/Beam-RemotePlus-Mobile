import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/network/remote_link.dart';
import '../../core/platform/hardware_keys.dart';
import '../../core/protocol/mod_message.dart';
import '../../core/protocol/mod_protocol.dart';
import '../../core/protocol/telemetry.dart';
import '../../core/protocol/vehicle_skeleton.dart';
import '../../core/settings/app_settings.dart';
import '../../themes/control_theme.dart';
import '../vehicle_status/haptics_engine.dart';
import '../vehicle_status/skeleton_tracker.dart';

/// Logic of the driving screen (the view is driving_screen.dart): routes the
/// inputs to the game, tracks held commands, gear-change flashes, read-only
/// mode and haptics. No widget code here, fully unit-tested.
class DrivingController extends ChangeNotifier {
  final RemoteLink link;

  /// The engine reached the rev limiter (rising edge).
  final VoidCallback onLimiter;
  final void Function(Pulse pulse) onPulse;
  final HapticsEngine _haptics = HapticsEngine();
  late final SkeletonTracker _skeleton = SkeletonTracker(request: () => link.sendCommand(ModCommand.skeleton));
  AppSettings _settings;

  final Set<String> _heldCommands = {};
  final List<StreamSubscription<Object?>> _subs = [];
  Timer? _flashTimer;
  bool _readOnly = false;
  int _resetCount = 0;
  bool _atLimiter = false;
  GearFlash? _gearFlash;
  Telemetry _telemetry = Telemetry.empty;

  static const flashDuration = Duration(milliseconds: 300);

  /// Share of the max RPM where the limiter vibration fires, and where it
  /// re-arms (hysteresis: one vibration per hit, not per frame).
  static const double limiterOn = 0.97;
  static const double limiterOff = 0.93;

  DrivingController({
    required this.link,
    required AppSettings settings,
    required this.onLimiter,
    void Function(Pulse pulse)? onPulse,
  })  : onPulse = onPulse ?? _noPulse,
        _settings = settings {
    _subs.add(link.modActiveChanges.listen((_) => notifyListeners()));
    _subs.add(link.states.listen((_) => notifyListeners()));
    _subs.add(link.telemetry.listen(_onTelemetry));
    _subs.add(link.events.listen(_onEvent));
  }

  bool get modActive => link.modActive;
  LinkState get linkState => link.state;
  bool get readOnly => _readOnly;

  /// Incremented each time a recovery started from the phone ends.
  int get resetCount => _resetCount;
  GearFlash? get gearFlash => _gearFlash;
  Telemetry get telemetry => _telemetry;
  AppSettings get settings => _settings;
  Set<String> get heldCommands => Set.unmodifiable(_heldCommands);

  /// Real structure of the followed vehicle, and the damage of each of its
  /// segments (null until the mod sent it).
  VehicleSkeleton? get skeleton => _skeleton.skeleton;
  Uint8List? get skeletonLevels => _skeleton.levels;

  /// Commands (horn...) only reach the game with the mod and outside read-only.
  bool get commandsEnabled => modActive && !_readOnly;

  set settings(AppSettings value) {
    _settings = value;
    notifyListeners();
  }

  static void _noPulse(Pulse _) {}

  void _onEvent(ModMessage message) {
    if (message is SkeletonMessage && _skeleton.onChunk(message.chunk)) notifyListeners();
  }

  void _onTelemetry(Telemetry t) {
    _telemetry = t;
    _skeleton.onTelemetry(t, DateTime.now());
    final s = _settings;
    if (s.anyRoadHaptics && !s.secondScreen) {
      _haptics.strength = s.hapticStrength;
      final pulse = _haptics.update(t, DateTime.now(), enabled: {
        if (s.hapticSpin) HapticKind.spin,
        if (s.hapticLock) HapticKind.lock,
        if (s.hapticImpacts) HapticKind.impact,
        if (s.hapticKerbs) HapticKind.kerb,
        if (s.hapticAbs) HapticKind.abs,
      });
      if (pulse != null) onPulse(pulse);
    }
    final ratio = t.rpmRatio;
    if (ratio != null) {
      if (!_atLimiter && ratio >= limiterOn) {
        _atLimiter = true;
        if (s.hapticLimiter && !s.secondScreen) onLimiter();
      } else if (ratio < limiterOff) {
        _atLimiter = false;
      }
    }
    notifyListeners();
  }

  // Analog inputs ---------------------------------------------------------------

  void steer(double value) {
    if (!_readOnly) link.updateControls(steering: value);
  }

  void brake(double value) {
    if (!_readOnly) link.updateControls(brake: value);
  }

  void throttle(double value) {
    if (!_readOnly) link.updateControls(throttle: value);
  }

  // Commands --------------------------------------------------------------------

  void press(String command) {
    if (commandsEnabled) link.sendCommand(command);
  }

  /// Press/release of a hold command (horn, high beams...). A release is
  /// always sent if the press was, even if read-only was switched on since.
  void hold(String command, {required bool pressed}) {
    if (pressed) {
      if (!commandsEnabled || !_heldCommands.add(command)) return;
      link.sendCommand(command, '1');
    } else if (_heldCommands.remove(command)) {
      link.sendCommand(command, '0');
      if (command == ModCommand.recover) {
        _resetCount++;
        notifyListeners();
      }
    }
  }

  void releaseAllHolds() {
    for (final command in List.of(_heldCommands)) {
      hold(command, pressed: false);
    }
  }

  void shift({required bool up}) {
    if (!commandsEnabled) return;
    link.sendCommand(up ? ModCommand.gearUp : ModCommand.gearDown);
    _gearFlash = up ? GearFlash.up : GearFlash.down;
    _flashTimer?.cancel();
    _flashTimer = Timer(flashDuration, () {
      _gearFlash = null;
      notifyListeners();
    });
    notifyListeners();
  }

  /// Volume up = horn, volume down = headlight flash, while held (each one
  /// can be disabled in the settings).
  void onHardwareKey(HardwareKey key, bool pressed) {
    final up = key == HardwareKey.volumeUp;
    if (up ? !_settings.hornOnVolume : !_settings.flashOnVolume) return;
    hold(up ? ModCommand.horn : ModCommand.highBeam, pressed: pressed);
  }

  void setReadOnly(bool value) {
    _readOnly = value;
    if (value) {
      releaseAllHolds();
      link.updateControls(steering: 0.5, throttle: 0, brake: 0);
    }
    notifyListeners();
  }

  @override
  void dispose() {
    releaseAllHolds();
    _flashTimer?.cancel();
    for (final s in _subs) {
      s.cancel();
    }
    super.dispose();
  }
}
