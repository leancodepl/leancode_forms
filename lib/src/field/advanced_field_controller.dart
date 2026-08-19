import 'dart:async';

import 'package:advanced_forms/src/field/advanced_field_state.dart';
import 'package:advanced_forms/src/utils/shared_call.dart';
import 'package:advanced_forms/src/validation_mode.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
// Older Flutter versions need this import
// ignore: unnecessary_import
import 'package:meta/meta.dart';

part 'async_validation.dart';
part 'focus_handling.dart';
part 'validation_round.dart';

/// A validate function receiving the current value and returning an error code.
/// If null is returned, the value is considered valid.
typedef Validator<T, E extends Object> = E? Function(T);

FieldStatus _statusFromErrors(Object? validationError, Object? asyncError) =>
    validationError == null && asyncError == null
        ? FieldStatus.valid
        : FieldStatus.invalid;

/// A single form field which can be validated. [T] is the held value, [E] the
/// error code; [E] cannot be nullable, so lack of an error is unambiguous.
///
/// Validation follows three rules. [AdvancedFieldState.validationMode] decides
/// which events make the field validate itself; a round runs the sync validator
/// first, the async one only if sync passed. A field the user has never edited
/// validates nothing on its own. [validate] ignores the mode.
// Behaviour is split across the part files:
// - focus in the _FocusHandling mixin,
// - async rounds in the _Rounds extension type over this class.
// Round state stays on the class — an extension type holds none.
class AdvancedFieldController<T, E extends Object>
    with ChangeNotifier, _FocusHandling
    implements ValueListenable<AdvancedFieldState<T, E>> {
  /// Creates a new [AdvancedFieldController] with an initial value and a
  /// validator. Pass [asyncValidation] to also validate asynchronously.
  ///
  /// Pass [focusNode] to bind a node you own; its lifecycle stays yours, so
  /// this field never disposes it. Without one the field makes and owns its
  /// own — see [AdvancedFieldController.focusNode].
  AdvancedFieldController({
    required T initialValue,
    Validator<T, E>? validator,
    AsyncValidation<T, E>? asyncValidation,
    FocusNode? focusNode,
    this.name,
  })  : _value = AdvancedFieldState<T, E>(value: initialValue),
        _initialValue = initialValue,
        _validator = validator ?? ((_) => null),
        _asyncValidation = asyncValidation,
        _suppliedFocusNode = focusNode {
    _bindSuppliedFocusNode();
  }

  /// Optional label used in reported errors and as the `FocusNode` debug label.
  /// Not used for identity — fields are identified by reference.
  @override
  final String? name;

  @override
  final FocusNode? _suppliedFocusNode;

  AdvancedFieldState<T, E> _value;

  @override
  AdvancedFieldState<T, E> get value => _value;

  /// The current value — shortcut for `value.value`.
  T get fieldValue => _value.value;

  /// The current error — shortcut for `value.error`.
  E? get error => _value.error;

  bool _isDisposed = false;

  /// Whether this controller has been disposed. Once true it stays true.
  @override
  bool get isDisposed => _isDisposed;

  /// Details behind [FieldStatus.failedValidation], or null when the field is
  /// not in that state. Diagnostic only.
  AsyncValidationFailure? get lastFailure =>
      _value.isFailedValidation ? _lastFailure : null;

  // Internals with no public surface.
  final T _initialValue;
  final Validator<T, E> _validator;
  final AsyncValidation<T, E>? _asyncValidation;
  final _validateCall = SharedCall<bool>();
  VoidCallback? _fieldsSubscriptionCleanup;
  _ValidationRound<T, E>? _currentRound;
  AsyncValidationFailure? _lastFailure;

  // Whether a settled verdict still describes the value the field holds.
  bool _hasVerdict = false;

  // Entry point for async validation on this field.
  _Rounds<T, E> get _rounds => _Rounds(this);

  // Set when the user first edits the field. Only reset() clears it.
  // While false, the field skips validation triggered by its mode.
  bool _hasInteracted = false;

  // null: follow the form's mode. Non-null: this field manages its own.
  ValidationMode? _ownMode;

  // What the form last said about its validation switch. Outranks every mode.
  bool _parentEnabled = true;

  /// Sets a new [newValue] on behalf of the user. A no-op on a read-only field
  /// unless [force] is true.
  ///
  /// Both errors are cleared, because they described the old value. This is
  /// what counts as the user editing the field — see [prefill] for a write the
  /// user did not make.
  ///
  /// Throws a [StateError] if this field has already been disposed.
  void setValue(T newValue, {bool force = false}) {
    if (isDisposed) {
      throw StateError(
        'Cannot set a value on a disposed AdvancedFieldController.',
      );
    }
    if (_value.readOnly && !force) {
      return;
    }

    _hasInteracted = true;
    _rounds.invalidate();

    if (!_shouldValidateOn(ValidationEvent.valueChanged)) {
      _clearTo(newValue);
      return;
    }

    final validationError = _validator(newValue);
    if (validationError != null || _asyncValidation == null) {
      _setState(
        _value.copyWithNullable(
          value: newValue,
          validationError: validationError,
          asyncError: null,
          status: _statusFromErrors(validationError, null),
        ),
      );
      return;
    }

    _rounds.begin(newValue, debounced: true);
  }

  /// Returns `null` if the field is readonly, otherwise [setValue]. Useful
  /// where a null `onChange` is what disables a widget.
  ValueSetter<T>? getValueSetter() => _value.readOnly ? null : setValue;

  /// Writes [newValue] on behalf of the program, not the user. A no-op on a
  /// read-only field unless [force] is true.
  ///
  /// Both errors are cleared and nothing validates, in any mode: unlike
  /// [setValue] this does not count as the user having edited the field.
  void prefill(T newValue, {bool force = false}) {
    if (_value.readOnly && !force) {
      return;
    }

    _rounds.invalidate();
    _clearTo(newValue);
  }

  /// Called when focus moves away from the field. This is what
  /// [ValidationMode.onUnfocus] reacts to. With [focusNode] bound, focus loss
  /// calls this for you; pickers and dropdowns must call it themselves. Runs pending debounce immediately and
  /// validates read-only fields, same as [validate].
  @override
  Future<void> handleUnfocus() async {
    // User left the field — finish any debounced validation now.
    // Only onUserInteraction mode debounces validation.
    _rounds.flushDebounce();

    if (!_shouldValidateOn(ValidationEvent.unfocus)) {
      return;
    }

    // Caught here, so a throwing validator cannot escape into the zone of
    // whoever moved the focus.
    try {
      await validate();
    } catch (error, stackTrace) {
      _report(name, 'validating after focus loss', error, stackTrace);
    }
  }

  /// Sets a new [error] on [AdvancedFieldState.validationError]. Passing null
  /// clears it and the status follows.
  ///
  /// Aborts the live round so it cannot erase the pushed error. The verdict
  /// survives: the value did not change. Passing null also discards a
  /// [FieldStatus.failedValidation] status, unlike [markReadOnly].
  void setError(E? error) {
    _rounds.abort();
    _setState(
      _value.copyWithNullable(
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
  Future<bool> validate() => _isDisposed
      ? Future.value(false)
      : _validateCall.run(_rounds.runValidate);

  /// Gives this field its own validation mode, ignoring the form's from now on.
  /// Cannot be undone — the field no longer follows form mode changes.
  /// Does not trigger validation by itself.
  void setValidationMode(ValidationMode mode) {
    _ownMode = mode;
    _publishValidationMode(_parentEnabled ? mode : ValidationMode.manual);
  }

  /// Applies the form's mode and enabled flag; this field's own mode wins if set.
  @internal
  void applyValidationMode(ValidationMode mode, {required bool enabled}) {
    _parentEnabled = enabled;
    _publishValidationMode(
      enabled ? (_ownMode ?? mode) : ValidationMode.manual,
    );
  }

  // No-op when mode is unchanged — forms send it again on every registration.
  // When it changes, cancel any validation still running under the old mode.
  void _publishValidationMode(ValidationMode mode) {
    if (mode == _value.validationMode) {
      return;
    }

    _rounds.abort();
    _setState(
      _value.copyWithNullable(
        validationMode: mode,
        status: _statusAfterAbort,
      ),
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
    _rounds.abort();
    _setState(
      _value.copyWithNullable(readOnly: true, status: _statusAfterAbort),
    );
  }

  /// Allows further changes of value [T].
  void unmarkReadOnly() => _setState(
        _value.copyWithNullable(
          readOnly: false,
          status: _statusAfter(_value.validationError),
        ),
      );

  /// Clears both errors, and drops the verdict since the code it produced is
  /// being erased. This is how to invalidate an async check whose answer depends
  /// on state outside the value.
  void clearErrors() {
    _rounds.invalidate();
    _clearTo(_value.value);
  }

  /// Resets the field to its initial value, clearing both errors, the status,
  /// the verdict and [lastFailure]. Keeps [AdvancedFieldState.validationMode]
  /// and [AdvancedFieldState.readOnly].
  ///
  /// The field counts as untouched again.
  void reset() {
    _rounds.invalidate();
    _hasInteracted = false;
    _clearTo(_initialValue);
  }

  /// Subscribes to the [fields] and re-runs this field's **sync** validator
  /// whenever any of their values change. Replaces any earlier subscription.
  ///
  /// The async validator is not re-run: this field's value did not change, so
  /// its verdict stands. While this field's gate is closed nothing happens at
  /// all. With it open [AdvancedFieldState.validationError] is rewritten, so a
  /// code pushed there with [setError] gives way to whatever the validator now
  /// returns.
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

  /// Re-runs the **sync** validator when the gate allows it, nothing otherwise.
  ///
  /// This is what a dependency's change means for this field: its own value did
  /// not change, so [AdvancedFieldState.asyncError], the verdict and
  /// [lastFailure] are left alone and no async check is owed. Read-only fields
  /// are included — freezing a value does not stop its rule from being
  /// re-evaluated.
  ///
  /// The mechanism behind [subscribeToFields] and the form's `revalidateSync`.
  void revalidateSync() {
    if (_shouldValidateOn(ValidationEvent.dependencyChanged)) {
      _setSyncError(_validator(_value.value));
    }
  }

  /// Test-only seeder for state combinations the pipeline never produces, such
  /// as an [AdvancedFieldState.asyncError] with no round having run. Carries no
  /// verdict, so [validate] re-runs the async validator for it.
  @visibleForTesting
  void debugSetState(AdvancedFieldState<T, E> state) {
    _rounds.invalidate();
    _setState(state);
  }

  @override
  void dispose() {
    _isDisposed = true;
    _rounds.abort();
    _fieldsSubscriptionCleanup?.call();
    _fieldsSubscriptionCleanup = null;
    _disposeFocusNode();
    super.dispose();
  }

  bool _shouldValidateOn(ValidationEvent event) => validatesOn(
        event,
        mode: _value.validationMode,
        hasInteracted: _hasInteracted,
      );

  // Publishes [value] with both errors cleared and the given status.
  void _clearTo(T value, {FieldStatus status = FieldStatus.valid}) => _setState(
        _value.copyWithNullable(
          value: value,
          validationError: null,
          asyncError: null,
          status: status,
        ),
      );

  // Writes `validationError`, leaving the status to [_statusAfter].
  void _setSyncError(E? syncError) => _setState(
        _value.copyWithNullable(
          validationError: syncError,
          status: _statusAfter(syncError),
        ),
      );

  // After abort: keep failedValidation so submit stays blocked; else use errors.
  // After sync write: keep current status if validation is running or failed.
  FieldStatus get _statusAfterAbort => _value.isFailedValidation
      ? FieldStatus.failedValidation
      : _statusFromErrors(_value.validationError, _value.asyncError);

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
