import 'dart:async';
import 'dart:io';

import 'package:beam_remoteplus/core/network/pov_session.dart';
import 'package:beam_remoteplus/core/network/remote_link.dart';
import 'package:beam_remoteplus/core/platform/pov_video.dart';
import 'package:beam_remoteplus/core/protocol/mod_protocol.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_pov_player.dart';

void main() {
  final pc = InternetAddress('192.168.1.20');
  const hd = PovFormat(PovQuality.hd60, 1424, 640);
  const fullHd = PovFormat(PovQuality.fullHd60, 1920, 864);
  late FakePovPlayer player;
  late PovSession session;
  late List<PovPicture> pictures;

  setUp(() {
    player = FakePovPlayer();
    session = PovSession(player);
    pictures = [];
    session.pictures.listen(pictures.add);
  });

  tearDown(() {
    session.dispose();
    player.dispose();
  });

  test('plays the video of the PC at the size asked, then shows its texture', () async {
    session.play(pc, hd);
    expect(player.calls, ['start 192.168.1.20:${ModProtocol.povPort} 1424x640']);
    player.starting.complete(7);
    await pumpEventQueue();
    expect(pictures.single.textureId, 7);
    expect((pictures.single.width, pictures.single.height), (1424, 640));
  });

  test('asking again for the format playing does not restart the player', () {
    session
      ..play(pc, hd)
      ..play(pc, hd);
    expect(player.calls, hasLength(1));
  });

  test('another format restarts the player', () {
    session.play(pc, hd);
    player.starting = Completer<int>();
    session.play(pc, fullHd);
    expect(player.calls, ['start 192.168.1.20:4448 1424x640', 'stop', 'start 192.168.1.20:4448 1920x864']);
    expect(session.format, fullHd);
  });

  test('switched off while starting: nothing is shown', () async {
    session
      ..play(pc, hd)
      ..stop();
    player.starting.complete(7);
    await pumpEventQueue();
    expect(pictures, isEmpty);
    expect(session.format, isNull);
  });

  test('follows the size the decoder finds, and tells its failures', () async {
    session.play(pc, hd);
    player.starting.complete(7);
    await pumpEventQueue();
    player.events_.add(const PovPlayerSize(1280, 576));
    player.events_.add(const PovPlayerError('decoder lost'));
    await pumpEventQueue();
    expect(pictures[1].width, 1280);
    expect(pictures[2].textureId, 7);
    expect(pictures[2].width, 1280);
    expect(pictures[2].error, 'decoder lost');
  });

  test('a player that cannot start tells why', () async {
    session.play(pc, hd);
    player.starting.completeError(StateError('no decoder'));
    await pumpEventQueue();
    expect(pictures.single.textureId, -1);
    expect(pictures.single.error, contains('no decoder'));
  });

  test('ignores the player once stopped', () async {
    session.play(pc, hd);
    player.starting.complete(7);
    await pumpEventQueue();
    session.stop();
    player.events_.add(const PovPlayerSize(1280, 576));
    await pumpEventQueue();
    expect(pictures, hasLength(1));
  });
}
