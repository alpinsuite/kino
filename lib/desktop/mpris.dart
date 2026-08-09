import 'dart:async';
import 'dart:io';

import 'package:dbus/dbus.dart';
import 'package:kino_core/kino_core.dart';
import 'package:kino_media/kino_media.dart';

/// The pure half of MPRIS: what each D-Bus property should say for a given
/// [PlaybackState].
///
/// Separated so the mapping — which is where this can be quietly wrong, and
/// where being wrong means a lock screen showing the previous file — is
/// testable without a session bus.
abstract final class MprisMapping {
  /// The MPRIS name Kino owns. The suffix must be a valid bus-name element:
  /// no dots, no hyphens.
  static const String busName = 'org.mpris.MediaPlayer2.kino';
  static const String objectPath = '/org/mpris/MediaPlayer2';
  static const String rootInterface = 'org.mpris.MediaPlayer2';
  static const String playerInterface = 'org.mpris.MediaPlayer2.Player';

  /// MPRIS knows three states and Kino has six.
  ///
  /// `ended` reports Stopped rather than Paused: the shell should not offer to
  /// resume something that has finished, and a paused-looking player at the end
  /// of a file is what makes a media widget feel stuck.
  static String playbackStatus(PlaybackStatus status) => switch (status) {
    PlaybackStatus.playing => 'Playing',
    PlaybackStatus.paused || PlaybackStatus.opening => 'Paused',
    PlaybackStatus.idle ||
    PlaybackStatus.ended ||
    PlaybackStatus.failed => 'Stopped',
  };

  /// MPRIS volume is 0..1; Kino's is 0..150 percent.
  ///
  /// Clamped at 1.0 rather than reporting 1.5, because the shell slider has no
  /// room above unity and a value outside the range makes it render at zero on
  /// some shells.
  static double volume(PlaybackState state) =>
      state.muted ? 0 : (state.volume / 100).clamp(0.0, 1.0);

  /// A track id unique per opened file.
  ///
  /// MPRIS requires an object path, and shells use a *change* of id as the
  /// signal that the track changed. Derived from the source so replaying the
  /// same file does not look like a new track, and sanitised because a path
  /// element may only contain `[A-Za-z0-9_]`.
  static String trackId(Uri? source) {
    if (source == null) return '/ch/alpinsuite/kino/NoTrack';
    final sanitised = source.toString().replaceAll(
      RegExp('[^A-Za-z0-9_]'),
      '_',
    );
    return '/ch/alpinsuite/kino/track/$sanitised';
  }

  /// `xesam:title` and friends, as plain Dart so a test can read them.
  static Map<String, Object> metadata(PlaybackState state) {
    final media = state.media;
    final entries = <String, Object>{'mpris:trackid': trackId(media?.source)};
    if (media == null) return entries;

    entries['mpris:length'] = media.duration.inMicroseconds;
    entries['xesam:url'] = media.source.toString();
    final title = media.title;
    if (title != null && title.isNotEmpty) entries['xesam:title'] = title;
    return entries;
  }
}

/// Publishes Kino on the session bus as an MPRIS2 player.
///
/// §0.5 calls this non-negotiable, and it is what makes the media keys work,
/// puts Kino in the GNOME and KDE shell controls, and shows it on the lock
/// screen. Users notice its absence within minutes.
class MprisService {
  MprisService({
    required this.playback,
    required this.onRaise,
    required this.onQuit,
    DBusClient? bus,
    // Assigned in the body, not as an initialising formal: a named parameter
    // cannot be called `_bus`, and the field is replaced on dispose.
  }) {
    _bus = bus;
  }

  final PlaybackController playback;
  final Future<void> Function() onRaise;
  final Future<void> Function() onQuit;

  DBusClient? _bus;
  _MprisObject? _object;
  PlaybackState? _published;

  /// Registers on the bus. Never throws: a missing or refused session bus must
  /// not stop the player from playing.
  Future<bool> start() async {
    try {
      final bus = _bus ??= DBusClient.session();
      final object = _MprisObject(this);
      await bus.requestName(
        MprisMapping.busName,
        flags: <DBusRequestNameFlag>{DBusRequestNameFlag.doNotQueue},
      );
      await bus.registerObject(object);
      _object = object;
      _published = playback.state;
      playback.addListener(_onChanged);
      return true;
    } on Object {
      return false;
    }
  }

  Future<void> dispose() async {
    playback.removeListener(_onChanged);
    _object = null;
    await _bus?.close();
    _bus = null;
  }

  void _onChanged() => unawaited(_publish());

  /// Emits `PropertiesChanged` for what actually changed.
  ///
  /// Position is excluded on purpose: MPRIS says it is not to be signalled on
  /// every tick — shells poll it — and emitting it at the engine's update rate
  /// would put a D-Bus message on the bus several times a second for every
  /// listener on the desktop.
  Future<void> _publish() async {
    final object = _object;
    final previous = _published;
    if (object == null) return;

    final state = playback.state;
    _published = state;

    final changed = <String, DBusValue>{};
    if (previous == null ||
        previous.status != state.status ||
        previous.speed != state.speed) {
      changed['PlaybackStatus'] = DBusString(
        MprisMapping.playbackStatus(state.status),
      );
      changed['Rate'] = DBusDouble(state.speed);
    }
    if (previous == null ||
        previous.volume != state.volume ||
        previous.muted != state.muted) {
      changed['Volume'] = DBusDouble(MprisMapping.volume(state));
    }
    if (previous == null || previous.media != state.media) {
      changed['Metadata'] = object.metadataValue();
      changed['CanSeek'] = DBusBoolean(state.hasMedia);
      changed['CanPlay'] = DBusBoolean(state.hasMedia);
      changed['CanPause'] = DBusBoolean(state.hasMedia);
    }
    if (changed.isEmpty) return;

    try {
      await object.emitPropertiesChanged(
        MprisMapping.playerInterface,
        changedProperties: changed,
      );
    } on Object {
      // The bus went away; playback is unaffected.
    }
  }
}

/// The exported object. Both MPRIS interfaces live on the one path.
class _MprisObject extends DBusObject {
  _MprisObject(this.service) : super(DBusObjectPath(MprisMapping.objectPath));

  final MprisService service;

  PlaybackState get _state => service.playback.state;

  DBusValue metadataValue() =>
      DBusDict(DBusSignature('s'), DBusSignature('v'), <DBusValue, DBusValue>{
        for (final entry in MprisMapping.metadata(_state).entries)
          DBusString(entry.key): DBusVariant(switch (entry.value) {
            final int value when entry.key == 'mpris:trackid' => DBusString(
              '$value',
            ),
            final int value => DBusInt64(value),
            final String value when entry.key == 'mpris:trackid' =>
              DBusObjectPath(value),
            final String value => DBusString(value),
            final Object value => DBusString('$value'),
          }),
      });

  @override
  List<DBusIntrospectInterface> introspect() => <DBusIntrospectInterface>[
    DBusIntrospectInterface(
      MprisMapping.rootInterface,
      methods: <DBusIntrospectMethod>[
        DBusIntrospectMethod('Raise'),
        DBusIntrospectMethod('Quit'),
      ],
      properties: <DBusIntrospectProperty>[
        DBusIntrospectProperty('CanQuit', DBusSignature('b')),
        DBusIntrospectProperty('CanRaise', DBusSignature('b')),
        DBusIntrospectProperty('HasTrackList', DBusSignature('b')),
        DBusIntrospectProperty('Identity', DBusSignature('s')),
        DBusIntrospectProperty('DesktopEntry', DBusSignature('s')),
        DBusIntrospectProperty('SupportedUriSchemes', DBusSignature('as')),
        DBusIntrospectProperty('SupportedMimeTypes', DBusSignature('as')),
      ],
    ),
    DBusIntrospectInterface(
      MprisMapping.playerInterface,
      methods: <DBusIntrospectMethod>[
        DBusIntrospectMethod('Play'),
        DBusIntrospectMethod('Pause'),
        DBusIntrospectMethod('PlayPause'),
        DBusIntrospectMethod('Stop'),
        DBusIntrospectMethod('Next'),
        DBusIntrospectMethod('Previous'),
        DBusIntrospectMethod('Seek'),
        DBusIntrospectMethod('SetPosition'),
      ],
      properties: <DBusIntrospectProperty>[
        DBusIntrospectProperty('PlaybackStatus', DBusSignature('s')),
        DBusIntrospectProperty('Metadata', DBusSignature('a{sv}')),
        DBusIntrospectProperty('Position', DBusSignature('x')),
        DBusIntrospectProperty(
          'Volume',
          DBusSignature('d'),
          access: DBusPropertyAccess.readwrite,
        ),
        DBusIntrospectProperty(
          'Rate',
          DBusSignature('d'),
          access: DBusPropertyAccess.readwrite,
        ),
        DBusIntrospectProperty('CanPlay', DBusSignature('b')),
        DBusIntrospectProperty('CanPause', DBusSignature('b')),
        DBusIntrospectProperty('CanSeek', DBusSignature('b')),
        DBusIntrospectProperty('CanControl', DBusSignature('b')),
        DBusIntrospectProperty('CanGoNext', DBusSignature('b')),
        DBusIntrospectProperty('CanGoPrevious', DBusSignature('b')),
      ],
    ),
  ];

  @override
  Future<DBusMethodResponse> getProperty(String interface, String name) async {
    if (interface == MprisMapping.rootInterface) {
      return switch (name) {
        'CanQuit' => DBusGetPropertyResponse(const DBusBoolean(true)),
        'CanRaise' => DBusGetPropertyResponse(const DBusBoolean(true)),
        'HasTrackList' => DBusGetPropertyResponse(const DBusBoolean(false)),
        'Identity' => DBusGetPropertyResponse(const DBusString('Kino')),
        'DesktopEntry' => DBusGetPropertyResponse(
          const DBusString('ch.alpinsuite.Kino'),
        ),
        'SupportedUriSchemes' => DBusGetPropertyResponse(
          DBusArray.string(<String>['file', 'http', 'https']),
        ),
        'SupportedMimeTypes' => DBusGetPropertyResponse(
          DBusArray.string(<String>[
            'video/mp4',
            'video/x-matroska',
            'video/webm',
            'video/quicktime',
            'video/x-msvideo',
            'video/mpeg',
          ]),
        ),
        _ => DBusMethodErrorResponse.unknownProperty(),
      };
    }

    if (interface != MprisMapping.playerInterface) {
      return DBusMethodErrorResponse.unknownInterface();
    }

    final state = _state;
    return switch (name) {
      'PlaybackStatus' => DBusGetPropertyResponse(
        DBusString(MprisMapping.playbackStatus(state.status)),
      ),
      'Metadata' => DBusGetPropertyResponse(metadataValue()),
      'Position' => DBusGetPropertyResponse(
        DBusInt64(state.position.inMicroseconds),
      ),
      'Volume' => DBusGetPropertyResponse(
        DBusDouble(MprisMapping.volume(state)),
      ),
      'Rate' => DBusGetPropertyResponse(DBusDouble(state.speed)),
      'MinimumRate' => DBusGetPropertyResponse(const DBusDouble(0.25)),
      'MaximumRate' => DBusGetPropertyResponse(const DBusDouble(4)),
      'CanPlay' ||
      'CanPause' ||
      'CanSeek' => DBusGetPropertyResponse(DBusBoolean(state.hasMedia)),
      'CanControl' => DBusGetPropertyResponse(const DBusBoolean(true)),
      // There is no playlist yet, so neither is offered rather than offered
      // and silently ignored.
      'CanGoNext' ||
      'CanGoPrevious' => DBusGetPropertyResponse(const DBusBoolean(false)),
      _ => DBusMethodErrorResponse.unknownProperty(),
    };
  }

  @override
  Future<DBusMethodResponse> setProperty(
    String interface,
    String name,
    DBusValue value,
  ) async {
    if (interface != MprisMapping.playerInterface) {
      return DBusMethodErrorResponse.unknownInterface();
    }
    switch (name) {
      case 'Volume':
        if (value is! DBusDouble) {
          return DBusMethodErrorResponse.invalidArgs();
        }
        await service.playback.setVolume((value.value * 100).round());
        return DBusMethodSuccessResponse();
      case 'Rate':
        if (value is! DBusDouble) {
          return DBusMethodErrorResponse.invalidArgs();
        }
        await service.playback.setSpeed(value.value);
        return DBusMethodSuccessResponse();
      default:
        return DBusMethodErrorResponse.unknownProperty();
    }
  }

  @override
  Future<DBusMethodResponse> getAllProperties(String interface) async {
    final names = introspect()
        .where((candidate) => candidate.name == interface)
        .expand((candidate) => candidate.properties)
        .map((property) => property.name);

    final values = <String, DBusValue>{};
    for (final name in names) {
      final response = await getProperty(interface, name);
      if (response is DBusGetPropertyResponse) {
        values[name] = response.values.first is DBusVariant
            ? (response.values.first as DBusVariant).value
            : response.values.first;
      }
    }
    return DBusGetAllPropertiesResponse(values);
  }

  @override
  Future<DBusMethodResponse> handleMethodCall(DBusMethodCall call) async {
    final playback = service.playback;

    if (call.interface == MprisMapping.rootInterface) {
      switch (call.name) {
        case 'Raise':
          await service.onRaise();
          return DBusMethodSuccessResponse();
        case 'Quit':
          await service.onQuit();
          return DBusMethodSuccessResponse();
        default:
          return DBusMethodErrorResponse.unknownMethod();
      }
    }

    if (call.interface != MprisMapping.playerInterface) {
      return DBusMethodErrorResponse.unknownInterface();
    }

    switch (call.name) {
      case 'Play':
        await playback.play();
      case 'Pause':
        await playback.pause();
      case 'PlayPause':
        await playback.playOrPause();
      case 'Stop':
        await playback.stop();
      case 'Next' || 'Previous':
        // No playlist yet. CanGoNext already says so; answering the call
        // silently is friendlier than an error a shell will log.
        break;
      case 'Seek':
        final offset = call.values.first as DBusInt64;
        final target =
            playback.state.position + Duration(microseconds: offset.value);
        await playback.seek(target < Duration.zero ? Duration.zero : target);
      case 'SetPosition':
        final position = call.values[1] as DBusInt64;
        await playback.seek(Duration(microseconds: position.value));
      case 'OpenUri':
        final uri = call.values.first as DBusString;
        await playback.open(Uri.parse(uri.value));
      default:
        return DBusMethodErrorResponse.unknownMethod();
    }
    return DBusMethodSuccessResponse();
  }
}

/// Null off Linux, where there is no session bus to publish on.
MprisService? createMprisService({
  required PlaybackController playback,
  required Future<void> Function() onRaise,
  required Future<void> Function() onQuit,
}) => Platform.isLinux
    ? MprisService(playback: playback, onRaise: onRaise, onQuit: onQuit)
    : null;
