import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:network_info_plus/network_info_plus.dart';

import 'control_packet.dart';
import 'mod_packets.dart';
import 'protocol_constants.dart';
import 'telemetry_packet.dart';

enum BeamngConnectionState { idle, discovering, connected, timeout, error }

/// Client du contrôleur BeamNG.drive.
///
/// Le canal de direction/accélération/freinage parle directement au
/// protocole natif "Application de contrôle à distance" intégré au jeu
/// (aucun mod requis). Si le mod optionnel Beam-RemotePlus est détecté sur
/// le PC, l'app bascule automatiquement sur son canal pour bénéficier de
/// pédales analogiques et d'une télémétrie riche ; sinon elle reste sur le
/// strict minimum natif (direction + accélération/freinage tout-ou-rien,
/// pas de télémétrie).
class BeamngClient {
  final _telemetryController = StreamController<TelemetryPacket>.broadcast();
  final _modTelemetryController =
      StreamController<ModTelemetryPacket>.broadcast();
  final _stateController =
      StreamController<BeamngConnectionState>.broadcast();
  final _latencyController = StreamController<Duration>.broadcast();
  final _modActiveController = StreamController<bool>.broadcast();

  /// Télémétrie native (généralement vide, voir docs/protocole : le canal
  /// natif appelle une fonction dépréciée côté jeu et n'envoie jamais rien
  /// dans les versions actuelles). Conservé pour compatibilité si BeamNG le
  /// répare un jour.
  Stream<TelemetryPacket> get telemetryStream => _telemetryController.stream;

  /// Télémétrie riche fournie par le mod optionnel, seule source fiable
  /// aujourd'hui. Vide tant que [modActive] est false.
  Stream<ModTelemetryPacket> get modTelemetryStream =>
      _modTelemetryController.stream;

  Stream<BeamngConnectionState> get stateStream => _stateController.stream;
  Stream<Duration> get latencyStream => _latencyController.stream;

  /// Émet true dès que le mod optionnel est détecté actif sur le PC.
  Stream<bool> get modActiveStream => _modActiveController.stream;

  BeamngConnectionState _state = BeamngConnectionState.idle;
  BeamngConnectionState get state => _state;

  bool _modActive = false;
  bool get modActive => _modActive;

  RawDatagramSocket? _sharedSocket; // handshake response + télémétrie native
  RawDatagramSocket? _controlSocket; // envoi des paquets de contrôle natifs
  RawDatagramSocket? _modSocket; // pong + télémétrie + envoi contrôle mod
  Timer? _controlTimer;
  Timer? _modPingTimer;
  InternetAddress? _hostAddress;

  double _steering = 0.5;
  double _throttle = 0;
  double _brake = 0;
  int _seq = 0;
  final Map<int, DateTime> _sentAt = {};

  int controlIntervalMs = BeamngProtocol.defaultControlIntervalMs;

  void _setState(BeamngConnectionState s) {
    _state = s;
    _stateController.add(s);
  }

  void _startControlTimer() {
    _controlTimer?.cancel();
    final interval = _modActive
        ? ModProtocol.controlIntervalMs
        : controlIntervalMs;
    _controlTimer = Timer.periodic(
      Duration(milliseconds: interval),
      (_) => _sendControlPacket(),
    );
  }

  /// Lance la découverte + le handshake natif avec le code lu sur le QR
  /// code, démarre l'envoi de contrôle, puis sonde discrètement la
  /// présence du mod optionnel.
  Future<void> connect(String securityCode) async {
    await disconnect();
    _setState(BeamngConnectionState.discovering);

    final info = NetworkInfo();
    final myIp = await info.getWifiIP();
    final broadcastIp = await info.getWifiBroadcast();

    if (myIp == null || broadcastIp == null) {
      _setState(BeamngConnectionState.error);
      throw StateError(
        'Impossible de déterminer l\'adresse WiFi locale. '
        'Vérifiez que le téléphone est bien connecté en WiFi, '
        'sur le même réseau que le PC.',
      );
    }

    final deviceName = await _resolveDeviceName();
    final handshakeMessage =
        '${BeamngProtocol.handshakePrefix}|$deviceName|$securityCode';
    final expectedResponse =
        '${BeamngProtocol.handshakePrefix}|$securityCode';

    final socket = await RawDatagramSocket.bind(
      InternetAddress(myIp),
      BeamngProtocol.clientPort,
      reuseAddress: true,
    );
    socket.broadcastEnabled = true;
    _sharedSocket = socket;

    final sendSocket = await RawDatagramSocket.bind(
      InternetAddress.anyIPv4,
      0,
    );
    sendSocket.broadcastEnabled = true;

    // Un socket dart:io est un stream à écoute UNIQUE : listen() ne peut être
    // appelé qu'une seule fois sur toute sa durée de vie (un second appel,
    // même après cancel() du premier, lève "Bad state: Stream has already
    // been listened to."). On enregistre donc un seul listener pour toute la
    // session, qui bascule lui-même de la phase handshake à la phase
    // télémétrie une fois la connexion établie.
    final completer = Completer<InternetAddress>();
    socket.listen((event) {
      if (event != RawSocketEvent.read) return;
      final dg = socket.receive();
      if (dg == null) return;

      if (!completer.isCompleted) {
        final msg = utf8.decode(dg.data, allowMalformed: true);
        if (msg == expectedResponse) {
          completer.complete(dg.address);
        }
        return;
      }

      _onTelemetryDatagram(dg);
    });

    var attempts = 0;
    final sendTimer = Timer.periodic(
      Duration(milliseconds: BeamngProtocol.discoveryRetryTimeoutMs),
      (t) {
        attempts++;
        if (completer.isCompleted ||
            attempts > BeamngProtocol.discoveryMaxRetries) {
          t.cancel();
          return;
        }
        sendSocket.send(
          utf8.encode(handshakeMessage),
          InternetAddress(broadcastIp),
          BeamngProtocol.hostPort,
        );
      },
    );

    InternetAddress hostAddress;
    try {
      hostAddress = await completer.future.timeout(
        Duration(
          milliseconds:
              BeamngProtocol.discoveryRetryTimeoutMs *
                  (BeamngProtocol.discoveryMaxRetries + 2),
        ),
      );
    } on TimeoutException {
      sendTimer.cancel();
      sendSocket.close();
      socket.close();
      _sharedSocket = null;
      _setState(BeamngConnectionState.timeout);
      rethrow;
    } finally {
      sendTimer.cancel();
      sendSocket.close();
    }

    _hostAddress = hostAddress;

    // Le socket de handshake reste ouvert : le même listener (voir plus
    // haut) bascule automatiquement en mode télémétrie car `completer` est
    // maintenant complété.
    _controlSocket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);

    _startControlTimer();

    _setState(BeamngConnectionState.connected);

    unawaited(_probeMod(securityCode));
  }

  /// Sonde la présence du mod optionnel sur le PC déjà identifié par le
  /// handshake natif. Ne bloque jamais la connexion native : en cas
  /// d'absence, l'app continue simplement sans lui, mais garde une sonde
  /// périodique active en arrière-plan (le mod peut être activé après
  /// coup dans le gestionnaire de mods, ou un ping isolé peut se perdre).
  Future<void> _probeMod(String securityCode) async {
    final host = _hostAddress;
    if (host == null) return;

    final RawDatagramSocket modSocket;
    try {
      modSocket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        ModProtocol.clientPort,
        reuseAddress: true,
      );
    } catch (_) {
      // Port déjà pris (ex: reconnexion rapide) : on abandonne la sonde
      // pour cette session plutôt que de planter la connexion native.
      return;
    }
    _modSocket = modSocket;

    final pongExpected = '${ModProtocol.pongPrefix}$securityCode|';

    modSocket.listen((event) {
      if (event != RawSocketEvent.read) return;
      final dg = modSocket.receive();
      if (dg == null) return;

      if (!_modActive) {
        final msg = utf8.decode(dg.data, allowMalformed: true);
        if (msg.startsWith(pongExpected)) {
          _modPingTimer?.cancel();
          _modPingTimer = null;
          _modActive = true;
          _modActiveController.add(true);
          _startControlTimer(); // passe à 16ms (~60Hz) pour le mod
        }
        return;
      }

      _onModTelemetryDatagram(dg);
    });

    final pingMessage = utf8.encode('${ModProtocol.pingPrefix}$securityCode');
    modSocket.send(pingMessage, host, ModProtocol.hostPort);
    _modPingTimer = Timer.periodic(
      const Duration(milliseconds: 500),
      (_) => modSocket.send(pingMessage, host, ModProtocol.hostPort),
    );
  }

  void _onTelemetryDatagram(Datagram dg) {
    try {
      final packet = TelemetryPacket.fromBytes(dg.data);
      final sentAt = _sentAt.remove(packet.id);
      if (sentAt != null) {
        _latencyController.add(DateTime.now().difference(sentAt));
      }
      _telemetryController.add(packet);
    } on FormatException {
      // paquet non conforme, ignoré (ex: bruit réseau)
    }
  }

  void _onModTelemetryDatagram(Datagram dg) {
    if (!_modActive) {
      _modActive = true;
      _modActiveController.add(true);
    }
    try {
      _modTelemetryController.add(ModTelemetryPacket.fromBytes(dg.data));
    } on FormatException {
      // paquet non conforme, ignoré
    }
  }

  /// Envoie une commande textuelle au mod (ex: changement de véhicule).
  /// Sans effet si le mod n'est pas actif ou la connexion absente.
  void sendCommand(String command) {
    final sock = _modSocket;
    final host = _hostAddress;
    if (sock == null || host == null || !_modActive) return;
    sock.send(utf8.encode(command), host, ModProtocol.hostPort);
  }

  /// Met à jour les commandes envoyées au prochain tick. À appeler depuis
  /// l'UI (volant, pédales) aussi souvent que nécessaire ; l'envoi réel est
  /// cadencé par [controlIntervalMs] (natif) ou [ModProtocol.controlIntervalMs]
  /// (mod, plus rapide).
  void updateControls({double? steering, double? throttle, double? brake}) {
    if (steering != null) _steering = steering.clamp(0.0, 1.0);
    if (throttle != null) _throttle = throttle.clamp(0.0, 1.0);
    if (brake != null) _brake = brake.clamp(0.0, 1.0);
  }

  void _sendControlPacket() {
    final host = _hostAddress;
    if (host == null) return;

    if (_modActive) {
      final modSocket = _modSocket;
      if (modSocket == null) return;
      final packet = ModControlPacket(
        steering: _steering,
        throttle: _throttle,
        brake: _brake,
      );
      modSocket.send(packet.toBytes(), host, ModProtocol.hostPort);
      return;
    }

    final controlSocket = _controlSocket;
    if (controlSocket == null) return;

    final seq = _seq;
    _seq = (_seq + 1) % 128;
    _sentAt[seq] = DateTime.now();
    if (_sentAt.length > 128) {
      _sentAt.remove(_sentAt.keys.first);
    }

    final packet = ControlPacket(
      steering: _steering,
      throttle: _throttle,
      brake: _brake,
      sequenceId: seq,
    );
    controlSocket.send(packet.toBytes(), host, BeamngProtocol.hostPort);
  }

  Future<String> _resolveDeviceName() async {
    try {
      final androidInfo = await DeviceInfoPlugin().androidInfo;
      final manufacturer = _capitalize(androidInfo.manufacturer);
      final model = androidInfo.model;
      if (model.toLowerCase().startsWith(
        androidInfo.manufacturer.toLowerCase(),
      )) {
        return _capitalize(model);
      }
      return '$manufacturer $model';
    } catch (_) {
      return 'BeamNG RemotePlus';
    }
  }

  String _capitalize(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1);
  }

  Future<void> disconnect() async {
    _controlTimer?.cancel();
    _controlTimer = null;
    _controlSocket?.close();
    _controlSocket = null;
    _sharedSocket?.close();
    _sharedSocket = null;
    _modSocket?.close();
    _modSocket = null;
    _modPingTimer?.cancel();
    _modPingTimer = null;
    _hostAddress = null;
    _modActive = false;
    _sentAt.clear();
    if (_state != BeamngConnectionState.idle) {
      _setState(BeamngConnectionState.idle);
    }
  }

  void dispose() {
    disconnect();
    _telemetryController.close();
    _modTelemetryController.close();
    _stateController.close();
    _latencyController.close();
    _modActiveController.close();
  }
}
