import 'dart:async';

import 'package:beam_remoteplus/core/network/remote_link.dart';
import 'package:beam_remoteplus/core/protocol/mod_message.dart';
import 'package:beam_remoteplus/core/protocol/telemetry.dart';

export 'package:beam_remoteplus/themes/kit/sample_telemetry.dart';

/// In-memory [RemoteLink] recording what the app sends.
class FakeLink implements RemoteLink {
  final states_ = StreamController<LinkState>.broadcast();
  final modActive_ = StreamController<bool>.broadcast();
  final telemetry_ = StreamController<Telemetry>.broadcast();
  final events_ = StreamController<ModMessage>.broadcast();

  @override
  LinkState state = LinkState.connected;
  @override
  bool modActive;
  @override
  int protocolVersion;

  final List<String> commands = [];
  double steering = 0.5, throttle = 0, brake = 0;

  FakeLink({this.modActive = true, this.protocolVersion = 2});

  @override
  Stream<LinkState> get states => states_.stream;
  @override
  Stream<bool> get modActiveChanges => modActive_.stream;
  @override
  Stream<Telemetry> get telemetry => telemetry_.stream;
  @override
  Stream<ModMessage> get events => events_.stream;

  @override
  void sendCommand(String name, [String? arg]) => commands.add(arg == null ? name : '$name|$arg');

  @override
  void updateControls({double? steering, double? throttle, double? brake}) {
    if (steering != null) this.steering = steering;
    if (throttle != null) this.throttle = throttle;
    if (brake != null) this.brake = brake;
  }

  @override
  Future<void> disconnect() async {}

  @override
  void dispose() {
    states_.close();
    modActive_.close();
    telemetry_.close();
    events_.close();
  }
}
