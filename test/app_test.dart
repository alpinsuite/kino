import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kino/app.dart';

void main() {
  // These pump the real KinoApp rather than a widget out of it. Every other
  // test in this suite builds a single widget under a hand-made harness, and
  // that is exactly why a startup crash in the provider wiring reached a
  // running binary: Provider<T> asserts when T is a Listenable, which
  // PlaybackController is, and no test had ever built the tree that does it.
  group('KinoApp', () {
    testWidgets('starts without an engine and explains itself', (tester) async {
      await tester.pumpWidget(
        const KinoApp(
          engineFailure: 'Cannot find libmpv-2.dll in your system %PATH%.',
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Video playback is unavailable'), findsOneWidget);
    });

    testWidgets('survives a resize to the minimum window size', (tester) async {
      await tester.binding.setSurfaceSize(const Size(600, 380));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(const KinoApp(engineFailure: 'no libmpv'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });
}
