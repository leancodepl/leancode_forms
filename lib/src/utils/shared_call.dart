import 'dart:async';

/// One run of an operation, shared by everyone who asks for it while it is
/// still going — so a double-tapped submit button cannot start two validation
/// passes.
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
    _inFlight = completer.future;
    // Clear in callbacks (not whenComplete) to avoid an unhandled async error.
    // Future.sync lets sync throws reject without leaving _inFlight set forever.
    Future.sync(body).then(
      (value) {
        _inFlight = null;
        completer.complete(value);
      },
      onError: (Object error, StackTrace stackTrace) {
        _inFlight = null;
        completer.completeError(error, stackTrace);
      },
    );

    return completer.future;
  }
}
