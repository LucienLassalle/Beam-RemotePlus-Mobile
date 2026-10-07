import 'dart:async';

import 'package:beam_remoteplus/core/network/remote_link.dart';
import 'package:beam_remoteplus/core/protocol/mod_message.dart';
import 'package:beam_remoteplus/core/protocol/telemetry.dart';

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

/// A plausible mid-corner telemetry frame used by widget tests and previews.
const sampleTelemetry = Telemetry(
  speed: 41.7,
  rpm: 6900,
  maxRpm: 7800,
  gear: '4',
  gearIndex: 4,
  maxGearIndex: 6,
  fuel: 0.62,
  fuelVolume: 31.4,
  waterTemp: 92,
  oilTemp: 104,
  envTemp: 21,
  boost: 2.4,
  engineRunning: true,
  ignitionLevel: 2,
  lowBeam: true,
  highBeam: false,
  signalLeft: true,
  parkingBrake: false,
  hasAbs: true,
  absActive: false,
  hasEsc: true,
  escActive: true,
  hasTcs: true,
  tcsActive: false,
  odometer: 48213000,
  shiftLight: false,
  driveMode: 'Sport',
  tirePressures: {'FL': 210, 'FR': 212, 'RL': 205, 'RR': 95},
  radar: [
    RadarTarget(x: -3.5, y: 6, heading: 0),
    RadarTarget(x: 3.4, y: -12, heading: 180, length: 5.2),
    RadarTarget(x: 0.5, y: 18, heading: 10, length: 12, width: 2.5),
  ],
  bodyDamage: {'FL': 0.35, 'ML': 0.08},
  engineDamage: ['radiatorLeak'],
  tyres: {
    'FL': TyreState(temp: 92, working: 85, condition: 96),
    'FR': TyreState(temp: 84, working: 85, condition: 97),
    'RL': TyreState(temp: 62, working: 85, condition: 98),
    'RR': TyreState(temp: 118, working: 85, condition: 91),
  },
  receivedFields: {'speed', 'rpm'},
);
