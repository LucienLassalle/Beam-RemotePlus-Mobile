import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../debug/debug_log.dart';
import '../protocol/mod_message.dart';
import '../protocol/mod_protocol.dart';
import '../protocol/native_protocol.dart';
import '../protocol/telemetry.dart';
import '../protocol/telemetry_frames.dart';
import 'udp_endpoint.dart';

/// Who the phone is, as its pings tell the mod.
class ModIdentity {
  final String code;
  final String deviceName;

  /// Second-screen phone: telemetry only, no inputs.
  final bool display;

  /// Sent so the mod can tell whether the app and the mod match.
  final String? appVersion;

  const ModIdentity({required this.code, required this.deviceName, this.display = false, this.appVersion});
}

/// Channel to the Beam-RemotePlus mod (port 4446): keep-alive pings, the
/// analog controls at 60 Hz, commands, and what the mod sends back
/// (telemetry, events). Tells whether the mod answers ([active]) and how
/// well (latency, signal lost).
class ModChannel {
  final UdpBinder _bind;
  final DateTime Function() _now;

  final _activeChanges = StreamController<bool>.broadcast();
  final _telemetry = StreamController<Telemetry>.broadcast();
  final _events = StreamController<ModMessage>.broadcast();
  final _quality = StreamController<void>.broadcast();

  /// The game kicked this phone: the channel is closed, pings included,
  /// otherwise the keep-alive would pair the phone again at once.
  void Function()? onKicked;

  /// Asks the mod for success acknowledgements too (debug overlay).
  bool debugAcks = false;

  /// The mod answered from another address while searching (see [search]):
  /// the PC changed address, everything now goes there.
  void Function(InternetAddress host)? onHostChanged;

  UdpEndpoint? _endpoint;
  StreamSubscription<Datagram>? _datagrams;
  Timer? _pingTimer;
  InternetAddress? _host;
  ModIdentity? _identity;

  /// Also pinged while the mod does not answer (see [search]).
  List<InternetAddress> _searchTargets = const [];

  bool _active = false;
  int _protocolVersion = 0;
  DateTime? _lastMessage;

  // Link quality: round trip of the keep-alive pings, and whether the mod
  // went silent.
  DateTime? _pingSentAt;
  int? _latencyMs;
  bool _signalLost = false;

  /// Handshake prefixes the pings use: both until the mod answers (mods up
  /// to 0.0.3 only know the legacy one), then the one of its answer.
  List<String> _prefixes = ModProtocol.prefixes;

  final _frames = TelemetryFrames();

  ModChannel(this._bind, {DateTime Function()? now}) : _now = now ?? DateTime.now;

  Stream<bool> get activeChanges => _activeChanges.stream;

  /// The mod answers: controls, telemetry and commands go through it.
  bool get active => _active;

  /// Negotiated protocol version, 0 while the mod is not active.
  int get protocolVersion => _protocolVersion;
  Stream<Telemetry> get telemetry => _telemetry.stream;

  /// Acks, session messages... (everything but telemetry and kicks).
  Stream<ModMessage> get events => _events.stream;
  int? get latencyMs => _latencyMs;
  bool get signalLost => _signalLost;

  /// Fires when [latencyMs] or [signalLost] changes.
  Stream<void> get qualityChanges => _quality.stream;

  /// Second screen: pings every target until the mod of one of them answers
  /// (no native handshake: it would create a game controller), then keeps
  /// the session. Returns the PC address; throws a [TimeoutException].
  Future<InternetAddress> find(ModIdentity identity, List<String> targets,
      {Duration timeout = const Duration(seconds: 6)}) async {
    close();
    _identity = identity;
    final endpoint = await _bind(ModProtocol.clientPort);
    _endpoint = endpoint;
    final found = Completer<InternetAddress>();
    _datagrams = endpoint.datagrams.listen((dg) {
      if (found.isCompleted) return _onDatagram(dg);
      final answer = utf8.decode(dg.data, allowMalformed: true);
      if (ModProtocol.parsePong(answer, identity.code) == null) return;
      _keepPrefixOf(answer);
      found.complete(dg.address);
    });
    final retry = Timer.periodic(const Duration(milliseconds: NativeProtocol.discoveryRetryMs), (_) {
      final pings = _pings();
      for (final target in targets) {
        try {
          for (final ping in pings) {
            endpoint.send(ping, InternetAddress(target), ModProtocol.hostPort);
          }
        } catch (_) {}
      }
    });
    final InternetAddress host;
    try {
      host = await found.future.timeout(timeout);
    } finally {
      retry.cancel();
    }
    // The first pong is consumed above: the keep-alive pings make the mod
    // active with the next one.
    _host = host;
    _startPings();
    return host;
  }

  /// Controller: talks to the mod of [host] (found by the native handshake).
  /// The mod may be missing or enabled later: the pings never stop.
  Future<void> open(InternetAddress host, ModIdentity identity) async {
    close();
    _identity = identity;
    final UdpEndpoint endpoint;
    try {
      endpoint = await _bind(ModProtocol.clientPort);
    } catch (e) {
      DebugLog.log('mod probe: cannot bind ${ModProtocol.clientPort} ($e)');
      return;
    }
    _endpoint = endpoint;
    _host = host;
    _datagrams = endpoint.datagrams.listen(_onDatagram);
    _startPings();
  }

  /// Until the mod answers, also pings [targets] (broadcast addresses): a
  /// PC that changed address answers from the new one. Calling it again
  /// replaces the targets (the phone may have changed network).
  void search(List<String> targets) {
    if (_active) return;
    _searchTargets = [
      for (final t in targets)
        if (InternetAddress.tryParse(t) case final address?) address,
    ];
  }

  bool get searching => _searchTargets.isNotEmpty;

  List<List<int>> _pings() {
    final id = _identity!;
    return [
      for (final p in _prefixes)
        utf8.encode(ModProtocol.ping(id.code, id.deviceName,
            display: id.display, withPrefix: p, appVersion: id.appVersion, features: ModProtocol.features)),
    ];
  }

  /// Keeps the prefix of [answer] (a pong) for the next pings.
  void _keepPrefixOf(String answer) {
    final p = ModProtocol.prefixOf(answer);
    if (p != null) _prefixes = [p];
  }

  // Never stops pinging: fast while the mod is not found (it may be enabled
  // after the phone connected), slowly once paired so the session is
  // restored if the mod restarts (reload, switched off and on...).
  void _startPings() {
    _ping();
    var ticks = 0;
    _pingTimer = Timer.periodic(const Duration(milliseconds: ModProtocol.pingRetryMs), (_) {
      ticks++;
      final last = _lastMessage;
      final silence = last == null ? null : _now().difference(last);
      // Still lost once the app fell back to the native channel, until the
      // mod answers again.
      _setSignalLost(silence != null && silence > ModProtocol.signalLostAfter);
      if (_active && silence != null && silence > ModProtocol.modSilenceTimeout) {
        DebugLog.log('mod silent, back to the native channel until it answers again');
        _setActive(false);
      }
      if (!_active || ticks % ModProtocol.keepAlivePingEvery == 0) _ping();
    });
  }

  void _ping() {
    final endpoint = _endpoint;
    final host = _host;
    if (endpoint == null || host == null) return;
    if (_active) _pingSentAt = _now();
    final pings = _pings();
    for (final target in [host, if (!_active) ..._searchTargets]) {
      for (final p in pings) {
        endpoint.send(p, target, ModProtocol.hostPort);
      }
    }
  }

  void _onDatagram(Datagram dg) {
    // Pongs are plain text, every other v2 message is JSON.
    if (dg.data.isNotEmpty && dg.data.first != 0x7B /* { */ && dg.data.length != Telemetry.legacySizeBytes) {
      return _onPong(utf8.decode(dg.data, allowMalformed: true), dg.address);
    }
    if (!_active) return;
    _heard();
    try {
      final message = ModMessage.decode(dg.data, _protocolVersion, _frames);
      if (message is TelemetryMessage) {
        if (!_telemetry.isClosed) _telemetry.add(message.telemetry);
      } else if (message is KickedMessage) {
        DebugLog.log('kicked by the game');
        close();
        onKicked?.call();
      } else if (message != null) {
        if (!_events.isClosed) _events.add(message);
      }
    } catch (e) {
      // One malformed frame must never break the dashboard.
      DebugLog.log('mod datagram dropped ($e)');
    }
  }

  void _onPong(String answer, InternetAddress from) {
    final version = ModProtocol.parsePong(answer, _identity!.code);
    if (version == null) return;
    if (searching && from != _host) {
      DebugLog.log('mod answers from ${from.address}: the PC changed address');
      _host = from;
      onHostChanged?.call(from);
    }
    _heard();
    final sentAt = _pingSentAt;
    if (sentAt != null) {
      _pingSentAt = null;
      _latencyMs = _lastMessage!.difference(sentAt).inMilliseconds;
      _qualityChanged();
    }
    if (_active) return;
    _keepPrefixOf(answer);
    _protocolVersion = version;
    _searchTargets = const [];
    DebugLog.log('mod detected, protocol v$version');
    _setActive(true);
    if (debugAcks) sendCommand(ModCommand.debug, '1');
  }

  void _heard() {
    _lastMessage = _now();
    _setSignalLost(false);
  }

  void _setActive(bool active) {
    if (_active == active) return;
    _active = active;
    if (!active) {
      _protocolVersion = 0;
      _frames.reset();
      // The mod may come back updated or downgraded: probe both again.
      _prefixes = ModProtocol.prefixes;
    }
    if (!_activeChanges.isClosed) _activeChanges.add(active);
  }

  void _setSignalLost(bool lost) {
    if (_signalLost == lost) return;
    _signalLost = lost;
    DebugLog.log(lost ? 'signal lost' : 'signal back');
    _qualityChanged();
  }

  void _qualityChanged() {
    if (!_quality.isClosed) _quality.add(null);
  }

  /// Sends `cmd|name` or `cmd|name|arg` (ignored while the mod is not active).
  void sendCommand(String name, [String? arg]) {
    final endpoint = _endpoint;
    final host = _host;
    if (endpoint == null || host == null || !_active) return;
    endpoint.send(utf8.encode(ModProtocol.command(name, arg)), host, ModProtocol.hostPort);
  }

  void sendControls(ModControlPacket packet) {
    final endpoint = _endpoint;
    final host = _host;
    if (endpoint == null || host == null) return;
    endpoint.send(packet.toBytes(), host, ModProtocol.hostPort);
  }

  /// Stops talking to the mod and forgets the session.
  void close() {
    _pingTimer?.cancel();
    _pingTimer = null;
    unawaited(_datagrams?.cancel());
    _datagrams = null;
    _endpoint?.close();
    _endpoint = null;
    _host = null;
    _searchTargets = const [];
    _frames.reset();
    _active = false;
    _protocolVersion = 0;
    _prefixes = ModProtocol.prefixes;
    _lastMessage = null;
    _pingSentAt = null;
    _latencyMs = null;
    _signalLost = false;
  }

  void dispose() {
    close();
    _activeChanges.close();
    _telemetry.close();
    _events.close();
    _quality.close();
  }
}
