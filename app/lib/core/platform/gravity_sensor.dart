import 'package:flutter/services.dart';
import 'package:sensors_plus/sensors_plus.dart';

/// Gravity seen by the phone, computed from the gyroscope fused with the
/// accelerometer (Android game rotation vector, see MainActivity): the same
/// axes as the accelerometer, without the shakes of the hands and with less
/// smoothing needed, so tilt steering reacts faster.
class GravitySensor {
  GravitySensor._();

  static const _methods = MethodChannel('com.beamremoteplus.app/sensors');
  static const _events = EventChannel('com.beamremoteplus.app/gravity');

  /// Whether the phone has the gyroscope this needs.
  static Future<bool> available() async {
    try {
      return await _methods.invokeMethod<bool>('hasGameRotationVector') ?? false;
    } on MissingPluginException {
      return false; // tests / unsupported platform
    } on PlatformException {
      return false;
    }
  }

  /// Samples as accelerometer events, so tilt steering takes either source.
  static Stream<AccelerometerEvent> samples() => _events.receiveBroadcastStream().map((event) {
        final v = event as List<Object?>;
        double axis(int i) => (v[i] as num).toDouble();
        return AccelerometerEvent(axis(0), axis(1), axis(2), DateTime.now());
      });
}
