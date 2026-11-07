import 'package:beam_remoteplus/core/protocol/telemetry_frames.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late TelemetryFrames frames;
  setUp(() => frames = TelemetryFrames());

  test('a full frame stands for itself', () {
    final full = {'type': 'telemetry', 'rpm': 3000, 'maxRpm': 7000};
    expect(frames.accept(full), full);
  });

  test('a delta updates the last frame, null removing a field', () {
    frames.accept({'type': 'telemetry', 'rpm': 3000, 'maxRpm': 7000, 'tyres': 1});
    expect(frames.accept({'delta': true, 'rpm': 3100, 'tyres': null}), {'type': 'telemetry', 'rpm': 3100, 'maxRpm': 7000});
    expect(frames.accept({'delta': true, 'speed': 20}), {'type': 'telemetry', 'rpm': 3100, 'maxRpm': 7000, 'speed': 20});
  });

  test('a full frame replaces everything, fields it lacks included', () {
    frames.accept({'type': 'telemetry', 'rpm': 3000, 'radar': <Object?>[]});
    expect(frames.accept({'type': 'telemetry', 'rpm': 900}), {'type': 'telemetry', 'rpm': 900});
  });

  test('a delta before any full frame is dropped, and after a reset', () {
    expect(frames.accept({'delta': true, 'rpm': 3100}), isNull);
    frames
      ..accept({'type': 'telemetry', 'rpm': 3000})
      ..reset();
    expect(frames.accept({'delta': true, 'rpm': 3100}), isNull);
  });
}
