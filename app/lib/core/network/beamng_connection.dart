import 'dart:async';
import 'dart:io';

import '../debug/debug_log.dart';
import '../platform/app_version.dart';
import '../platform/device_name.dart';
import '../platform/pov_video.dart';
import '../protocol/mod_message.dart';
import '../protocol/mod_protocol.dart';
import '../protocol/native_protocol.dart';
import '../protocol/telemetry.dart';
import 'broadcast.dart';
import 'mod_channel.dart';
import 'native_channel.dart';
import 'pov_session.dart';
import 'remote_link.dart';
import 'udp_endpoint.dart';

/// Connection to BeamNG.drive.
///
/// 1. Native handshake (port 4444) with the pairing code: finds the PC and
///    gives steering + on/off pedals even without the mod ([NativeChannel]).
/// 2. Mod probe (port 4446): once the mod answers, controls switch to its
///    analog channel at 60 Hz and telemetry/commands become available
///    ([ModChannel]).
///
/// The point of view video is played by a [PovSession].
class BeamngConnection implements RemoteLink {
  final _states = StreamController<LinkState>.broadcast();
  final NativeChannel _native;
  final ModChannel _mod;
  final PovSession _pov;
  final Future<List<String>> Function() _broadcastTargets;
  final Future<String> Function() _deviceName;
  final Future<String?> Function() _appVersion;
  late final StreamSubscription<bool> _modActivity;

  /// [povPlayer]: the point of view video player (the phone's hardware
  /// decoder by default). The other parameters replace the network and the
  /// platform in tests.
  BeamngConnection({
    PovPlayer? povPlayer,
    UdpBinder bind = IoUdpEndpoint.bind,
    Future<List<String>> Function() findBroadcastTargets = broadcastTargets,
    Future<String> Function() deviceName = resolveDeviceName,
    Future<String?> Function() appVersion = resolveAppVersion,
    DateTime Function()? now,
  })  : _native = NativeChannel(bind),
        _mod = ModChannel(bind, now: now),
        _pov = PovSession(povPlayer ?? NativePovPlayer()),
        _broadcastTargets = findBroadcastTargets,
        _deviceName = deviceName,
        _appVersion = appVersion {
    _mod.onKicked = () => unawaited(_onKicked());
    _modActivity = _mod.activeChanges.listen((_) => _restartControlTimer());
  }

  LinkState _state = LinkState.idle;

  /// Second-screen phone: telemetry only, no inputs sent to the game.
  bool _display = false;
  String? _resolvedAppVersion;
  InternetAddress? _host;
  Timer? _controlTimer;

  double _steering = 0.5;
  double _throttle = 0;
  double _brake = 0;

  @override
  Stream<LinkState> get states => _states.stream;
  @override
  LinkState get state => _state;
  @override
  Stream<bool> get modActiveChanges => _mod.activeChanges;
  @override
  bool get modActive => _mod.active;
  @override
  int get protocolVersion => _mod.protocolVersion;
  @override
  Stream<Telemetry> get telemetry => _mod.telemetry;
  @override
  Stream<ModMessage> get events => _mod.events;
  @override
  int? get latencyMs => _mod.latencyMs;
  @override
  bool get signalLost => _mod.signalLost;
  @override
  Stream<void> get qualityChanges => _mod.qualityChanges;
  @override
  Stream<PovPicture> get povPictures => _pov.pictures;

  void _setState(LinkState s) {
    _state = s;
    if (!_states.isClosed) _states.add(s);
  }

  /// Pairs with the game. [knownHost] (from automatic discovery) is tried
  /// first, broadcasts cover the manual-code / QR cases. With [display]
  /// the phone is a second screen: it only talks to the mod (the native
  /// handshake would create a game controller) and never sends inputs.
  Future<void> connect(String code, {String? knownHost, bool display = false}) async {
    await disconnect();
    _display = display;
    _setState(LinkState.connecting);

    final deviceName = await _deviceName();
    _resolvedAppVersion ??= await _appVersion();
    final identity = ModIdentity(code: code, deviceName: deviceName, display: display, appVersion: _resolvedAppVersion);
    final targets = [if (knownHost != null) knownHost, ...await _broadcastTargets()];
    DebugLog.log('connect: targets=$targets device=$deviceName display=$display');

    try {
      _host = display ? await _mod.find(identity, targets) : await _native.pair(code, deviceName, targets);
    } on TimeoutException {
      DebugLog.log('connect: no answer from $targets');
      _setState(LinkState.timeout);
      rethrow;
    }
    _restartControlTimer();
    _setState(LinkState.connected);
    if (!display) unawaited(_mod.open(_host!, identity));
  }

  Future<void> _onKicked() async {
    await disconnect();
    _setState(LinkState.kicked);
  }

  /// Asks the mod for success acknowledgements too (debug overlay).
  void setDebugAcks(bool enabled) {
    _mod.debugAcks = enabled;
    if (_mod.active) sendCommand(ModCommand.debug, enabled ? '1' : '0');
  }

  @override
  void sendCommand(String name, [String? arg]) => _mod.sendCommand(name, arg);

  @override
  void setPovVideo(PovFormat? format) {
    if (format == null) {
      sendCommand(ModCommand.pov, '0');
      _pov.stop();
      return;
    }
    final host = _host;
    if (host != null) _pov.play(host, format);
    sendCommand(ModCommand.pov, format.wire);
  }

  @override
  void updateControls({double? steering, double? throttle, double? brake}) {
    if (steering != null) _steering = steering.clamp(0.0, 1.0);
    if (throttle != null) _throttle = throttle.clamp(0.0, 1.0);
    if (brake != null) _brake = brake.clamp(0.0, 1.0);
  }

  // The mod's channel at 60 Hz while it answers, the native one at 20 Hz
  // otherwise. A second screen never drives.
  void _restartControlTimer() {
    _controlTimer?.cancel();
    _controlTimer = null;
    if (_display || _host == null) return;
    final interval = _mod.active ? ModProtocol.controlIntervalMs : NativeProtocol.controlIntervalMs;
    _controlTimer = Timer.periodic(Duration(milliseconds: interval), (_) => _sendControls());
  }

  void _sendControls() {
    if (_mod.active) {
      _mod.sendControls(ModControlPacket(steering: _steering, throttle: _throttle, brake: _brake));
    } else {
      _native.sendControls(steering: _steering, throttle: _throttle, brake: _brake);
    }
  }

  @override
  Future<void> disconnect() async {
    // Leaving on purpose: the mod brakes the car instead of letting it run
    // on the last throttle until the phone times out.
    if (_mod.active) sendCommand(ModCommand.leave);
    _controlTimer?.cancel();
    _controlTimer = null;
    _mod.close();
    _native.close();
    _pov.stop();
    _host = null;
    if (_state != LinkState.idle) _setState(LinkState.idle);
  }

  @override
  void dispose() {
    unawaited(disconnect());
    unawaited(_modActivity.cancel());
    _mod.dispose();
    _pov.dispose();
    _states.close();
  }
}
