import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/network/remote_link.dart';
import '../../core/platform/hardware_keys.dart';
import '../../core/protocol/mod_message.dart';
import '../../core/protocol/mod_protocol.dart';
import '../../core/protocol/telemetry.dart';
import '../../core/protocol/vehicle_command.dart';
import '../../core/protocol/vehicle_skeleton.dart';
import '../../core/settings/app_settings.dart';
import '../../themes/control_theme.dart';
import '../../themes/theme_registry.dart';
import '../vehicle_status/haptics_engine.dart';
import '../vehicle_status/skeleton_tracker.dart';
import 'steering_curve.dart';

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
  Map<String, String>? _optionalMods;
  int? _playerColor;
  ActionsMessage? _moreCommands;
  final Set<String> _heldMore = {};
  bool _povOffered = false;
  String? _povUnavailable;
  PovFormat? _povSent; // asked for, null while the video is off
  double _screenAspect = 16 / 9;
  PovMessage? _povState;
  PovPicture? _povPicture;
  bool _lookOffered = false;
  double _lookX = 0, _lookY = 0; // not sent yet
  Timer? _lookTimer;
  Timer? _recenterTimer;
  double _flyThrottle = 0, _flyBrake = 0;
  double _flySent = 0;
  Timer? _flyTimer;

  static const flashDuration = Duration(milliseconds: 300);

  /// Look commands per logical pixel of finger travel (the mod's unit is
  /// the game's mouse count): a swipe across a phone turns the seat
  /// camera about half a turn.
  static const double lookGain = 2;

  /// Finger moves are gathered and sent at most this often (~30 Hz).
  static const lookInterval = Duration(milliseconds: 33);

  /// A seat camera waits this long after the finger left before turning
  /// back to the road (the mod then eases it back).
  static const recenterDelay = Duration(seconds: 1);

  /// A fly command lasts 1 s in the mod: repeated well before.
  static const flyRepeat = Duration(milliseconds: 250);

  /// Steps of the fly value sent (fewer commands for the same feel).
  static const double flyStep = 0.05;

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
    _subs.add(link.modActiveChanges.listen((_) => _onModActiveChanged()));
    _subs.add(link.states.listen((_) => notifyListeners()));
    _subs.add(link.telemetry.listen(_onTelemetry));
    _subs.add(link.events.listen(_onEvent));
    _subs.add(link.qualityChanges.listen((_) => notifyListeners()));
    _subs.add(link.povPictures.listen(_onPovPicture));
  }

  bool get modActive => link.modActive;
  LinkState get linkState => link.state;

  /// Round trip to the mod in ms (null until measured), and whether the
  /// mod went silent (it brakes the car meanwhile).
  int? get latencyMs => link.latencyMs;
  bool get signalLost => link.signalLost;
  bool get readOnly => _readOnly;

  /// Incremented each time a recovery started from the phone ends.
  int get resetCount => _resetCount;
  GearFlash? get gearFlash => _gearFlash;
  Telemetry get telemetry => _telemetry;
  AppSettings get settings => _settings;
  Set<String> get heldCommands => Set.unmodifiable(_heldCommands);

  /// 0xRRGGBB colour the game gives this phone's player, null when the mod
  /// does not tell (older mod, unassigned).
  int? get playerColor => _playerColor;

  /// Commands of the "More" sheet for the current vehicle, null until the
  /// mod answered [requestMoreCommands] (never with older mods).
  ActionsMessage? get moreCommands => _moreCommands;

  /// State of each optional mod in the game by id, null while unknown.
  Map<String, String>? get optionalMods => _optionalMods;

  /// Real structure of the followed vehicle, and the damage of each of its
  /// segments (null until the mod sent it).
  VehicleSkeleton? get skeleton => _skeleton.skeleton;
  Uint8List? get skeletonLevels => _skeleton.levels;

  /// The mod can stream the view from the driver's seat (BeamNG.drive 0.40
  /// or newer): the video button and setting apply.
  bool get povAvailable => _povOffered;

  /// Why the game cannot stream the driver's view at all (see
  /// [SessionMessage.povUnavailable]): the video button says so instead of
  /// hiding. Null when it can, or when the mod does not tell.
  String? get povUnavailable => _povOffered ? null : _povUnavailable;

  /// The video shows a seat camera (the car's own dashboard is in view);
  /// null until the video is live.
  bool? get povInside => _povState?.state == PovMessage.live ? _povState!.inside : null;

  /// What the phone's player draws, while the video is on.
  PovPicture? get povPicture => _povPicture;

  /// Why there is no video: [PovMessage.errorEncoder] (the PC's graphics
  /// card has no usable video encoder), or [povErrorDecoder]. Null while
  /// all is well or the video is off.
  String? get povError {
    if (_povSent == null) return null;
    if (_povState?.state == PovMessage.failed) return _povState!.error ?? PovMessage.errorEncoder;
    if (_povPicture?.error != null) return povErrorDecoder;
    return null;
  }

  /// The phone could not decode the video.
  static const povErrorDecoder = 'decoder';

  /// The camera of the video can be turned with a finger, and switched to
  /// the free camera (newer mods, while the video is on and well).
  bool get povCameraControl => _lookOffered && _povSent != null && povError == null;

  /// The video shows the game's free camera: the pedals fly it, the car
  /// coasts.
  bool get freeCamera => povCameraControl && _povState?.free == true;

  /// Commands (horn...) only reach the game with the mod and outside read-only.
  bool get commandsEnabled => modActive && !_readOnly;

  set settings(AppSettings value) {
    _settings = value;
    _syncPov();
    notifyListeners();
  }

  /// Width / height of the area the video fills: the video is asked in that
  /// shape (a folding phone opened asks for it again).
  set screenAspect(double value) {
    if (value == _screenAspect) return;
    _screenAspect = value;
    _syncPov();
  }

  static void _noPulse(Pulse _) {}

  void _onEvent(ModMessage message) {
    if (message is SkeletonMessage && _skeleton.onChunk(message.chunk)) notifyListeners();
    if (message is ActionsMessage) {
      _moreCommands = message;
      notifyListeners();
    }
    if (message is SessionMessage && message.optionalMods != null) {
      _optionalMods = message.optionalMods;
      notifyListeners();
    }
    if (message is PovMessage) {
      final wasFree = freeCamera;
      _povState = message;
      if (freeCamera != wasFree) _onFreeCameraChanged();
      notifyListeners();
    }
    if (message is SessionMessage) {
      _playerColor = message.playerColor;
      _povOffered = message.commands.contains(ModCommand.pov);
      _povUnavailable = message.povUnavailable;
      _lookOffered = message.commands.contains(ModCommand.look);
      // A new session may be a restarted mod: ask again.
      _syncPov(resend: true);
      notifyListeners();
    }
  }

  void _onModActiveChanged() {
    if (!link.modActive) {
      _povOffered = false;
      _povUnavailable = null;
    }
    _syncPov();
    notifyListeners();
  }

  /// Point of view video on while the setting asks for it and the mod
  /// offers it, in the shape of the screen.
  void _syncPov({bool resend = false}) {
    final want = _settings.povVideo && _povOffered && link.modActive
        ? PovFormat.forScreen(_settings.povQuality, _screenAspect, _settings.povBitrate)
        : null;
    if (want != null && (want != _povSent || resend)) {
      if (want != _povSent) _povState = null;
      _povSent = want;
      link.setPovVideo(want);
    } else if (want == null && _povSent != null) {
      _povSent = null;
      _stopFlying();
      link.setPovVideo(null);
      _povState = null;
      _povPicture = null;
    }
  }

  void _onPovPicture(PovPicture picture) {
    if (_povSent == null) return;
    _povPicture = picture;
    notifyListeners();
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

  /// [value]: 0 (full right) .. 1 (full left), shaped by the centre
  /// precision setting.
  void steer(double value) {
    if (freeCamera || _readOnly) return;
    link.updateControls(steering: SteeringCurve.apply(value, _settings.steeringCenterPrecision));
  }

  /// In the free camera the brake flies it backward instead.
  void brake(double value) {
    if (freeCamera) return _fly(brake: value);
    if (!_readOnly) link.updateControls(brake: value);
  }

  /// In the free camera the throttle flies it forward instead.
  void throttle(double value) {
    if (freeCamera) return _fly(throttle: value);
    if (!_readOnly) link.updateControls(throttle: value);
  }

  // Camera of the video ------------------------------------------------------------

  /// Finger moved by [dx], [dy] logical pixels over the video: turns its
  /// camera (moves gathered, sent at most every [lookInterval]).
  void look(double dx, double dy) {
    if (!povCameraControl) return;
    _recenterTimer?.cancel();
    _lookX += dx * lookGain;
    _lookY += dy * lookGain;
    _lookTimer ??= Timer(lookInterval, _sendLook);
  }

  void _sendLook() {
    _lookTimer?.cancel();
    _lookTimer = null;
    final x = _lookX.truncate(), y = _lookY.truncate();
    if (x == 0 && y == 0) return;
    _lookX -= x;
    _lookY -= y;
    link.sendCommand(ModCommand.look, '$x|$y');
  }

  /// The finger left the video: a seat camera turns back to the road by
  /// itself after [recenterDelay], like a head.
  void lookEnded() {
    _recenterTimer?.cancel();
    if (povInside == true && !freeCamera) _recenterTimer = Timer(recenterDelay, recenterLook);
  }

  /// Puts the camera of the video back to where it looks by default.
  void recenterLook() {
    if (!povCameraControl) return;
    _recenterTimer?.cancel();
    _sendLook();
    _lookX = _lookY = 0;
    link.sendCommand(ModCommand.lookCenter);
  }

  /// Free camera on or off (the mod's pov message confirms it).
  void toggleFreeCamera() {
    if (povCameraControl) link.sendCommand(ModCommand.freecam, freeCamera ? '0' : '1');
  }

  // Entering the free camera lets the car coast, wheels straight; leaving it
  // stops the flight (the pedals drive again from their next move).
  void _onFreeCameraChanged() {
    if (freeCamera) {
      link.updateControls(steering: 0.5, throttle: 0, brake: 0);
    } else {
      _stopFlying();
    }
  }

  void _fly({double? throttle, double? brake}) {
    _flyThrottle = throttle ?? _flyThrottle;
    _flyBrake = brake ?? _flyBrake;
    final value = ((_flyThrottle - _flyBrake) / flyStep).round() * flyStep;
    if (value == _flySent) return;
    _flySent = value;
    _sendFly();
    _flyTimer?.cancel();
    _flyTimer = value == 0 ? null : Timer.periodic(flyRepeat, (_) => _sendFly());
  }

  void _sendFly() => link.sendCommand(ModCommand.fly, _flySent.toStringAsFixed(2));

  void _stopFlying() {
    _flyTimer?.cancel();
    _flyTimer = null;
    _flyThrottle = _flyBrake = _flySent = 0;
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
    for (final command in List.of(_heldMore)) {
      holdMore(VehicleCommand(id: command, hold: true), pressed: false);
    }
  }

  // "More" sheet ---------------------------------------------------------------

  /// Asks the mod for the commands of the current vehicle (answered by an
  /// actions message, see [moreCommands]).
  void requestMoreCommands() {
    if (commandsEnabled) link.sendCommand(ModCommand.actions);
  }

  void pressMore(VehicleCommand command) {
    if (commandsEnabled) link.sendCommand(ModCommand.action, command.id);
  }

  /// Press / release of a held command; a release is always sent if the
  /// press was.
  void holdMore(VehicleCommand command, {required bool pressed}) {
    if (pressed) {
      if (!commandsEnabled || !_heldMore.add(command.id)) return;
      link.sendCommand(ModCommand.actionDown, command.id);
    } else if (_heldMore.remove(command.id)) {
      link.sendCommand(ModCommand.actionUp, command.id);
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

  /// What the volume buttons do comes from the theme: horn and headlight
  /// flash while held by default, DRS and Push-to-Pass on the F4 theme.
  /// Each button can be disabled in the settings.
  void onHardwareKey(HardwareKey key, bool pressed) {
    final up = key == HardwareKey.volumeUp;
    if (up ? !_settings.hornOnVolume : !_settings.flashOnVolume) return;
    final style = themeByName(_settings.themeName).style;
    final t = _telemetry;
    switch (up ? style.volumeUp : style.volumeDown) {
      case VolumeKeyAction.horn:
        hold(ModCommand.horn, pressed: pressed);
      case VolumeKeyAction.headlightFlash:
        hold(ModCommand.highBeam, pressed: pressed);
      case VolumeKeyAction.drs:
        if (pressed && t.hasDrs == true) press(ModCommand.drs);
      case VolumeKeyAction.pushToPass:
        if (pressed && t.hasPushToPass == true) press(ModCommand.pushToPass);
    }
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
    if (_povSent != null) link.setPovVideo(null);
    _flashTimer?.cancel();
    _lookTimer?.cancel();
    _flyTimer?.cancel();
    _recenterTimer?.cancel();
    for (final s in _subs) {
      s.cancel();
    }
    super.dispose();
  }
}
