/// Which pedal a touch belongs to, and how hard it is pressed. Pure logic,
/// unit-tested (test/features/driving/pedal_mapping_test.dart).
enum Pedal { brake, throttle }

class PedalMapping {
  /// Fraction of the screen width given to each pedal from its edge.
  final double zoneFraction;

  /// Top part of a zone that always means 100% (easy full throttle).
  final double topDeadZone;

  /// Bottom part of a zone that always means 0% (resting thumb).
  /// With the defaults the pedal travel uses 80% of the screen height.
  final double bottomDeadZone;

  const PedalMapping({this.zoneFraction = 0.4, this.topDeadZone = 0.15, this.bottomDeadZone = 0.05});

  /// Tilt steering: 40% of the width on each side, the middle 20% is free.
  static const wide = PedalMapping();

  /// Touch steering: narrower strips leave room for the steering bar.
  static const sides = PedalMapping(zoneFraction: 0.32);

  Pedal? pedalAt(double x, double width) {
    if (width <= 0) return null;
    if (x < width * zoneFraction) return Pedal.brake;
    if (x >= width * (1 - zoneFraction)) return Pedal.throttle;
    return null;
  }

  /// 0..1 from the vertical position (top = 1).
  double valueAt(double y, double height) {
    if (height <= 0) return 0;
    final top = height * topDeadZone;
    final bottom = height * (1 - bottomDeadZone);
    if (y <= top) return 1;
    if (y >= bottom) return 0;
    return ((bottom - y) / (bottom - top)).clamp(0.0, 1.0);
  }
}
