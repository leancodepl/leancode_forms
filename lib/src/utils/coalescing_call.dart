import 'dart:async';

/// Holds the run of an operation that must never be in flight twice at once,
/// so a double-tapped submit button cannot start two validation passes.
class CoalescingCall<T> {
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
    _inFlight = completer.future;
    // The clear needs no identity check: this callback is the first listener
    // registered on the future, so it runs before any awaiting caller can
    // resume and start a second run for it to clobber.
    unawaited(completer.future.whenComplete(() => _inFlight = null));
    // `body` runs after the holder is set, so code re-entering synchronously
    // from inside it coalesces onto this run.
    body().then(completer.complete, onError: completer.completeError);

    return completer.future;
  }
}
