/*
 * AI-Provenance:
 *   model: Claude Opus 5
 *   harness: Cursor
 */
import 'package:advanced_forms_docs_islands/generated/registry.dart';
import 'package:advanced_forms_docs_islands/support/island_frame.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Puts every snippet in the docs through the constraints a real island
/// imposes: a fixed width and an unbounded height, so the framework's computed
/// height is what sizes the host element on the page.
///
/// This is the check that catches the one rule an author has to remember —
/// an auto-height island cannot use `Scaffold`, which takes all the height it
/// is offered. `flutter analyze` cannot see that; this can.
void main() {
  testWidgets('the docs contain at least one example', (tester) async {
    expect(
      examples,
      isNotEmpty,
      reason: 'run `npm run examples:generate` in docs_app',
    );
  });

  for (final entry in examples.entries) {
    group('example ${entry.key}', () {
      testWidgets('lays out under unbounded height', (tester) async {
        await tester.pumpWidget(_island(entry.value));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);

        final size = tester.getSize(find.byType(IslandFrame));
        expect(size.width, 400);
        expect(
          size.height,
          greaterThan(0),
          reason: 'the island would collapse to nothing on the page',
        );
        expect(
          size.height,
          lessThan(5000),
          reason: 'an island that tall probably means something took '
              'constraints.biggest — use height={...} for it',
        );
      });

      testWidgets('survives a rebuild in the other brightness', (tester) async {
        await tester.pumpWidget(_island(entry.value));
        await tester.pumpAndSettle();
        await tester.pumpWidget(_island(entry.value, Brightness.dark));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
      });
    });
  }
}

Widget _island(
  WidgetBuilder builder, [
  Brightness brightness = Brightness.light,
]) {
  return Directionality(
    textDirection: TextDirection.ltr,
    child: Align(
      alignment: Alignment.topCenter,
      // A scroll view is the simplest way to hand the frame the same
      // constraints `viewConstraints: {minHeight: 0, maxHeight: Infinity}`
      // produces in the browser: tight width, unbounded height.
      child: SingleChildScrollView(
        child: SizedBox(
          width: 400,
          child: IslandFrame(brightness: brightness, builder: builder),
        ),
      ),
    ),
  );
}
