import CoreMotion
import Flutter
import UIKit

/// iOS side of the platform channels of MainActivity.kt (UNTESTED: no iPhone
/// available to the maintainer). Implemented:
///  - sensors / gravity: gravity from CoreMotion's device motion (gyroscope
///    fused with the accelerometer), for tilt steering
///  - vibrator: haptic taps whose strength follows the amplitude
/// Not available on iOS, so the Dart side falls back (MissingPluginException):
///  - hardware_keys: iOS has no API to capture the volume buttons
///  - gesture_exclusion, network_info (hotspot / USB tethering interfaces)
///  - pov_video: the driver's view video player (Android MediaCodec)
@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private let motion = CMMotionManager()

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    guard let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "BeamRemotePlusChannels") else { return }
    let messenger = registrar.messenger()

    FlutterMethodChannel(name: "com.beamremoteplus.app/sensors", binaryMessenger: messenger)
      .setMethodCallHandler { [weak self] call, result in
        guard call.method == "hasGameRotationVector" else { return result(FlutterMethodNotImplemented) }
        result(self?.motion.isDeviceMotionAvailable ?? false)
      }
    FlutterEventChannel(name: "com.beamremoteplus.app/gravity", binaryMessenger: messenger)
      .setStreamHandler(GravityStream(motion: motion))

    FlutterMethodChannel(name: "com.beamremoteplus.app/vibrator", binaryMessenger: messenger)
      .setMethodCallHandler { call, result in
        guard call.method == "vibrate" else { return result(FlutterMethodNotImplemented) }
        let args = call.arguments as? [String: Any]
        let amplitude = (args?["amplitude"] as? NSNumber)?.intValue ?? 255
        let intensity = CGFloat(min(max(amplitude, 1), 255)) / 255
        let style: UIImpactFeedbackGenerator.FeedbackStyle = intensity > 0.66 ? .heavy : (intensity > 0.33 ? .medium : .light)
        UIImpactFeedbackGenerator(style: style).impactOccurred(intensity: intensity)
        result(nil)
      }
  }
}

/// Gravity in the phone frame with Android's conventions (m/s², +z when the
/// screen faces up), like the accelerometer events of sensors_plus.
private class GravityStream: NSObject, FlutterStreamHandler {
  private let motion: CMMotionManager

  init(motion: CMMotionManager) {
    self.motion = motion
  }

  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    guard motion.isDeviceMotionAvailable else {
      return FlutterError(code: "unavailable", message: "no device motion", details: nil)
    }
    let g = 9.80665
    motion.deviceMotionUpdateInterval = 1.0 / 50
    // CoreMotion's gravity points down in g units: the opposite sign of
    // Android's (which reads +g on z when the phone lies screen up).
    motion.startDeviceMotionUpdates(to: .main) { data, _ in
      guard let gravity = data?.gravity else { return }
      events([-gravity.x * g, -gravity.y * g, -gravity.z * g])
    }
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    motion.stopDeviceMotionUpdates()
    return nil
  }
}
