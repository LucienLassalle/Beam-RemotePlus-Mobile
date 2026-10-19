import 'dart:async';

import 'package:flutter/services.dart';

/// What the player tells about the point of view video.
sealed class PovPlayerEvent {
  const PovPlayerEvent();
}

/// Size of the decoded picture, known once the decoder started.
class PovPlayerSize extends PovPlayerEvent {
  final int width;
  final int height;
  const PovPlayerSize(this.width, this.height);
}

/// The phone's decoder failed (it tries again on the next keyframe).
class PovPlayerError extends PovPlayerEvent {
  final String message;
  const PovPlayerError(this.message);
}

/// Player of the mod's point of view video (H.264 in MPEG-TS over UDP),
/// drawing into a Flutter texture.
abstract class PovPlayer {
  /// Listens on [port] for the video of [host]; returns the texture to show.
  /// [width] x [height]: the expected picture.
  Future<int> start({required String host, required int port, required int width, required int height});

  Future<void> stop();

  Stream<PovPlayerEvent> get events;
}

/// The phone's hardware decoder (MediaCodec, see PovVideoPlayer.kt).
class NativePovPlayer implements PovPlayer {
  static const _channel = MethodChannel('com.beamremoteplus.app/pov_video');
  static const _events = EventChannel('com.beamremoteplus.app/pov_video_events');

  late final Stream<PovPlayerEvent> _stream = _events.receiveBroadcastStream().map((event) {
    final map = event is Map ? event : const {};
    return switch (map['type']) {
      'size' => PovPlayerSize((map['width'] as num?)?.toInt() ?? 0, (map['height'] as num?)?.toInt() ?? 0),
      _ => PovPlayerError('${map['message'] ?? event}'),
    };
  });

  @override
  Stream<PovPlayerEvent> get events => _stream;

  @override
  Future<int> start({required String host, required int port, required int width, required int height}) async {
    final id = await _channel.invokeMethod<int>('start', {'host': host, 'port': port, 'width': width, 'height': height});
    if (id == null) throw PlatformException(code: 'pov_error', message: 'no texture');
    return id;
  }

  @override
  Future<void> stop() async {
    try {
      await _channel.invokeMethod<void>('stop');
    } on MissingPluginException {
      // Tests / unsupported platform.
    }
  }
}
