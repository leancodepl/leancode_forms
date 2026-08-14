import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:leancode_forms/src/utils/shared_call.dart';
import 'package:leancode_forms/src/validation_mode.dart';

part 'advanced_field_state.dart';
part 'async_validation.dart';

/// A validate function receiving the current value and returning an error code.
/// If null is returned, the value is considered valid.
typedef Validator<T, E extends Object> = E? Function(T);

typedef _Result<E extends Object> = ({
  E? verdict,
  AsyncValidationFailure? failure,
});

FieldStatus _statusFromErrors(Object? validationError, Object? asyncError) =>
    validationError == null && asyncError == null
        ? FieldStatus.valid
        : FieldStatus.invalid;

/// A single form field which can be validated. [T] is the held value, [E] the
/// error code; [E] cannot be nullable, so lack of an error is unambiguous.
///
/// Validation follows three rules. [AdvancedFieldState.mode] decides which
/// events make the field validate itself, and a round runs the sync validator
/// first, the async one only if sync passed. A field the user has never edited
/// validates nothing on its own, in any mode. [validate] validates on demand,
/// whatever the mode says, and never changes it.
class AdvancedFieldController<T, E extends Object>
    with ChangeNotifier
    implements ValueListenable<AdvancedFieldState<T, E>> {
  /// Creates a new [AdvancedFieldController] with an initial value and a
  /// validator. Pass [asyncValidation] to also validate asynchronously.
  AdvancedFieldController({
    required T initialValue,
    Validator<T, E>? validator,
    AsyncValidation<T, E>? asyncValidation,
    this.name,
  })  : _value = AdvancedFieldState<T, E>(value: initialValue),
        _initialValue = initialValue,
        _validator = validator ?? ((_) => null),
        _asyncValidation = asyncValidation;

  /// Optional label used in reported errors and as the `FocusNode` debug label.
  /// Not used for identity — fields are identified by reference.
  final String? name;

  AdvancedFieldState<T, E> _value;

  @override
  AdvancedFieldState<T, E> get value => _value;

  /// The current value — shortcut for `value.value`.
  T get fieldValue => _value.value;

  /// The current error — shortcut for `value.error`.
  E? get error => _value.error;

  bool _isDisposed = false;

  /// Whether this controller has been disposed. Once true it stays true.
  bool get isDisposed => _isDisposed;

  AsyncValidationFailure? _lastFailure;

  /// Details behind [FieldStatus.failedValidation], or null when the field is
  /// not in that state. Diagnostic only.
  AsyncValidationFailure? get lastFailure =>
      _value.isFailedValidation ? _lastFailure : null;

  // Internals with no public surface.
  final T _initialValue;
  final Validator<T, E> _validator;
  final AsyncValidation<T, E>? _asyncValidation;
  final _validateCall = SharedCall<bool>();
  _ValidationRound<T, E>? _currentRound;
  VoidCallback? _fieldsSubscriptionCleanup;

  // Whether a settled verdict still describes the value the field holds.
  bool _hasVerdict = false;

  // The ticket's guarantee: a field the user has never edited validates nothing
  // on its own. One-way — only `reset()` clears it — so nothing in the pipeline
  // can disarm it halfway through a repair.
  bool _hasInteracted = false;

  // null: follow the form's mode. Non-null: this field manages its own.
  ValidationMode? _ownMode;

  // Whether the form this field belongs to has validation switched on. It
  // outranks every mode, this field's own included.
  bool _formEnabled = true;

  FocusNode? _focusNode;

  // Mirrors `focusNode.hasFocus`, because a `FocusNode` notifies for changes
  // other than focus itself; without it a blur would fire more than once.
  bool _hadFocus = false;

  /// The [FocusNode] bound to this field, created on first use.
  ///
  /// Bind it in the widget for [ValidationMode.onUnfocus] to work — losing
  /// focus is what makes the field validate in that mode. A widget that has no
  /// focus node of its own, such as a picker, calls [handleUnfocus] instead.
  ///
  /// Throws a [StateError] if this field has already been disposed.
  FocusNode get focusNode {
    if (_isDisposed) {
      throw StateError(
        'Cannot use the focusNode of a disposed AdvancedFieldController.',
      );
    }

    return _focusNode ??= FocusNode(
      debugLabel:
          'AdvancedFieldController${name?.isNotEmpty ?? false ? '($name)' : ''}',
    )..addListener(_handleFocusChange);
  }

  /// Requests focus for the field via [focusNode]. A no-op once the controller
  /// has been disposed, so `focus()` after a teardown is safe.
  void focus() {
    if (_isDisposed) {
      return;
    }

    focusNode.requestFocus();
  }

  /// Sets a new [newValue] on behalf of the user. A no-op on a read-only field
  /// unless [force] is true.
  ///
  /// Both errors are cleared, because they described the old value. This is
  /// what counts as the user having edited the field, so it is what arms every
  /// mode. Use [prefill] to write a value the user did not type.
  void setValue(T newValue, {bool force = false}) {
    if (_value.readOnly && !force) {
      return;
    }

    _hasInteracted = true;
    _abortRound();
    _hasVerdict = false;

    if (!validatesOn(
      ValidationEvent.valueChanged,
      mode: _value.mode,
      hasInteracted: _hasInteracted,
    )) {
      _clearTo(newValue);
      return;
    }

    final validationError = _validator(newValue);
    if (validationError != null || _asyncValidation == null) {
      _setState(
        _value._copyWithNullable(
          value: newValue,
          validationError: validationError,
          asyncError: null,
          status: _statusFromErrors(validationError, null),
        ),
      );
      return;
    }

    _beginRound(newValue, debounced: true);
  }

  /// Returns `null` if the field is readonly, otherwise [setValue]. Useful
  /// where a null `onChange` is what disables a widget.
  ValueSetter<T>? getValueSetter() => _value.readOnly ? null : setValue;

  /// Writes [newValue] on behalf of the program, not the user. A no-op on a
  /// read-only field unless [force] is true.
  ///
  /// Both errors are cleared and nothing validates, in any mode. Unlike
  /// [setValue] this does not count as the user having edited the field, so a
  /// form prefilled from a profile fetch does not greet the user with errors.
  /// Only [validate] checks a value written this way.
  void prefill(T newValue, {bool force = false}) {
    if (_value.readOnly && !force) {
      return;
    }

    _abortRound();
    _hasVerdict = false;
    _clearTo(newValue);
  }

  /// Tells the field the user has left it, which is what
  /// [ValidationMode.onUnfocus] validates on.
  ///
  /// Bind [focusNode] in the widget and this is called for you. Call it by hand
  /// from a widget that manages focus itself, such as a picker or a dropdown.
  ///
  /// A round still waiting out its debounce runs at once in every mode, because
  /// leaving the field means typing is over. Beyond that, only a field the user
  /// has edited validates, and only in [ValidationMode.onUnfocus]; a value that
  /// has not changed since its last check reuses that answer, so tabbing in and
  /// out costs no requests. Read-only fields validate too, matching [validate].
  void handleUnfocus() {
    _flushDebounce();

    if (!validatesOn(
      ValidationEvent.unfocus,
      mode: _value.mode,
      hasInteracted: _hasInteracted,
    )) {
      return;
    }

    // Nobody awaits this, so a throwing validator would escape as an unhandled
    // error in the zone instead of reaching the caller.
    unawaited(
      validate().catchError((Object error, StackTrace stackTrace) {
        _report(name, 'validating after focus loss', error, stackTrace);
        return false;
      }),
    );
  }

  /// Sets a new [error] on [AdvancedFieldState.validationError]. Passing null
  /// clears it and the status follows.
  ///
  /// Aborts the live round so it cannot erase the pushed error. The verdict
  /// survives: the value did not change. Passing null also discards a
  /// [FieldStatus.failedValidation] status, unlike [markReadOnly].
  void setError(E? error) {
    _abortRound();
    _setState(
      _value._copyWithNullable(
        validationError: error,
        status: _statusFromErrors(error, _value.asyncError),
      ),
    );
  }

  /// Runs a full validation round on the current value and reports whether the
  /// field ended up [AdvancedFieldState.isValid].
  ///
  /// The sync validator runs first; if it fails, `false` is returned and the
  /// async validator does not run.
  ///
  /// If it passes, exactly one of four things happens, in this order:
  ///
  /// 1. A round still waiting out its debounce is run at once.
  /// 2. An in-flight round is awaited, not restarted.
  /// 3. A verdict that still describes the current value is reused.
  /// 4. Otherwise a round runs immediately — which is also how a failed round
  ///    is retried.
  ///
  /// Calling this again before the first call finishes gives you the same
  /// result; it does not start a second round. A field disposed mid-round
  /// completes `false`.
  Future<bool> validate() =>
      _isDisposed ? Future.value(false) : _validateCall.run(_runValidate);

  /// Sets when this field validates itself, whatever its form's mode says.
  ///
  /// From here on the field manages its own mode: a later change of the form's
  /// mode leaves it alone. There is no way back to following the form — call
  /// this again with the form's current mode to match it.
  ///
  /// A form with validation switched off still silences the field: that switch
  /// outranks every mode, this one included, and the mode set here takes effect
  /// when validation comes back on.
  ///
  /// Changing the mode validates nothing by itself, and drops a round the old
  /// mode started.
  void setValidationMode(ValidationMode mode) {
    _ownMode = mode;
    _applyMode(_formEnabled ? mode : ValidationMode.disabled);
  }

  /// Applies the mode the field's form offers, and whether that form validates
  /// at all. A field with a mode of its own keeps it; [enabled] outranks both.
  @internal
  void applyValidationMode(ValidationMode mode, {required bool enabled}) {
    _formEnabled = enabled;
    _applyMode(enabled ? (_ownMode ?? mode) : ValidationMode.disabled);
  }

  // Publishing the same mode again must cost nothing: a form re-broadcasts on
  // every registration, and aborting here would kill a round in flight.
  void _applyMode(ValidationMode mode) {
    if (mode == _value.mode) {
      return;
    }

    // A round started under the old mode must not land under the new one.
    _abortRound();
    _setState(
      _value._copyWithNullable(mode: mode, status: _statusKeepingFailure),
    );
  }

  /// Prevents further changes of value [T]. [validate] still validates a
  /// read-only field.
  ///
  /// Aborts the live round, so a frozen field does not go on transitioning on
  /// its own. Drops [lastFailure] but keeps a
  /// [FieldStatus.failedValidation] status, so the field still blocks submit; a
  /// round still in progress is dropped and leaves the field valid, so only
  /// [validate] can still catch it.
  void markReadOnly() {
    _abortRound();
    _setState(
      _value._copyWithNullable(readOnly: true, status: _statusKeepingFailure),
    );
  }

  /// Allows further changes of value [T].
  void unmarkReadOnly() => _setState(
        _value._copyWithNullable(
          readOnly: false,
          status: _statusAfter(_value.validationError),
        ),
      );

  /// Clears both errors, and drops the verdict since the code it produced is
  /// being erased. This is how to invalidate an async check whose answer depends
  /// on state outside the value.
  void clearErrors() {
    _abortRound();
    _hasVerdict = false;
    _clearTo(_value.value);
  }

  /// Resets the field to its initial value, clearing both errors, the status,
  /// the verdict and [lastFailure]. Keeps [AdvancedFieldState.mode] and
  /// [AdvancedFieldState.readOnly].
  ///
  /// The field counts as untouched again, so it validates nothing on its own
  /// until the user edits it.
  void reset() {
    _abortRound();
    _hasVerdict = false;
    _hasInteracted = false;
    _clearTo(_initialValue);
  }

  /// Subscribes to the [fields] and re-runs this field's **sync** validator
  /// whenever any of their values change. Replaces any earlier subscription.
  ///
  /// The async validator is not re-run: this field's value did not change, so
  /// its verdict stands. A field the user has never edited, or one in
  /// [ValidationMode.disabled], does nothing at all. Otherwise
  /// [AdvancedFieldState.validationError] is rewritten, so a code pushed there
  /// with [setError] gives way to whatever the validator now returns.
  ///
  /// The subscription is dropped on [dispose]. Throws a [StateError] if this
  /// field has already been disposed — otherwise the listeners it attaches to
  /// the live [fields] would never be removed.
  void subscribeToFields(
    List<AdvancedFieldController<dynamic, dynamic>> fields,
  ) {
    if (_isDisposed) {
      throw StateError(
        'Cannot subscribe a disposed AdvancedFieldController to fields.',
      );
    }

    _fieldsSubscriptionCleanup?.call();

    var lastValues = <dynamic>[for (final f in fields) f.value.value];

    void listener() {
      final values = <dynamic>[for (final f in fields) f.value.value];
      if (listEquals(lastValues, values)) {
        return;
      }
      lastValues = values;
      revalidateSync();
    }

    for (final f in fields) {
      f.addListener(listener);
    }
    _fieldsSubscriptionCleanup = () {
      for (final f in fields) {
        f.removeListener(listener);
      }
    };
  }

  /// Re-runs the **sync** validator if this field's mode and the interaction
  /// guarantee allow it, and nothing otherwise.
  ///
  /// This is what a dependency's change means for this field: its own value did
  /// not change, so [AdvancedFieldState.asyncError], the verdict and
  /// [lastFailure] are left alone and no async check is owed. Read-only fields
  /// are included — freezing a value does not stop its rule from being
  /// re-evaluated.
  ///
  /// The mechanism behind [subscribeToFields] and the form's own
  /// `revalidateSync`. Prefer those: they say *when* to re-run, which is the
  /// part a form actually has to get right.
  void revalidateSync() {
    if (validatesOn(
      ValidationEvent.dependencyChanged,
      mode: _value.mode,
      hasInteracted: _hasInteracted,
    )) {
      _setSyncError(_validator(_value.value));
    }
  }

  /// Test-only seeder for state combinations the pipeline never produces, such
  /// as an [AdvancedFieldState.asyncError] with no round having run. Carries no
  /// verdict, so [validate] re-runs the async validator for it.
  @visibleForTesting
  void debugSetState(AdvancedFieldState<T, E> state) {
    _abortRound();
    _hasVerdict = false;
    _setState(state);
  }

  @override
  void dispose() {
    _isDisposed = true;
    _abortRound();
    _fieldsSubscriptionCleanup?.call();
    _fieldsSubscriptionCleanup = null;
    _focusNode?.dispose();
    _focusNode = null;
    super.dispose();
  }

  void _handleFocusChange() {
    final hasFocus = _focusNode?.hasFocus ?? false;
    if (hasFocus == _hadFocus) {
      return;
    }
    _hadFocus = hasFocus;
    if (!hasFocus) {
      handleUnfocus();
    }
  }

  // Leaving a field means typing is over, so a round still waiting out its
  // debounce runs now. Only `onUserInteraction` can have one waiting.
  void _flushDebounce() {
    if (_currentRound case final round? when round.isDebouncing) {
      unawaited(_run(round));
    }
  }

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

  // Publishes [value] with both errors cleared and the given status.
  void _clearTo(T value, {FieldStatus status = FieldStatus.valid}) => _setState(
        _value._copyWithNullable(
          value: value,
          validationError: null,
          asyncError: null,
          status: status,
        ),
      );

  // Writes `validationError`, leaving the status to [_statusAfter].
  void _setSyncError(E? syncError) => _setState(
        _value._copyWithNullable(
          validationError: syncError,
          status: _statusAfter(syncError),
        ),
      );

  // The status to publish right after a round was aborted: the aborted round no
  // longer owns it, so it is re-derived from both errors, while a failed round's
  // status survives because the field must still block submit.
  FieldStatus get _statusKeepingFailure => _value.isFailedValidation
      ? FieldStatus.failedValidation
      : _statusFromErrors(_value.validationError, _value.asyncError);

  // A live or failed round owns the status, so it is carried through. A settled
  // field re-derives it from both errors, which is how a state seeded with a
  // status that disagrees with them gets corrected.
  FieldStatus _statusAfter(E? syncError) =>
      _value.isInProgress || _value.isFailedValidation
          ? _value.status
          : _statusFromErrors(syncError, _value.asyncError);

  void _setState(AdvancedFieldState<T, E> newValue) {
    if (_isDisposed || newValue == _value) {
      return;
    }
    _value = newValue;
    notifyListeners();
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
