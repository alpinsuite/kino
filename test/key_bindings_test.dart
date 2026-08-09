import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kino/core/commands.dart';

void main() {
  group('default bindings', () {
    test('bind every command that a key should reach', () {
      final bound = kDefaultKeyBindings.values.toSet();
      final unbound = KinoCommand.values.toSet().difference(bound);

      // `stop` has no default key: mpv has none either, and a key that unloads
      // the file sits one slip away from every other transport key.
      expect(unbound, <KinoCommand>{KinoCommand.stop});
    });

    test('no two commands share an activator', () {
      // A Map cannot hold a duplicate key, so a collision silently drops the
      // earlier binding at the literal. Comparing counts is what catches it.
      final activators = kDefaultKeyBindings.keys
          .map((a) => a.toString())
          .toList();
      expect(activators.toSet(), hasLength(activators.length));
    });

    test('honour the muscle memory that is not negotiable', () {
      expect(
        kDefaultKeyBindings[const SingleActivator(LogicalKeyboardKey.space)],
        KinoCommand.playPause,
      );
      expect(
        kDefaultKeyBindings[const SingleActivator(LogicalKeyboardKey.escape)],
        KinoCommand.exitFullscreen,
      );
    });

    test('never bind a bare key to quit', () {
      // In mpv, `q` quits. In a window that is one keystroke from losing a
      // two-hour position by accident.
      for (final entry in kDefaultKeyBindings.entries) {
        if (entry.value != KinoCommand.quit) continue;
        final activator = entry.key as SingleActivator;
        expect(
          activator.control || activator.meta,
          isTrue,
          reason: '$activator quits without a modifier',
        );
      }
    });

    test('use the seek steps §1 names, on the modifiers it names', () {
      const left = LogicalKeyboardKey.arrowLeft;
      expect(
        kDefaultKeyBindings[const SingleActivator(left)],
        KinoCommand.seekBackMedium,
      );
      expect(
        kDefaultKeyBindings[const SingleActivator(left, shift: true)],
        KinoCommand.seekBackSmall,
      );
      expect(
        kDefaultKeyBindings[const SingleActivator(left, control: true)],
        KinoCommand.seekBackLarge,
      );
    });

    test('keep frame stepping on mpv\'s comma and period', () {
      expect(
        kDefaultKeyBindings[const SingleActivator(LogicalKeyboardKey.comma)],
        KinoCommand.frameBack,
      );
      expect(
        kDefaultKeyBindings[const SingleActivator(LogicalKeyboardKey.period)],
        KinoCommand.frameForward,
      );
    });
  });

  test('the step constants are the ones the specification states', () {
    expect(SeekSteps.small, const Duration(seconds: 1));
    expect(SeekSteps.medium, const Duration(seconds: 5));
    expect(SeekSteps.large, const Duration(seconds: 60));
    expect(kDelayStep, const Duration(milliseconds: 100));
  });
}
