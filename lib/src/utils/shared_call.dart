import 'dart:async';

import 'package:meta/meta.dart';

/// One run of an operation, shared by everyone who asks for it while it is
/// still going — so a double-tapped submit button cannot start two validation
/// passes.
@internal
class SharedCall<T> {
  Future<T>? _inFlight;

  /// The run currently in flight, or null when nothing is running.
  Future<T>? get inFlight => _inFlight;

  /// Returns the run already in flight, or starts [body] and holds onto it.
  /// All callers of one run get the same future.
  Future<T> run(Future<T> Function() body) {
    if (_inFlight case final inFlight?) {
      return inFlight;
    }

    final completer = Completer<T>();
    final future = _inFlight = completer.future;
    // Only this run may clear the slot: [invalidate] may have replaced it, and
    // clearing then would drop a newer run's future.
    void settle() {
      if (identical(_inFlight, future)) {
        _inFlight = null;
      }
    }

    // Clear in callbacks (not whenComplete) to avoid an unhandled async error.
    // Future.sync lets sync throws reject without leaving _inFlight set forever.
    Future.sync(body).then(
      (value) {
        settle();
        completer.complete(value);
      },
      onError: (Object error, StackTrace stackTrace) {
        settle();
        completer.completeError(error, stackTrace);
      },
    );

    return completer.future;
  }

  /// Stops the run in flight from being shared with later callers, so the next
  /// [run] starts a fresh one. Callers already waiting still get the answer the
  /// dropped run produces — it was computed under what they asked for.
  ///
  /// This is what a settings change owes: an answer worked out under the old
  /// settings must not be handed to someone asking under the new ones.
  void invalidate() => _inFlight = null;
}
