import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:leancode_forms/src/field/validation_mode.dart';
import 'package:leancode_forms/src/utils/shared_call.dart';

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
/// Validation follows three rules. [AdvancedFieldState.mode] says which events
/// make the field validate itself; a field the user has never edited validates
/// nothing on its own whatever the mode says; and a round runs the sync
/// validator first, the async one only if sync passed. [validate] validates on
/// demand, whatever the mode says.
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

  // What this field was last told to run under. Kept whole, rather than reduced
  // to `_value.mode`, so that a mode set while the subtree is switched off is
  // still there when it is switched back on. Read only through
  // [ValidationSettingsInheritance.fieldMode] in [_apply]: the gate must have
  // one input, not two.
  ValidationSettings _settings = defaultValidationSettings;

  // One-way: once this field manages its own mode, a form's mode never
  // replaces it again.
  bool _hasOwnMode = false;

  // The interaction guarantee. Set by [setValue] and by nothing else, cleared
  // only by [reset]. Nothing in the pipeline can unset it, so it cannot disarm
  // itself halfway through a repair.
  bool _hasInteracted = false;

  FocusNode? _focusNode;
  bool _hadFocus = false;
  bool _warnedUnboundFocusNode = false;

  /// Sets a new [newValue] as the user's own edit. A no-op on a read-only field
  /// unless [force] is true.
  ///
  /// Both errors are cleared, because they described the old value. This is
  /// also what arms the field: from here on it validates itself on the events
  /// its [AdvancedFieldState.mode] names. Use [prefill] to write a value
  /// without that.
  void setValue(T newValue, {bool force = false}) {
    if (_value.readOnly && !force) {
      return;
    }

    _hasInteracted = true;
    _warnUnboundFocusNode();
    _write(newValue, validate: _validatesOn(ValidationEvent.valueChanged));
  }

  /// Writes [newValue] on the app's behalf — a value fetched from a profile, a
  /// draft restored from storage. A no-op on a read-only field unless [force]
  /// is true.
  ///
  /// Both errors are cleared and nothing validates, in any mode. The user has
  /// not edited this field, so it stays quiet until they do; [validate] is what
  /// checks a prefilled value.
  void prefill(T newValue, {bool force = false}) {
    if (_value.readOnly && !force) {
      return;
    }

    _write(newValue, validate: false);
  }

  void _write(T newValue, {required bool validate}) {
    _abortRound();
    _hasVerdict = false;

    if (!validate) {
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

  /// Sets when this field validates itself, whatever its form says. The field
  /// keeps this mode when the form's mode changes later.
  ///
  /// A form with validation switched off still outranks it: every field in that
  /// subtree runs as [ValidationMode.disabled] until it is switched back on.
  ///
  /// Changing the mode validates nothing by itself, and drops validation the
  /// old mode started. There is no way back to following the form; call this
  /// again with the form's current mode to match it.
  void setValidationMode(ValidationMode mode) {
    _hasOwnMode = true;
    _apply(_settings.overriddenBy(mode));
  }

  /// Applies the settings of the form this field belongs to. A mode set by
  /// [setValidationMode] wins over `settings.mode`; `settings.enabled` applies
  /// either way.
  @internal
  void applyValidationSettings(ValidationSettings settings) =>
      _apply(_hasOwnMode ? settings.overriddenBy(_settings.mode) : settings);

  /// Reports that the field lost focus — the event, not a request to drop
  /// focus.
  ///
  /// A widget bound to [focusNode] gets this for free. Call it by hand for a
  /// picker or a dropdown that manages focus its own way.
  ///
  /// A round still waiting out its debounce runs at once, in any mode: leaving
  /// the field means the typing is over. Then, under
  /// [ValidationMode.onUnfocus], the field validates — reusing a settled
  /// verdict, so tabbing in and out of an unchanged field costs nothing.
  void handleUnfocus() {
    if (_isDisposed) {
      return;
    }

    if (_currentRound case final round? when round.isDebouncing) {
      unawaited(_run(round));
    }

    if (!_validatesOn(ValidationEvent.unfocus)) {
      return;
    }

    // Nobody is awaiting this, so a throwing validator would escape as an
    // unhandled async error.
    validate().onError((error, stackTrace) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error ?? 'null',
          stack: stackTrace,
          library: 'leancode_forms',
          context: ErrorDescription(
            'while validating ${name ?? 'a field'} on unfocus',
          ),
        ),
      );
      return false;
    }).ignore();
  }

  /// The [FocusNode] bound to this field, created on first use and disposed
  /// with the controller.
  ///
  /// Bind it in the widget for [ValidationMode.onUnfocus] to work: losing focus
  /// on a node nobody holds is not something that can happen, so the mode would
  /// do nothing.
  ///
  /// Throws a [StateError] if the controller has been disposed.
  FocusNode get focusNode {
    if (_isDisposed) {
      throw StateError(
        'Cannot use the focusNode of a disposed AdvancedFieldController.',
      );
    }

    return _focusNode ??= FocusNode(
      debugLabel:
          'AdvancedFieldController${name?.isNotEmpty ?? false ? '($name)' : ''}',
    )..addListener(_handleFocusChanged);
  }

  /// Requests focus for the field via [focusNode]. A no-op once the controller
  /// has been disposed, so `focus()` after a teardown is safe.
  void focus() {
    if (_isDisposed) {
      return;
    }

    focusNode.requestFocus();
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
      _value._copyWithNullable(
        readOnly: true,
        status: _statusKeepingFailure,
      ),
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
  /// the verdict and [lastFailure]. The field counts as untouched again, so it
  /// stays quiet until the user edits it. Keeps [AdvancedFieldState.mode] and
  /// [AdvancedFieldState.readOnly].
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
  /// its verdict stands. A field the user has never edited, or one whose mode
  /// is [ValidationMode.disabled], does nothing at all. Otherwise
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

  /// Re-runs the **sync** validator if this field's mode says a dependency's
  /// change is its business, and nothing otherwise.
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
    if (_validatesOn(ValidationEvent.dependencyChanged)) {
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

  bool _validatesOn(ValidationEvent event) => validatesOn(
        event,
        mode: _value.mode,
        hasInteracted: _hasInteracted,
      );

  // The only writer of the effective mode.
  void _apply(ValidationSettings settings) {
    // Stored before the comparison: a mode change under `enabled: false` leaves
    // the effective mode `disabled`, but must still be what takes effect when
    // the switch comes back on.
    _settings = settings;

    final mode = settings.fieldMode;
    // Idempotent: re-registering re-broadcasts, and aborting on a no-op would
    // kill validation already in flight.
    if (mode == _value.mode) {
      return;
    }

    // The work the old mode started must not land under the new one.
    _abortRound();
    _setState(
      _value._copyWithNullable(mode: mode, status: _statusKeepingFailure),
    );
  }

  void _handleFocusChanged() {
    if (_focusNode?.hasFocus ?? false) {
      _hadFocus = true;
      return;
    }
    if (!_hadFocus) {
      return;
    }

    _hadFocus = false;
    handleUnfocus();
  }

  // [ValidationMode.onUnfocus] cannot report anything when no widget holds the
  // node, and nothing throws to say so. An edit is what makes a blur check
  // owed, and by then the widget that should have bound the node exists.
  void _warnUnboundFocusNode() {
    assert(
      () {
        if (_value.mode == ValidationMode.onUnfocus &&
            _focusNode == null &&
            !_warnedUnboundFocusNode) {
          _warnedUnboundFocusNode = true;
          debugPrint(
            'leancode_forms: ${name ?? 'a field'} runs in '
            'ValidationMode.onUnfocus but nothing has read its focusNode, so '
            'it can never validate. Bind field.focusNode in the widget, or '
            'call field.handleUnfocus() yourself.',
          );
        }
        return true;
      }(),
      '',
    );
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
      return _report(await live.done);
    }

    if (_hasVerdict) {
      return _value.isValid;
    }

    return _report(await _beginRound(_value.value, debounced: false).done);
  }

  // Turns the outcome of a round into what [validate] returns.
  bool _report(bool notSuperseded) =>
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

  // A live or failed round owns the status, so it is carried through. A settled
  // field re-derives it from both errors, which is how a state seeded with a
  // status that disagrees with them gets corrected.
  FieldStatus _statusAfter(E? syncError) =>
      _value.isInProgress || _value.isFailedValidation
          ? _value.status
          : _statusFromErrors(syncError, _value.asyncError);

  // What the status is once a round has been dropped: the errors on record,
  // except that a failed round still blocks submit until something re-runs it.
  FieldStatus get _statusKeepingFailure => _value.isFailedValidation
      ? FieldStatus.failedValidation
      : _statusFromErrors(_value.validationError, _value.asyncError);

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
