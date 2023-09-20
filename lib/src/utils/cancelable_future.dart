/// A [CancelableFuture] is a [Future] that can be cancelled.
class CancelableFuture<T> {
  /// Creates a new [CancelableFuture].
  CancelableFuture({
    required Future<T> future,
    required void Function(T) onComplete,
  }) {
    future.then((value) {
      if (!_cancelled) {
        onComplete(value);
      }
    });
  }
  bool _cancelled = false;

  /// Cancels the future.
  void cancel() {
    _cancelled = true;
  }
}
