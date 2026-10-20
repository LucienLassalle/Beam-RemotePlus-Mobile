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

  /// Both pedals side by side on the right (brake inside, throttle at the
  /// edge), for the right thumb, when the left one turns the wheel.
  final bool bothRight;

  const PedalMapping({this.zoneFraction = 0.4, this.topDeadZone = 0.15, this.bottomDeadZone = 0.05, this.bothRight = false});

  /// Tilt steering: 40% of the width on each side, the middle 20% is free.
  static const wide = PedalMapping();

  /// Touch steering: narrower strips leave room for the steering bar.
  static const sides = PedalMapping(zoneFraction: 0.32);

  /// Thumb wheel on the left: brake and throttle under the right thumb.
  static const rightThumb = PedalMapping(zoneFraction: 0.2, bothRight: true);

  /// Over the driver's view video: 25% on each side, the middle half turns
  /// the camera (see LookZone).
  static const video = PedalMapping(zoneFraction: 0.25);

  /// Horizontal span no pedal takes, in fractions of the width.
  (double, double) get freeSpan => bothRight ? (0, 1 - 2 * zoneFraction) : (zoneFraction, 1 - zoneFraction);

  /// Horizontal span of a pedal zone, in fractions of the width.
  (double, double) spanOf(Pedal pedal) => switch ((pedal, bothRight)) {
        (Pedal.brake, false) => (0, zoneFraction),
        (Pedal.brake, true) => (1 - 2 * zoneFraction, 1 - zoneFraction),
        (Pedal.throttle, _) => (1 - zoneFraction, 1),
      };

  Pedal? pedalAt(double x, double width) {
    if (width <= 0) return null;
    for (final pedal in Pedal.values) {
      final (from, to) = spanOf(pedal);
      if (x >= width * from && (x < width * to || to == 1)) return pedal;
    }
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
