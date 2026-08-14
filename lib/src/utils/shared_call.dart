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
    final future = completer.future;
    _inFlight = future;

    // Only clears its own run: [invalidate] may already have replaced it.
    void clear() {
      if (identical(_inFlight, future)) {
        _inFlight = null;
      }
    }

    // Clear in callbacks (not whenComplete) to avoid an unhandled async error.
    // Future.sync lets sync throws reject without leaving _inFlight set forever.
    Future.sync(body).then(
      (value) {
        clear();
        completer.complete(value);
      },
      onError: (Object error, StackTrace stackTrace) {
        clear();
        completer.completeError(error, stackTrace);
      },
    );

    return future;
  }

  /// Drops the run in flight, so the next [run] starts a fresh one instead of
  /// joining an answer that was reached under conditions that no longer hold.
  /// Whoever already awaited the dropped run still gets its result.
  void invalidate() => _inFlight = null;
}
