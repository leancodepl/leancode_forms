import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:leancode_forms/src/utils/shared_call.dart';

void main() {
  late SharedCall<int> call;

  setUp(() {
    call = SharedCall<int>();
  });

  group('run', () {
    test('joins the run in flight instead of running the body twice', () async {
      final gate = Completer<int>();
      var calls = 0;
      Future<int> body() {
        calls++;
        return gate.future;
      }

      final first = call.run(body);
      final second = call.run(body);

      expect(identical(first, second), isTrue);
      expect(calls, 1);

      gate.complete(7);
      expect(await first, 7);
      expect(await second, 7);
    });

    test('a re-entrant call from inside the body joins the same run', () async {
      var calls = 0;
      late Future<int> reentrant;
      Future<int> body() async {
        calls++;
        // The slot is claimed before the body runs, so a validator that
        // synchronously asks for another pass joins this one.
        reentrant = call.run(body);
        return 1;
      }

      final first = call.run(body);

      expect(await first, 1);
      expect(identical(reentrant, first), isTrue);
      expect(calls, 1);
    });

    test('runs the body again once the earlier run has settled', () async {
      var calls = 0;
      Future<int> body() async {
        calls++;
        return calls;
      }

      expect(await call.run(body), 1);
      expect(await call.run(body), 2);
      expect(calls, 2);
    });

    test('runs the body again once the earlier run has rejected', () async {
      var calls = 0;
      Future<int> body() async {
        calls++;
        if (calls == 1) {
          throw StateError('body exploded');
        }
        return calls;
      }

      await expectLater(call.run(body), throwsStateError);

      expect(await call.run(body), 2);
    });

    test('rejects every joined caller with the same error', () async {
      final gate = Completer<int>();
      final failure = StateError('body exploded');
      var calls = 0;
      Future<int> body() {
        calls++;
        return gate.future;
      }

      final first = call.run(body);
      final second = call.run(body);
      gate.completeError(failure, StackTrace.current);

      await expectLater(first, throwsA(same(failure)));
      await expectLater(second, throwsA(same(failure)));
      expect(calls, 1);
      // A duplicated error would arrive as an unhandled async error, which
      // fails the test — so let the queue drain before it ends.
      await pumpEventQueue();
    });

    test('does not leak a rejected run as an unhandled async error', () async {
      final uncaught = <Object>[];

      await runZonedGuarded(
        () async {
          final seen = <Object>[];
          // Only one caller listens, so any second copy of the error has
          // nowhere to go but the zone.
          await call
              .run(() async => throw StateError('body exploded'))
              .then<void>((_) {}, onError: seen.add);
          await pumpEventQueue();

          expect(seen, hasLength(1));
        },
        (error, stackTrace) => uncaught.add(error),
      );

      expect(uncaught, isEmpty);
    });

    test('a body that throws synchronously rejects and frees the slot',
        () async {
      final failure = StateError('body exploded');
      // An unguarded body would throw out of `run` itself, right here.
      final result = call.run(() => throw failure);

      await expectLater(result, throwsA(same(failure)));
      expect(await call.run(() async => 1), 1);
    });
  });

  group('invalidate', () {
    test('makes the next caller start a fresh run', () async {
      final gate = Completer<int>();
      var calls = 0;
      final first = call.run(() {
        calls++;
        return gate.future;
      });

      call.invalidate();
      final second = call.run(() async => ++calls);

      expect(identical(first, second), isFalse);
      expect(await second, 2);

      gate.complete(1);
      expect(await first, 1);
    });

    test('still settles the callers already waiting on the old run', () async {
      final gate = Completer<int>();
      final first = call.run(() => gate.future);
      final joined = call.run(() async => -1);

      call.invalidate();
      gate.complete(7);

      expect(await first, 7);
      expect(await joined, 7);
    });

    test('an invalidated run does not free the slot the new run took',
        () async {
      final gate = Completer<int>();
      final first = call.run(() => gate.future);

      call.invalidate();
      final blocker = Completer<int>();
      final second = call.run(() => blocker.future);

      // The first run settles while the second still holds the slot, so a
      // third caller must join the second rather than start over.
      gate.complete(1);
      await first;

      expect(identical(call.run(() async => -1), second), isTrue);
      blocker.complete(2);
      expect(await second, 2);
    });

    test('is a no-op when nothing is running', () async {
      call.invalidate();
      expect(await call.run(() async => 1), 1);
    });
  });
}
