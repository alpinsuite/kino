import 'package:flutter_test/flutter_test.dart';
import 'package:kino/desktop/idle_inhibitor.dart';
import 'package:kino/desktop/mpris.dart';
import 'package:kino_core/kino_core.dart';
import 'package:kino_review/kino_review.dart';

import 'support/fake_playback_controller.dart';

// The D-Bus plumbing itself cannot run here — there is no session bus on a
// Windows development machine, and CI has no desktop. What *can* be tested is
// everything that decides what to say and when, which is where these go wrong
// in ways a user notices: a lock screen showing the previous file, or a screen
// that blanks halfway through.

class _RecordingInhibitor implements IdleInhibitor {
  final List<String> calls = <String>[];

  @override
  Future<void> inhibit(String reason) async => calls.add('inhibit($reason)');

  @override
  Future<void> release() async => calls.add('release()');

  @override
  Future<void> dispose() async => calls.add('dispose()');
}

PlaybackState _state(PlaybackStatus status, {MediaInfo? media}) =>
    PlaybackState(
      status: status,
      media:
          media ??
          MediaInfo(
            source: Uri.file('/srv/footage/north face.mkv'),
            duration: const Duration(minutes: 18, seconds: 30),
            title: 'north face.mkv',
            video: const VideoFormat(
              width: 1920,
              height: 1080,
              frameRate: FrameRate.pal,
            ),
          ),
    );

void main() {
  group('idle inhibition', () {
    test('holds only while playing', () {
      expect(
        IdleInhibitPolicy.shouldInhibit(_state(PlaybackStatus.playing)),
        isTrue,
      );
      for (final status in <PlaybackStatus>[
        PlaybackStatus.paused,
        PlaybackStatus.ended,
        PlaybackStatus.idle,
        PlaybackStatus.failed,
        PlaybackStatus.opening,
      ]) {
        expect(
          IdleInhibitPolicy.shouldInhibit(_state(status)),
          isFalse,
          reason: '$status should not hold the screen awake',
        );
      }
    });

    test('inhibits once and releases once across a play/pause cycle', () async {
      final playback = FakePlaybackController();
      final inhibitor = _RecordingInhibitor();
      final policy = IdleInhibitPolicy(
        playback: playback,
        inhibitor: inhibitor,
      );

      playback.state = _state(PlaybackStatus.playing);
      await policy.sync();
      // Repeated position updates arrive constantly while playing; none of them
      // should produce another D-Bus call.
      await policy.sync();
      await policy.sync();
      expect(inhibitor.calls, <String>['inhibit(Playing video)']);

      playback.state = _state(PlaybackStatus.paused);
      await policy.sync();
      await policy.sync();
      expect(inhibitor.calls, <String>['inhibit(Playing video)', 'release()']);
    });

    test('releases when the file ends', () async {
      final playback = FakePlaybackController();
      final inhibitor = _RecordingInhibitor();
      final policy = IdleInhibitPolicy(
        playback: playback,
        inhibitor: inhibitor,
      );

      playback.state = _state(PlaybackStatus.playing);
      await policy.sync();
      playback.state = _state(PlaybackStatus.ended);
      await policy.sync();

      expect(inhibitor.calls.last, 'release()');
    });
  });

  group('MPRIS mapping', () {
    test('collapses six states onto the three MPRIS knows', () {
      expect(MprisMapping.playbackStatus(PlaybackStatus.playing), 'Playing');
      expect(MprisMapping.playbackStatus(PlaybackStatus.paused), 'Paused');
      expect(MprisMapping.playbackStatus(PlaybackStatus.opening), 'Paused');
      expect(MprisMapping.playbackStatus(PlaybackStatus.idle), 'Stopped');
      expect(MprisMapping.playbackStatus(PlaybackStatus.failed), 'Stopped');
      // Not Paused: a shell should not offer to resume a finished file.
      expect(MprisMapping.playbackStatus(PlaybackStatus.ended), 'Stopped');
    });

    test('scales volume into 0..1 and clamps above unity', () {
      expect(
        MprisMapping.volume(const PlaybackState(volume: 50)),
        closeTo(0.5, 1e-9),
      );
      expect(MprisMapping.volume(const PlaybackState(volume: 100)), 1.0);
      // Kino goes to 150 %; the shell slider does not.
      expect(MprisMapping.volume(const PlaybackState(volume: 150)), 1.0);
      expect(
        MprisMapping.volume(const PlaybackState(volume: 80, muted: true)),
        0.0,
      );
    });

    test('track ids are valid object paths', () {
      final id = MprisMapping.trackId(Uri.file('/srv/foot age/a-b.c.mkv'));
      // Object path elements may only contain [A-Za-z0-9_]; anything else here
      // makes every shell reject the metadata silently.
      expect(RegExp(r'^(/[A-Za-z0-9_]+)+$').hasMatch(id), isTrue, reason: id);
    });

    test('a track id changes with the file and not otherwise', () {
      final first = MprisMapping.trackId(Uri.file('/a/one.mkv'));
      expect(MprisMapping.trackId(Uri.file('/a/one.mkv')), first);
      expect(MprisMapping.trackId(Uri.file('/a/two.mkv')), isNot(first));
      expect(MprisMapping.trackId(null), isNot(first));
    });

    test('metadata carries length in microseconds, url and title', () {
      final metadata = MprisMapping.metadata(_state(PlaybackStatus.playing));
      expect(
        metadata['mpris:length'],
        const Duration(minutes: 18, seconds: 30).inMicroseconds,
      );
      expect(metadata['xesam:title'], 'north face.mkv');
      expect(metadata['xesam:url'], startsWith('file://'));
    });

    test('metadata with nothing loaded is a track id and nothing else', () {
      final metadata = MprisMapping.metadata(PlaybackState.idle);
      expect(metadata.keys, <String>['mpris:trackid']);
    });

    test('the bus name is a legal one', () {
      // A dot or a hyphen after the last element makes requestName fail at
      // runtime, on Linux, where this cannot be tested.
      expect(
        RegExp(
          r'^[A-Za-z_][A-Za-z0-9_]*(\.[A-Za-z_][A-Za-z0-9_]*)+$',
        ).hasMatch(MprisMapping.busName),
        isTrue,
        reason: MprisMapping.busName,
      );
    });
  });
}
