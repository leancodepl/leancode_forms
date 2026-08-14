import 'dart:async';

import 'package:meta/meta.dart';

/// One run of an operation, shared by everyone who asks for it while it is
/// still going — so a double-tapped submit button cannot start two validation
/// passes.
@internal
class SharedCall<T> {
  Completer<T>? _inFlight;

  /// Returns the run already in flight, or starts [body] and holds onto it.
  /// All callers of one run get the same future.
  Future<T> run(Future<T> Function() body) {
    if (_inFlight case final inFlight?) {
      return inFlight.future;
    }

    final completer = Completer<T>();
    _inFlight = completer;
    // Clear in callbacks (not whenComplete) to avoid an unhandled async error.
    // Future.sync lets sync throws reject without leaving _inFlight set forever.
    Future.sync(body).then(
      (value) {
        _clear(completer);
        completer.complete(value);
      },
      onError: (Object error, StackTrace stackTrace) {
        _clear(completer);
        completer.completeError(error, stackTrace);
      },
    );

    return completer.future;
  }

  /// Frees the slot without settling the run in it, so the next caller starts a
  /// fresh run rather than joining one whose answer no longer applies. The
  /// callers already waiting still get the old run's result.
  void invalidate() => _inFlight = null;

  // Only the run that still owns the slot may free it: [invalidate] may have
  // given the slot to a newer run in the meantime.
  void _clear(Completer<T> completer) {
    if (identical(_inFlight, completer)) {
      _inFlight = null;
    }
  }
}
