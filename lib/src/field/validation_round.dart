part of 'advanced_field_controller.dart';

typedef _Result<E extends Object> = ({
  E? verdict,
  AsyncValidationFailure? failure,
});

// Driving the async side of validation: starting a round, letting it settle,
// and deciding whose answer is allowed to reach the state. The round's own
// state lives on the controller — see `_currentRound`, `_hasVerdict` and
// `_lastFailure`.
extension _ValidationRounds<T, E extends Object>
    on AdvancedFieldController<T, E> {
  Future<bool> _runValidate() async {
    final validationError = _validator(_value.value);

    if (validationError != null) {
      // No async check is owed for a value already known bad. The
      // verdict survives — the value did not change.
      _abortRound();
      _setState(
        _value._copyWithNullable(
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
      return _roundResult(await live.done);
    }

    if (_hasVerdict) {
      return _value.isValid;
    }

    return _roundResult(await _beginRound(_value.value, debounced: false).done);
  }

  // Turns the outcome of a round into what [validate] returns.
  bool _roundResult(bool notSuperseded) =>
      !_isDisposed && notSuperseded && _value.isValid;

  _ValidationRound<T, E> _beginRound(T value, {required bool debounced}) {
    final round = _ValidationRound<T, E>(value: value);
    _currentRound = round;

    final asyncValidation = _asyncValidation;
    if (debounced && asyncValidation != null) {
      // The timer starts before any state is published, so a listener
      // re-entering during the `pending` notification cannot orphan it.
      round.startDebounce(asyncValidation.debounce, () => _run(round));
      _lastFailure = null;
      _clearTo(value, status: FieldStatus.pending);
    } else {
      unawaited(_run(round));
    }

    return round;
  }

  Future<void> _run(_ValidationRound<T, E> round) async {
    final asyncValidation = _asyncValidation;
    // A round only ever starts when there is an async validator, so the null
    // case is unreachable rather than handled.
    if (asyncValidation == null || !identical(_currentRound, round)) {
      return;
    }
    round.cancelTimers();

    _lastFailure = null;
    _setState(
      _value._copyWithNullable(
        asyncError: null,
        status: FieldStatus.validating,
      ),
    );
    if (!identical(_currentRound, round)) {
      return;
    }

    final result = await round.runValidator(asyncValidation);
    round.cancelTimers();

    // `_currentRound` no longer points at this round, so a newer round replaced
    // it or `_abortRound` dropped it. Its answer must not be written.
    if (!identical(_currentRound, round)) {
      return;
    }
    _currentRound = null;

    final failure = result.failure;
    if (failure == null) {
      _hasVerdict = true;
      _setState(
        _value._copyWithNullable(
          asyncError: result.verdict,
          status: _statusFromErrors(_value.validationError, result.verdict),
        ),
      );
      round.finish();
      return;
    }

    // A failed round records no verdict, so the next `validate()` re-runs it.
    _lastFailure = failure;
    _setState(
      _value._copyWithNullable(
        asyncError: asyncValidation._mapFailure(failure, name),
        status: FieldStatus.failedValidation,
      ),
    );
    round.finish();
    unawaited(asyncValidation._reportFailure(failure, name));
  }

  // `_currentRound` is the liveness token: a round that is no longer it can
  // never write state again. Cancelling stops anything awaiting it from hanging.
  void _abortRound() {
    _lastFailure = null;
    _currentRound?.cancel();
    _currentRound = null;
  }
}

// One validation pass over one value, from the debounce to the answer. Settles
// exactly once, so a cancelled round is a completed round.
class _ValidationRound<T, E extends Object> {
  _ValidationRound({required this.value});

  final T value;

  final Completer<bool> _done = Completer<bool>();
  Timer? _debounceTimer;
  Timer? _timeoutTimer;

  // False if the round was superseded, cancelled or disposed; true otherwise,
  // including for a round that failed. A failure is caught by the status, not
  // here.
  Future<bool> get done => _done.future;

  bool get isDebouncing => _debounceTimer?.isActive ?? false;

  void startDebounce(Duration delay, void Function() run) =>
      _debounceTimer = Timer(delay, run);

  // `Future.any` handles and drops the loser's error, so a validator that
  // throws after the timeout cannot escape as an unhandled async error.
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
      // `Future.sync` turns a synchronous throw into a rejected future, so the
      // sync and async failure paths end up in the same `catch` below.
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

  // Cancels both timers: the debounce and, once [runValidator] has set it, the
  // timeout.
  void cancelTimers() {
    _debounceTimer?.cancel();
    _debounceTimer = null;
    _timeoutTimer?.cancel();
    _timeoutTimer = null;
  }

  // The round ran to completion, whether the validator passed or failed.
  void finish() => _complete(true);

  // The round was superseded, aborted or disposed, so it never had its say.
  void cancel() => _complete(false);

  void _complete(bool notSuperseded) {
    cancelTimers();
    if (!_done.isCompleted) {
      _done.complete(notSuperseded);
    }
  }
}
