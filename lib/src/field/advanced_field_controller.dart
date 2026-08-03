import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:leancode_forms/src/utils/cancelable_future.dart';

/// A validate function receiving the current value and returning an error code.
/// If null is returned, the value is considered valid.
typedef Validator<T, E extends Object> = E? Function(T);

/// An async validate function receiving the current value and returning an error code.
typedef AsyncValidator<T, E extends Object> = Future<E?> Function(T);

/// Translates an error to a string.
typedef ErrorTranslator<E extends Object> = String Function(E);

/// A single form field which can be validated.
/// Stores the current value, error text, and whether autovalidate is on.
/// [T] is the held value, [E] is the type of an error. [E] cannot be nullable
/// to be able to unambiguously detect lack of errors.
///
/// If autovalidate is true, the validator will be run after each field change.
class AdvancedFieldController<T, E extends Object>
    with ChangeNotifier
    implements ValueListenable<AdvancedFieldState<T, E>> {
  /// Creates a new [AdvancedFieldController] with an initial value and a validator.
  AdvancedFieldController({
    required T initialValue,
    Validator<T, E>? validator,
    AsyncValidator<T, E>? asyncValidator,
    Duration asyncValidationDebounce = const Duration(milliseconds: 300),
    this.name,
  })  : _value = AdvancedFieldState<T, E>(value: initialValue),
        _initialValue = initialValue,
        _validator = validator ?? ((_) => null),
        _asyncValidator = asyncValidator,
        _asyncValidationDebounce = asyncValidationDebounce;

  /// Optional name for the field. Useful for debugging, logging, and
  /// serialization. Not used for identity — fields are still identified by
  /// reference.
  final String? name;

  final T _initialValue;

  final Validator<T, E> _validator;

  final AsyncValidator<T, E>? _asyncValidator;

  final Duration _asyncValidationDebounce;

  AdvancedFieldState<T, E> _value;

  Timer? _debounceTimer;

  CancelableFuture<E?>? _asyncValidationFuture;

  VoidCallback? _fieldsSubscriptionCleanup;

  @override
  AdvancedFieldState<T, E> get value => _value;

  /// The current field value — shortcut for `value.value`.
  ///
  /// Useful in subclasses with composite values, where `value.value.currency`
  /// would otherwise stack up (state -> record -> component).
  T get fieldValue => value.value;

  /// The current error — shortcut for `value.error`
  /// ([AdvancedFieldState.validationError] falling back to
  /// [AdvancedFieldState.asyncError]).
  E? get error => value.error;

  void _setState(AdvancedFieldState<T, E> newValue) {
    if (newValue == _value) {
      return;
    }
    _value = newValue;
    notifyListeners();
  }

  /// Test-only seeder for states the public API can't construct
  /// (notably any state including a non-null [AdvancedFieldState.asyncError],
  /// which only the async-validator pipeline can produce).
  @visibleForTesting
  void debugSetState(AdvancedFieldState<T, E> state) => _setState(state);

  /// Subscribes to the [fields] and revalidates this field whenever any of
  /// their values change. Only fires on value changes — status changes on the
  /// observed fields are ignored.
  void subscribeToFields(
    List<AdvancedFieldController<dynamic, dynamic>> fields,
  ) {
    _fieldsSubscriptionCleanup?.call();

    final lastValues = <dynamic>[for (final f in fields) f.value.value];

    void listener() {
      var changed = false;
      for (var i = 0; i < fields.length; i++) {
        final v = fields[i].value.value;
        if (v != lastValues[i]) {
          lastValues[i] = v;
          changed = true;
        }
      }
      if (changed && value.autovalidate) {
        setValue(value.value);
      }
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

  /// Set a new [newValue]. When [force] is true, [value] is always updated to
  /// a new [newValue]; otherwise if the state is readonly, [setValue] is a
  /// noop.
  void setValue(T newValue, {bool force = false}) {
    if (value.readOnly && !force) {
      return;
    }

    final validationError =
        value.autovalidate ? _validator(newValue) : value.validationError;

    if (validationError == null && _asyncValidator != null) {
      _runAsyncValidator(newValue);
      return;
    }

    _setState(
      value.copyWithNullable(
        value: newValue,
        validationError: validationError,
        status:
            validationError == null ? FieldStatus.valid : FieldStatus.invalid,
      ),
    );
  }

  Future<void> _runAsyncValidator(T newValue) async {
    _debounceTimer?.cancel();
    _asyncValidationFuture?.cancel();

    final completer = Completer<E?>();

    _setState(value.copyWithNullable(value: newValue, status: FieldStatus.pending));

    _debounceTimer = Timer(_asyncValidationDebounce, () async {
      _setState(
        value.copyWithNullable(value: newValue, status: FieldStatus.validating),
      );

      _asyncValidationFuture = CancelableFuture(
        future: _asyncValidator!(newValue),
        onComplete: completer.complete,
      );
    });

    final error = await completer.future;

    _setState(
      value.copyWithNullable(
        value: newValue,
        validationError: null,
        asyncError: error,
        status: error == null ? FieldStatus.valid : FieldStatus.invalid,
      ),
    );
  }

  /// Returns `null` if field is readonly. Otherwise returns [setValue].
  ///
  /// Useful in contexts where setting `null` as the `onChange` callback causes
  /// the field to be disabled.
  ValueSetter<T>? getValueSetter() {
    if (value.readOnly) {
      return null;
    }
    return setValue;
  }

  /// Sets a new [error] and marks the field as invalid.
  void setError(E? error) {
    _setState(
      value.copyWithNullable(
        validationError: error,
        asyncError: null,
        status: FieldStatus.invalid,
      ),
    );
  }

  /// Runs the sync validator. Returns true if there are no errors.
  /// If the validator returns a different error than the current one, the
  /// state is updated.
  bool validate() {
    if (value.asyncError != null || value.isInProgress) {
      return false;
    }

    final error = _validator(value.value);

    if (error != value.validationError) {
      _setState(
        value.copyWithNullable(
          validationError: error,
          status: error == null ? FieldStatus.valid : FieldStatus.invalid,
        ),
      );
    }

    return value.validationError == null;
  }

  /// When autovalidate is true, setting a new value will trigger a validation.
  void setAutovalidate(bool autovalidate) {
    _setState(value.copyWithNullable(autovalidate: autovalidate));
  }

  /// Prevents further changes of value [T].
  void markReadOnly() {
    _setState(value.copyWithNullable(readOnly: true));
  }

  /// Allows further changes of value [T].
  void unmarkReadOnly() {
    _setState(value.copyWithNullable(readOnly: false));
  }

  /// Clears all errors on this field.
  void clearErrors() {
    _setState(
      value.copyWithNullable(
        validationError: null,
        asyncError: null,
        status: FieldStatus.valid,
      ),
    );
  }

  /// Resets the field to its initial value.
  void reset() {
    _setState(AdvancedFieldState(value: _initialValue));
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _asyncValidationFuture?.cancel();
    _fieldsSubscriptionCleanup?.call();
    _fieldsSubscriptionCleanup = null;
    super.dispose();
  }
}

/// The status of a [AdvancedFieldController].
enum FieldStatus {
  /// The field is valid.
  valid,

  /// The field is invalid.
  invalid,

  /// The field is pending validation.
  pending,

  /// The field is being async validated.
  validating,
}

/// An immutable snapshot of an [AdvancedFieldController] — its current value,
/// any validation errors, whether autovalidate and readonly are on, and where
/// validation currently stands.
///
/// Obtain it from [AdvancedFieldController.value], or listen to the controller
/// to be notified whenever it changes.
class AdvancedFieldState<T, E extends Object> {
  /// Creates a new [AdvancedFieldState].
  const AdvancedFieldState({
    required this.value,
    this.validationError,
    this.asyncError,
    this.autovalidate = false,
    this.readOnly = false,
    this.status = FieldStatus.valid,
  });

  /// Returns true if there are no errors.
  bool get isValid => status == FieldStatus.valid;

  /// Returns true if field status is being validated.
  bool get isValidating => status == FieldStatus.validating;

  /// Returns true if field status is pending.
  bool get isPending => status == FieldStatus.pending;

  /// Returns true if field status is pending or validating.
  bool get isInProgress => isPending || isValidating;

  /// Returns true if field status is invalid.
  bool get isInvalid => status == FieldStatus.invalid;

  /// The current value.
  /// Can be set manually by calling [AdvancedFieldController.setValue].
  final T value;

  /// The current validationError.
  /// If null, the value is considered valid.
  /// Can be set manually by calling [AdvancedFieldController.setError].
  /// Can be cleared by calling [AdvancedFieldController.clearErrors].
  /// Can be set by the validator when [AdvancedFieldController.validate] is called.
  final E? validationError;

  /// The current async error.
  final E? asyncError;

  /// The current error.
  E? get error => validationError ?? asyncError;

  /// Whether autovalidate is on.
  /// If true, the validator will be run after each field change.
  /// If false, the validator will only be run when
  /// [AdvancedFieldController.validate] is called.
  /// Can be changed by calling [AdvancedFieldController.setAutovalidate].
  final bool autovalidate;

  /// Whether the field is readonly.
  /// If true, the value cannot be changed.
  /// Can be changed by calling [AdvancedFieldController.markReadOnly] and
  /// [AdvancedFieldController.unmarkReadOnly].
  final bool readOnly;

  /// The current status of the field.
  final FieldStatus status;

  /// Returns a copy of this state with the given fields replaced.
  ///
  /// Omitting an argument keeps the current value. [validationError] and
  /// [asyncError] accept `null` to clear the error, so they are only left
  /// untouched when the argument is omitted entirely.
  AdvancedFieldState<T, E> copyWithNullable({
    Object? value = _unset,
    Object? validationError = _unset,
    Object? asyncError = _unset,
    bool? autovalidate,
    bool? readOnly,
    FieldStatus? status,
  }) =>
      AdvancedFieldState<T, E>(
        value: identical(value, _unset) ? this.value : value as T,
        validationError: identical(validationError, _unset)
            ? this.validationError
            : validationError as E?,
        asyncError:
            identical(asyncError, _unset) ? this.asyncError : asyncError as E?,
        autovalidate: autovalidate ?? this.autovalidate,
        readOnly: readOnly ?? this.readOnly,
        status: status ?? this.status,
      );

  // ⚠️ Maintainer: keep these and `copyWith` in sync with the fields above.
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AdvancedFieldState<T, E> &&
          value == other.value &&
          validationError == other.validationError &&
          asyncError == other.asyncError &&
          autovalidate == other.autovalidate &&
          readOnly == other.readOnly &&
          status == other.status;

  @override
  int get hashCode => Object.hash(
        value,
        validationError,
        asyncError,
        autovalidate,
        readOnly,
        status,
      );
}

class _Unset {
  const _Unset();
}
const _unset = _Unset();
