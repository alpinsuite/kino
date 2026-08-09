import 'dart:async';
import 'dart:io';

import 'package:dbus/dbus.dart';
import 'package:kino_core/kino_core.dart';
import 'package:kino_media/kino_media.dart';

/// Keeps the screen awake while something is playing.
///
/// "The screen does not blank during playback, and does blank when paused" is an
/// acceptance criterion, and a screen that blanks mid-film is the single most
/// complained-about bug in every player.
abstract class IdleInhibitor {
  /// Idempotent: inhibiting twice must not need releasing twice.
  Future<void> inhibit(String reason);
  Future<void> release();
  Future<void> dispose();
}

/// Inhibits over D-Bus.
///
/// **This is a deliberate departure from §0.5**, which asks for the Wayland
/// `idle-inhibit-unstable-v1` protocol on Wayland and
/// `org.freedesktop.ScreenSaver` on X11.
///
/// The Wayland protocol needs a `wl_surface` to inhibit *against*, and Flutter
/// does not expose one to Dart — it would mean C in `linux/` reaching into the
/// GTK embedder. The D-Bus route needs none of that and covers the same
/// machines: GNOME and KDE both implement `org.freedesktop.ScreenSaver` under
/// Wayland as well as X11, because every application that predates the protocol
/// still calls it.
///
/// A compositor that implements neither will blank the screen. That is a real
/// gap, and the honest place to close it is native code — see docs/DECISIONS.md.
class DBusIdleInhibitor implements IdleInhibitor {
  // The bus is assigned in the body rather than as an initialising formal: a
  // named parameter cannot be called `_bus`, and the field has to stay private
  // because it is replaced on dispose.
  DBusIdleInhibitor({DBusClient? bus, this.applicationName = 'Kino'}) {
    _bus = bus;
  }

  /// Each entry is a service that might be listening. The first that answers
  /// wins; the rest are not tried.
  static const List<({String name, String path, String interface})> _services =
      <({String name, String path, String interface})>[
        (
          name: 'org.freedesktop.ScreenSaver',
          path: '/org/freedesktop/ScreenSaver',
          interface: 'org.freedesktop.ScreenSaver',
        ),
        (
          name: 'org.freedesktop.PowerManagement.Inhibit',
          path: '/org/freedesktop/PowerManagement/Inhibit',
          interface: 'org.freedesktop.PowerManagement.Inhibit',
        ),
      ];

  DBusClient? _bus;

  /// What the desktop shows in "this application is keeping the screen awake".
  final String applicationName;

  int? _cookie;
  ({String name, String path, String interface})? _held;

  bool get isInhibiting => _cookie != null;

  DBusClient get _client => _bus ??= DBusClient.session();

  @override
  Future<void> inhibit(String reason) async {
    if (_cookie != null) return;

    for (final service in _services) {
      try {
        final reply = await _client.callMethod(
          destination: service.name,
          path: DBusObjectPath(service.path),
          interface: service.interface,
          name: 'Inhibit',
          values: <DBusValue>[DBusString(applicationName), DBusString(reason)],
          replySignature: DBusSignature('u'),
        );
        _cookie = (reply.returnValues.first as DBusUint32).value;
        _held = service;
        return;
      } on Object {
        // Not running, or refused. Try the next; a desktop that offers neither
        // is a screen that blanks, not a crash.
        continue;
      }
    }
  }

  @override
  Future<void> release() async {
    final cookie = _cookie;
    final service = _held;
    _cookie = null;
    _held = null;
    if (cookie == null || service == null) return;

    try {
      await _client.callMethod(
        destination: service.name,
        path: DBusObjectPath(service.path),
        interface: service.interface,
        name: 'UnInhibit',
        values: <DBusValue>[DBusUint32(cookie)],
        replySignature: DBusSignature(''),
      );
    } on Object {
      // The inhibit dies with the connection anyway.
    }
  }

  @override
  Future<void> dispose() async {
    await release();
    await _bus?.close();
    _bus = null;
  }
}

/// Decides when to hold the inhibit, and holds it.
///
/// Split from [IdleInhibitor] so the rule — which is the part that can be wrong
/// in a way a user notices — is testable without a bus.
class IdleInhibitPolicy {
  IdleInhibitPolicy({
    required this.playback,
    required this.inhibitor,
    this.reason = 'Playing video',
  });

  final PlaybackController playback;
  final IdleInhibitor inhibitor;
  final String reason;

  bool _inhibiting = false;

  /// Playing, and nothing else.
  ///
  /// Paused, ended, idle and failed all release. Pausing to answer the door and
  /// coming back to a locked session is the complaint this exists to prevent,
  /// and holding the inhibit while paused causes exactly that in reverse: a
  /// machine that never sleeps because a player is sitting open.
  static bool shouldInhibit(PlaybackState state) =>
      state.status == PlaybackStatus.playing;

  void start() => playback.addListener(_sync);

  void stop() => playback.removeListener(_sync);

  /// Visible for testing, and called on every state change.
  Future<void> sync() async {
    final wanted = shouldInhibit(playback.state);
    if (wanted == _inhibiting) return;
    _inhibiting = wanted;
    await (wanted ? inhibitor.inhibit(reason) : inhibitor.release());
  }

  void _sync() => unawaited(sync());
}

/// Builds the inhibitor this platform can actually use.
///
/// Returns null off Linux — there is no session bus on a Windows development
/// machine, and attempting one throws at startup.
IdleInhibitor? createIdleInhibitor() =>
    Platform.isLinux ? DBusIdleInhibitor() : null;
