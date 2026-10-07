import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../debug/debug_log.dart';
import '../platform/device_name.dart';
import '../protocol/mod_message.dart';
import '../protocol/mod_protocol.dart';
import '../protocol/native_protocol.dart';
import '../protocol/telemetry.dart';
import 'broadcast.dart';
import 'remote_link.dart';

/// Connection to BeamNG.drive.
///
/// 1. Native handshake (port 4444) with the pairing code: finds the PC and
///    gives steering + on/off pedals even without the mod.
/// 2. Mod probe (port 4446): once the mod answers, controls switch to its
///    analog channel at 60 Hz and telemetry/commands become available.
///
/// Sockets are always bound to anyIPv4: in hotspot mode some phones report
/// the mobile-data IP as "Wi-Fi IP", and binding to it would silently drop
/// every answer arriving on the real Wi-Fi interface.
class BeamngConnection implements RemoteLink {
  final _states = StreamController<LinkState>.broadcast();
  final _modActiveChanges = StreamController<bool>.broadcast();
  final _telemetry = StreamController<Telemetry>.broadcast();
  final _events = StreamController<ModMessage>.broadcast();

  LinkState _state = LinkState.idle;
  bool _modActive = false;
  int _protocolVersion = 0;
  bool debugAcks = false;

  RawDatagramSocket? _nativeSocket; // handshake answer
  RawDatagramSocket? _controlSocket; // native control packets
  RawDatagramSocket? _modSocket; // mod: pong, telemetry, events + sending
  Timer? _controlTimer;
  Timer? _modPingTimer;
  InternetAddress? _host;

  double _steering = 0.5;
  double _throttle = 0;
  double _brake = 0;
  int _sequence = 0;

  @override
  Stream<LinkState> get states => _states.stream;
  @override
  LinkState get state => _state;
  @override
  Stream<bool> get modActiveChanges => _modActiveChanges.stream;
  @override
  bool get modActive => _modActive;
  @override
  int get protocolVersion => _protocolVersion;
  @override
  Stream<Telemetry> get telemetry => _telemetry.stream;
  @override
  Stream<ModMessage> get events => _events.stream;

  void _setState(LinkState s) {
    _state = s;
    if (!_states.isClosed) _states.add(s);
  }

  /// Pairs with the game. [knownHost] (from automatic discovery) is tried
  /// first, broadcasts cover the manual-code / QR cases.
  Future<void> connect(String code, {String? knownHost}) async {
    await disconnect();
    _setState(LinkState.connecting);

    final deviceName = await resolveDeviceName();
    final targets = [if (knownHost != null) knownHost, ...await broadcastTargets()];
    DebugLog.log('connect: targets=$targets device=$deviceName');

    final InternetAddress host;
    try {
      host = await _nativeHandshake(code, deviceName, targets);
    } on TimeoutException {
      DebugLog.log('connect: no native answer from $targets');
      _setState(LinkState.timeout);
      rethrow;
    }
    _host = host;
    _controlSocket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
    _restartControlTimer();
    _setState(LinkState.connected);
    unawaited(_probeMod(code, deviceName));
  }

  Future<InternetAddress> _nativeHandshake(String code, String deviceName, List<String> targets) async {
    final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, NativeProtocol.clientPort, reuseAddress: true);
    socket.broadcastEnabled = true;
    _nativeSocket = socket;
    final expected = NativeProtocol.expectedAnswer(code);
    final answer = Completer<InternetAddress>();

    // A dart:io socket can only be listened to once: this single listener
    // handles the handshake answer, later datagrams are ignored.
    socket.listen((event) {
      if (event != RawSocketEvent.read) return;
      final dg = socket.receive();
      if (dg == null || answer.isCompleted) return;
      final msg = utf8.decode(dg.data, allowMalformed: true);
      DebugLog.log('handshake: "$msg" from ${dg.address.address}');
      if (msg == expected) answer.complete(dg.address);
    });

    final payload = utf8.encode(NativeProtocol.handshake(deviceName, code));
    var attempts = 0;
    final retry = Timer.periodic(const Duration(milliseconds: NativeProtocol.discoveryRetryMs), (t) {
      if (answer.isCompleted || ++attempts > NativeProtocol.discoveryMaxRetries) {
        t.cancel();
        return;
      }
      for (final target in targets) {
        try {
          socket.send(payload, InternetAddress(target), NativeProtocol.hostPort);
        } catch (e) {
          DebugLog.log('handshake: send to $target failed ($e)');
        }
      }
    });
    try {
      return await answer.future.timeout(
        const Duration(milliseconds: NativeProtocol.discoveryRetryMs * (NativeProtocol.discoveryMaxRetries + 2)),
      );
    } finally {
      retry.cancel();
    }
  }

  Future<void> _probeMod(String code, String deviceName) async {
    final host = _host;
    if (host == null) return;
    final RawDatagramSocket socket;
    try {
      socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, ModProtocol.clientPort, reuseAddress: true);
    } catch (e) {
      DebugLog.log('mod probe: cannot bind ${ModProtocol.clientPort} ($e)');
      return;
    }
    _modSocket = socket;

    socket.listen((event) {
      if (event != RawSocketEvent.read) return;
      final dg = socket.receive();
      if (dg != null) _onModDatagram(dg, code);
    });

    // Keeps probing: the mod may be enabled after the phone connected.
    final ping = utf8.encode(ModProtocol.ping(code, deviceName));
    socket.send(ping, host, ModProtocol.hostPort);
    _modPingTimer = Timer.periodic(
      const Duration(milliseconds: ModProtocol.pingRetryMs),
      (_) => socket.send(ping, host, ModProtocol.hostPort),
    );
  }

  void _onModDatagram(Datagram dg, String code) {
    if (!_modActive) {
      final version = ModProtocol.parsePong(utf8.decode(dg.data, allowMalformed: true), code);
      if (version == null) return;
      _modPingTimer?.cancel();
      _modPingTimer = null;
      _protocolVersion = version;
      _modActive = true;
      DebugLog.log('mod detected, protocol v$version');
      if (!_modActiveChanges.isClosed) _modActiveChanges.add(true);
      _restartControlTimer();
      if (debugAcks) sendCommand(ModCommand.debug, '1');
      return;
    }
    try {
      final message = ModMessage.decode(dg.data, _protocolVersion);
      if (message is TelemetryMessage) {
        if (!_telemetry.isClosed) _telemetry.add(message.telemetry);
      } else if (message != null) {
        if (!_events.isClosed) _events.add(message);
      }
    } catch (e) {
      // One malformed frame must never break the dashboard.
      DebugLog.log('mod datagram dropped ($e)');
    }
  }

  /// Asks the mod for success acknowledgements too (debug overlay).
  void setDebugAcks(bool enabled) {
    debugAcks = enabled;
    if (_modActive) sendCommand(ModCommand.debug, enabled ? '1' : '0');
  }

  @override
  void sendCommand(String name, [String? arg]) {
    final socket = _modSocket;
    final host = _host;
    if (socket == null || host == null || !_modActive) return;
    socket.send(utf8.encode(ModProtocol.command(name, arg)), host, ModProtocol.hostPort);
  }

  @override
  void updateControls({double? steering, double? throttle, double? brake}) {
    if (steering != null) _steering = steering.clamp(0.0, 1.0);
    if (throttle != null) _throttle = throttle.clamp(0.0, 1.0);
    if (brake != null) _brake = brake.clamp(0.0, 1.0);
  }

  void _restartControlTimer() {
    _controlTimer?.cancel();
    final interval = _modActive ? ModProtocol.controlIntervalMs : NativeProtocol.controlIntervalMs;
    _controlTimer = Timer.periodic(Duration(milliseconds: interval), (_) => _sendControls());
  }

  void _sendControls() {
    final host = _host;
    if (host == null) return;
    if (_modActive) {
      final packet = ModControlPacket(steering: _steering, throttle: _throttle, brake: _brake);
      _modSocket?.send(packet.toBytes(), host, ModProtocol.hostPort);
      return;
    }
    final packet = NativeControlPacket(steering: _steering, throttle: _throttle, brake: _brake, sequenceId: _sequence);
    _sequence = (_sequence + 1) % 128;
    _controlSocket?.send(packet.toBytes(), host, NativeProtocol.hostPort);
  }

  @override
  Future<void> disconnect() async {
    _controlTimer?.cancel();
    _modPingTimer?.cancel();
    _controlTimer = _modPingTimer = null;
    _nativeSocket?.close();
    _controlSocket?.close();
    _modSocket?.close();
    _nativeSocket = _controlSocket = _modSocket = null;
    _host = null;
    _modActive = false;
    _protocolVersion = 0;
    if (_state != LinkState.idle) _setState(LinkState.idle);
  }

  @override
  void dispose() {
    unawaited(disconnect());
    _states.close();
    _modActiveChanges.close();
    _telemetry.close();
    _events.close();
  }
}
