/// A [CancelableFuture] is a [Future] that can be cancelled.
class CancelableFuture<T> {
  /// Creates a new [CancelableFuture].
  ///
  /// Exactly one of [onComplete] and [onError] runs, unless [cancel] is called
  /// first, in which case neither runs. [onError] is required so that a failing
  /// [future] cannot be silently swallowed.
  CancelableFuture({
    required Future<T> future,
    required void Function(T) onComplete,
    required void Function(Object error, StackTrace stackTrace) onError,
  }) {
    future.then(
      (value) {
        if (!_cancelled) {
          onComplete(value);
        }
      },
      onError: (Object error, StackTrace stackTrace) {
        if (!_cancelled) {
          onError(error, stackTrace);
        }
      },
    );
  }
  bool _cancelled = false;

  /// Cancels the future.
  void cancel() {
    _cancelled = true;
  }
}
