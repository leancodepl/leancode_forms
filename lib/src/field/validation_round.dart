part of 'advanced_field_controller.dart';

typedef _Result<E extends Object> = ({
  E? verdict,
  AsyncValidationFailure? failure,
});

// Runs async validation: starts a pass, waits for the result, and writes it
// only if still current.
extension type _Rounds<T, E extends Object>(
        AdvancedFieldController<T, E> _field)
    implements AdvancedFieldController<T, E> {
  /// Runs the sync validator, then the async one when it is owed, and reports
  /// whether the field ended up valid. Backs [AdvancedFieldController.validate].
  Future<bool> runValidate() async {
    final validationError = _validator(_value.value);

    if (validationError != null) {
      // Sync error already failed — skip async. Keep any existing async verdict
      // since the value did not change.
      abort();
      _setState(
        _value.copyWithNullable(
          validationError: validationError,
          status: FieldStatus.invalid,
        ),
      );
      return false;
    }

    _setSyncError(null);

    if (_asyncValidation == null) {
      return _value.isValid;
    }

    final live = _currentRound;
    if (live != null) {
      if (live.isDebouncing) {
        unawaited(_run(live));
      }
      return _result(await live.done);
    }

    if (_hasVerdict) {
      return _value.isValid;
    }

    return _result(await begin(_value.value, debounced: false).done);
  }

  /// Starts a round for [value]. With [debounced] the field goes to
  /// [FieldStatus.pending] and the validator waits out
  /// [AsyncValidation.debounce]; without it the validator runs at once.
  _ValidationRound<T, E> begin(T value, {required bool debounced}) {
    final round = _ValidationRound<T, E>(value: value);
    _currentRound = round;

    final asyncValidation = _asyncValidation;
    if (debounced && asyncValidation != null) {
      // Start the debounce timer before publishing pending state, so a listener
      // triggered by that update cannot start a second timer.
      round.startDebounce(asyncValidation.debounce, () => _run(round));
      _lastFailure = null;
      _clearTo(value, status: FieldStatus.pending);
    } else {
      unawaited(_run(round));
    }

    return round;
  }

  /// Runs a round still waiting out its debounce right now, if there is one.
  /// This is what a focus loss does to a half-typed value.
  void flushDebounce() {
    if (_currentRound case final round? when round.isDebouncing) {
      unawaited(_run(round));
    }
  }

  /// Drops the live round, so it can no longer write state, notify, or report.
  /// Cancelling also unblocks callers waiting on `validate()`. The settled
  /// verdict survives — the value it describes did not change.
  void abort() {
    _lastFailure = null;
    _currentRound?.cancel();
    _currentRound = null;
  }

  /// [abort], and drop the settled verdict with it. This is what a write to the
  /// value means: the last answer no longer describes what the field holds, so
  /// the next `validate()` runs the validator again rather than reusing it.
  void invalidate() {
    abort();
    _hasVerdict = false;
  }

  // Maps this pass's result to what validate() returns.
  bool _result(bool notSuperseded) =>
      !isDisposed && notSuperseded && _value.isValid;

  Future<void> _run(_ValidationRound<T, E> round) async {
    final asyncValidation = _asyncValidation;
    // Rounds only start when an async validator exists — null here is unreachable.
    if (asyncValidation == null || !identical(_currentRound, round)) {
      return;
    }
    round.cancelTimers();

    _lastFailure = null;
    _setState(
      _value.copyWithNullable(
        asyncError: null,
        status: FieldStatus.validating,
      ),
    );
    if (!identical(_currentRound, round)) {
      return;
    }

    final result = await round.runValidator(asyncValidation);
    round.cancelTimers();

    // A newer validation replaced this one, or it was cancelled — don't write
    // a stale result.
    if (!identical(_currentRound, round)) {
      return;
    }
    _currentRound = null;

    final failure = result.failure;
    if (failure == null) {
      _hasVerdict = true;
      _setState(
        _value.copyWithNullable(
          asyncError: result.verdict,
          status: _statusFromErrors(_value.validationError, result.verdict),
        ),
      );
      round.finish();
      return;
    }

    // Validation failed — don't cache a verdict, so the next validate() retries.
    _lastFailure = failure;
    _setState(
      _value.copyWithNullable(
        asyncError: asyncValidation._mapFailure(failure, name),
        status: FieldStatus.failedValidation,
      ),
    );
    round.finish();
    unawaited(asyncValidation._reportFailure(failure, name));
  }
}

// One async validation pass for one value, from debounce through to result.
// Completes exactly once — cancellation counts as completion.
class _ValidationRound<T, E extends Object> {
  _ValidationRound({required this.value});

  final T value;

  final Completer<bool> _done = Completer<bool>();
  Timer? _debounceTimer;
  Timer? _timeoutTimer;

  // false if this pass was replaced or cancelled; true if it finished (even
  // on validator failure — that shows up in field status, not here).
  Future<bool> get done => _done.future;

  bool get isDebouncing => _debounceTimer?.isActive ?? false;

  void startDebounce(Duration delay, void Function() run) =>
      _debounceTimer = Timer(delay, run);

  // Future.any absorbs the losing future's error, so a late throw after
  // timeout does not become an unhandled async error.
  Future<_Result<E>> runValidator(AsyncValidation<T, E> validation) async {
    final timedOut = Completer<E?>();

    if (validation.timeout case final duration?) {
      _timeoutTimer = Timer(
        duration,
        () => timedOut.completeError(
          TimeoutException('Async validation timed out.', duration),
          StackTrace.current,
        ),
      );
    }

    try {
      // Future.sync turns a sync throw into a rejected future, so both paths hit
      // the same catch below.
      final verdict = await Future.any([
        Future.sync(() => validation.validator(value)),
        timedOut.future,
      ]);
      return (verdict: verdict, failure: null);
    } catch (error, stackTrace) {
      return (
        verdict: null,
        failure: AsyncValidationFailure(
          error: error,
          stackTrace: stackTrace,
          timedOut: timedOut.isCompleted,
        ),
      );
    }
  }

  // Stops the debounce timer and the timeout timer (if one was started).
  void cancelTimers() {
    _debounceTimer?.cancel();
    _debounceTimer = null;
    _timeoutTimer?.cancel();
    _timeoutTimer = null;
  }

  // This pass finished — validator passed or failed.
  void finish() => _complete(true);

  // This pass was replaced or cancelled before it could update the field.
  void cancel() => _complete(false);

  void _complete(bool notSuperseded) {
    cancelTimers();
    if (!_done.isCompleted) {
      _done.complete(notSuperseded);
    }
  }
}
