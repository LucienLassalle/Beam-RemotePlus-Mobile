import 'dart:async';
import 'dart:io';

import '../debug/debug_log.dart';
import '../platform/pov_video.dart';
import '../protocol/mod_protocol.dart';
import 'remote_link.dart';

/// The phone's side of the point of view video: runs the [PovPlayer] for the
/// format asked and tells what it shows ([pictures]).
class PovSession {
  final PovPlayer _player;
  final _pictures = StreamController<PovPicture>.broadcast();
  StreamSubscription<PovPlayerEvent>? _events;
  PovFormat? _format; // playing, or starting
  PovPicture? _picture;

  PovSession(this._player);

  Stream<PovPicture> get pictures => _pictures.stream;

  /// The format playing or starting, null while off.
  PovFormat? get format => _format;

  /// Plays the video of [host] in [format]; asking again for the format
  /// already playing changes nothing.
  void play(InternetAddress host, PovFormat format) {
    if (format == _format) return;
    stop();
    _format = format;
    unawaited(_start(host, format));
  }

  void stop() {
    if (_format == null) return;
    _format = null;
    _picture = null;
    unawaited(_player.stop());
  }

  Future<void> _start(InternetAddress host, PovFormat format) async {
    _events ??= _player.events.listen(_onEvent);
    try {
      final id = await _player.start(host: host.address, port: ModProtocol.povPort, width: format.width, height: format.height);
      // Switched off or changed while starting.
      if (_format != format) return;
      _setPicture(PovPicture(textureId: id, width: format.width, height: format.height));
    } catch (e) {
      DebugLog.log('pov: cannot start the player ($e)');
      if (_format == format) _setPicture(PovPicture(textureId: -1, width: 0, height: 0, error: '$e'));
    }
  }

  void _onEvent(PovPlayerEvent event) {
    final picture = _picture;
    if (picture == null || _format == null) return;
    _setPicture(switch (event) {
      PovPlayerSize(:final width, :final height) =>
        PovPicture(textureId: picture.textureId, width: width, height: height),
      PovPlayerError(:final message) =>
        PovPicture(textureId: picture.textureId, width: picture.width, height: picture.height, error: message),
    });
  }

  void _setPicture(PovPicture picture) {
    _picture = picture;
    if (!_pictures.isClosed) _pictures.add(picture);
  }

  void dispose() {
    stop();
    unawaited(_events?.cancel());
    _pictures.close();
  }
}
