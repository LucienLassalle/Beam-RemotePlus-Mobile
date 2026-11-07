import 'dart:async';

import 'package:beam_remoteplus/core/platform/pov_video.dart';

/// A point of view video player whose start the test finishes (or fails)
/// when it wants, recording what it was asked.
class FakePovPlayer implements PovPlayer {
  final events_ = StreamController<PovPlayerEvent>.broadcast();
  final List<String> calls = [];
  Completer<int> starting = Completer<int>();

  @override
  Stream<PovPlayerEvent> get events => events_.stream;

  @override
  Future<int> start({required String host, required int port, required int width, required int height}) {
    calls.add('start $host:$port ${width}x$height');
    return starting.future;
  }

  @override
  Future<void> stop() async => calls.add('stop');

  void dispose() => events_.close();
}
