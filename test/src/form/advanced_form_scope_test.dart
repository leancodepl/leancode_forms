import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:leancode_forms/leancode_forms.dart';

/// A controller that records whether/how many times it was created and
/// disposed, without needing a widget tree.
class _RecordingController extends AdvancedFormController {
  int disposeCalls = 0;

  @override
  void dispose() {
    disposeCalls++;
    super.dispose();
  }
}

class _Reader extends StatelessWidget {
  const _Reader({required this.builder});

  final Widget Function(BuildContext context) builder;

  @override
  Widget build(BuildContext context) => builder(context);
}

void main() {
  group('AdvancedFormScope', () {
    testWidgets('does not call create until first read', (tester) async {
      var createCalls = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: AdvancedFormScope<_RecordingController>(
            create: (context) {
              createCalls++;
              return _RecordingController();
            },
            child: const SizedBox(),
          ),
        ),
      );

      expect(createCalls, 0);
    });

    testWidgets('calls create exactly once across multiple reads',
        (tester) async {
      var createCalls = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: AdvancedFormScope<_RecordingController>(
            create: (context) {
              createCalls++;
              return _RecordingController();
            },
            child: _Reader(
              builder: (context) {
                AdvancedFormScope.watch<_RecordingController>(context);
                AdvancedFormScope.read<_RecordingController>(context);
                return const SizedBox();
              },
            ),
          ),
        ),
      );

      expect(createCalls, 1);
    });

    testWidgets('watch dependents rebuild on notify', (tester) async {
      late _RecordingController controller;
      var buildCalls = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: AdvancedFormScope<_RecordingController>(
            create: (context) => _RecordingController(),
            child: _Reader(
              builder: (context) {
                buildCalls++;
                controller = AdvancedFormScope.watch<_RecordingController>(
                  context,
                );
                return const SizedBox();
              },
            ),
          ),
        ),
      );

      expect(buildCalls, 1);

      controller.setValidationEnabled(false);
      await tester.pump();

      expect(buildCalls, 2);
    });

    testWidgets('read dependents do not rebuild on notify', (tester) async {
      late _RecordingController controller;
      var buildCalls = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: AdvancedFormScope<_RecordingController>(
            create: (context) => _RecordingController(),
            child: _Reader(
              builder: (context) {
                buildCalls++;
                controller = AdvancedFormScope.read<_RecordingController>(
                  context,
                );
                return const SizedBox();
              },
            ),
          ),
        ),
      );

      expect(buildCalls, 1);

      controller.setValidationEnabled(false);
      await tester.pump();

      expect(buildCalls, 1);
    });

    testWidgets('disposes the controller when the scope unmounts',
        (tester) async {
      late _RecordingController controller;

      await tester.pumpWidget(
        MaterialApp(
          home: AdvancedFormScope<_RecordingController>(
            create: (context) => _RecordingController(),
            child: _Reader(
              builder: (context) {
                controller = AdvancedFormScope.read<_RecordingController>(
                  context,
                );
                return const SizedBox();
              },
            ),
          ),
        ),
      );

      await tester.pumpWidget(const MaterialApp(home: SizedBox()));

      expect(controller.disposeCalls, 1);
      expect(controller.isDisposed, isTrue);
    });

    testWidgets('a never-read controller is never created and never disposed',
        (tester) async {
      var createCalls = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: AdvancedFormScope<_RecordingController>(
            create: (context) {
              createCalls++;
              return _RecordingController();
            },
            child: const SizedBox(),
          ),
        ),
      );

      await tester.pumpWidget(const MaterialApp(home: SizedBox()));

      expect(createCalls, 0);
    });

    testWidgets('.value controllers survive unmount undisposed',
        (tester) async {
      final controller = _RecordingController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: AdvancedFormScope<_RecordingController>.value(
            value: controller,
            child: _Reader(
              builder: (context) {
                AdvancedFormScope.read<_RecordingController>(context);
                return const SizedBox();
              },
            ),
          ),
        ),
      );

      await tester.pumpWidget(const MaterialApp(home: SizedBox()));

      expect(controller.disposeCalls, 0);
      expect(controller.isDisposed, isFalse);
    });

    testWidgets('.value rebuilds dependents and swaps subscription',
        (tester) async {
      final controllerA = _RecordingController();
      final controllerB = _RecordingController();
      addTearDown(controllerA.dispose);
      addTearDown(controllerB.dispose);
      late _RecordingController watched;
      var buildCalls = 0;

      Widget buildApp(_RecordingController value) => MaterialApp(
            home: AdvancedFormScope<_RecordingController>.value(
              value: value,
              child: _Reader(
                builder: (context) {
                  buildCalls++;
                  watched = AdvancedFormScope.watch<_RecordingController>(
                    context,
                  );
                  return const SizedBox();
                },
              ),
            ),
          );

      await tester.pumpWidget(buildApp(controllerA));
      expect(watched, controllerA);
      expect(buildCalls, 1);

      await tester.pumpWidget(buildApp(controllerB));
      expect(watched, controllerB);
      expect(buildCalls, 2);

      // Notifying the old controller must no longer trigger a rebuild.
      controllerA.setValidationEnabled(false);
      await tester.pump();
      expect(buildCalls, 2);

      controllerB.setValidationEnabled(false);
      await tester.pump();
      expect(buildCalls, 3);

      expect(controllerA.isDisposed, isFalse);
      expect(controllerB.isDisposed, isFalse);
    });

    testWidgets('nested scopes of the same type resolve to the innermost',
        (tester) async {
      late _RecordingController innerLookup;

      await tester.pumpWidget(
        MaterialApp(
          home: AdvancedFormScope<_RecordingController>(
            create: (context) => _RecordingController(),
            child: AdvancedFormScope<_RecordingController>(
              create: (context) => _RecordingController(),
              child: _Reader(
                builder: (context) {
                  innerLookup = AdvancedFormScope.read<_RecordingController>(
                    context,
                  );
                  return const SizedBox();
                },
              ),
            ),
          ),
        ),
      );

      final innerElement = tester
          .element(find.byType(_Reader))
          .findAncestorWidgetOfExactType<AdvancedFormScope<_RecordingController>>();
      expect(innerLookup, isNotNull);
      expect(innerElement, isNotNull);
    });

    testWidgets('throws a StateError with a helpful message when not found',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: _Reader(
            builder: (context) {
              expect(
                () => AdvancedFormScope.watch<_RecordingController>(context),
                throwsA(
                  isA<StateError>().having(
                    (e) => e.message,
                    'message',
                    allOf(
                      contains('_RecordingController'),
                      contains('exact type argument'),
                    ),
                  ),
                ),
              );
              return const SizedBox();
            },
          ),
        ),
      );
    });

    testWidgets('asserts against an already-disposed .value controller',
        (tester) async {
      final disposed = _RecordingController()..dispose();

      await tester.pumpWidget(
        MaterialApp(
          home: AdvancedFormScope<_RecordingController>.value(
            value: disposed,
            child: _Reader(
              builder: (context) {
                AdvancedFormScope.read<_RecordingController>(context);
                return const SizedBox();
              },
            ),
          ),
        ),
      );

      expect(tester.takeException(), isAssertionError);
    });
  });
}
