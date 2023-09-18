import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// A validate function receiving the current value and returning an error code.
/// If null is returned, the value is considered valid.
typedef Validator<T, E extends Object> = E? Function(T);

/// An async validate function receiving the current value and returning an error code.
typedef AsyncValidator<T, E extends Object> = Future<E?> Function(T);

/// A single form field which can be validated.
/// Stores the current value, error text, and whether autovalidate is on.
/// [T] is the held value, [E] is the type of an error. [E] cannot be nullable
/// to be able to unambiguously detect lack of errors.
///
/// If autovalidate is true, the validator will be run after each field change.
// ignore_for_file: avoid_positional_boolean_parameters
class FieldCubit<T, E extends Object> extends Cubit<FieldState<T, E>> {
  /// Creates a new [FieldCubit] with an initial value and a validator.
  FieldCubit({
    required T initialValue,
    Validator<T, E>? validator,
    AsyncValidator<T, E>? asyncValidator,
    Duration asyncValidationDebounce = const Duration(milliseconds: 300),
  })  : _initialValue = initialValue,
        _validator = validator ?? ((_) => null),
        _asyncValidator = asyncValidator,
        _asyncValidationDebounce = asyncValidationDebounce,
        super(
          FieldState<T, E>(
            value: initialValue,
            validationError: null,
            asyncError: null,
            autovalidate: false,
            readOnly: false,
            status: FieldStatus.valid,
          ),
        );

  final T _initialValue;

  final Validator<T, E> _validator;

  final AsyncValidator<T, E>? _asyncValidator;

  final Duration _asyncValidationDebounce;

  Timer? _debounceTimer;

  /// Set a new [value]. When [force] is true, [state] is always updated to a new [value],
  /// otherwise if [state] is readonly, [setValue] is a noop
  void setValue(T value, {bool force = false}) {
    if (state.readOnly && !force) {
      return;
    }

    E? validationError;

    validationError =
        state.autovalidate ? _validator(value) : state.validationError;

    if (validationError == null && _asyncValidator != null) {
      _runAsyncValidator(value);
      return;
    }

    emit(
      FieldState<T, E>(
        value: value,
        validationError: validationError,
        asyncError: state.asyncError,
        autovalidate: state.autovalidate,
        readOnly: state.readOnly,
        status:
            validationError == null ? FieldStatus.valid : FieldStatus.invalid,
      ),
    );
  }

  Future<void> _runAsyncValidator(T value) async {
    // Cancel the previous debounce timer if it exists.
    _debounceTimer?.cancel();

    // Create a new Completer to handle the async validation result.
    final completer = Completer<E?>();

    // Start a new debounce timer.
    _debounceTimer = Timer(_asyncValidationDebounce, () async {
      /// Update the field state with the async validation pending status.
      emit(
        FieldState<T, E>(
          value: state.value,
          validationError: state.validationError,
          asyncError: state.asyncError,
          autovalidate: state.autovalidate,
          readOnly: state.readOnly,
          status: FieldStatus.pending,
        ),
      );

      // Run the async validator and complete the Completer with the result.
      final error = await _asyncValidator!(value);
      completer.complete(error);
    });

    // Wait for the async validation to complete.
    final error = await completer.future;

    // Update the field state with the async validation result.
    emit(
      FieldState<T, E>(
        value: state.value,
        validationError: state.validationError,
        asyncError: error,
        autovalidate: state.autovalidate,
        readOnly: state.readOnly,
        status: error == null ? FieldStatus.valid : FieldStatus.invalid,
      ),
    );
  }

  /// Returns `null` if field is readonly. Otherwise returns [setValue].
  ///
  /// Useful in contexts where setting `null` as the `onChange` callback causes
  /// the field to be disabled.
  ValueSetter<T>? getValueSetter() {
    if (state.readOnly) {
      return null;
    }

    return setValue;
  }

  /// Emits a [FieldState] with a new [error].
  void setError(E? error) {
    emit(
      FieldState<T, E>(
        value: state.value,
        validationError: error,
        asyncError: null,
        autovalidate: state.autovalidate,
        readOnly: state.readOnly,
        status: FieldStatus.invalid,
      ),
    );
  }

  /// Returns true if there are no errors.
  /// If validator return different error than the current one, the state is updated.
  bool validate() {
    if (state.asyncError != null || state.isPending) {
      return false;
    }

    final error = _validator(state.value);

    if (error != state.validationError) {
      emit(
        FieldState<T, E>(
          value: state.value,
          validationError: error,
          asyncError: state.asyncError,
          autovalidate: state.autovalidate,
          readOnly: state.readOnly,
          status: error == null ? FieldStatus.valid : FieldStatus.invalid,
        ),
      );
    }

    return state.validationError == null;
  }

  /// When autovalidate is true, setting a new value will trigger a validation
  void setAutovalidate(bool autovalidate) {
    emit(
      FieldState<T, E>(
        value: state.value,
        validationError: state.validationError,
        asyncError: state.asyncError,
        autovalidate: autovalidate,
        readOnly: state.readOnly,
        status: state.status,
      ),
    );
  }

  /// Prevents further changes of value [T].
  void markReadOnly() {
    emit(
      FieldState<T, E>(
        value: state.value,
        validationError: state.validationError,
        asyncError: state.asyncError,
        autovalidate: state.autovalidate,
        readOnly: true,
        status: state.status,
      ),
    );
  }

  /// Allows further changes of value [T].
  void unmarkReadOnly() {
    emit(
      FieldState<T, E>(
        value: state.value,
        validationError: state.validationError,
        asyncError: state.asyncError,
        autovalidate: state.autovalidate,
        readOnly: false,
        status: state.status,
      ),
    );
  }

  /// Clears all errors on this field.
  void clearErrors() {
    emit(
      FieldState<T, E>(
        value: state.value,
        validationError: null,
        asyncError: null,
        autovalidate: state.autovalidate,
        readOnly: state.readOnly,
        status: FieldStatus.valid,
      ),
    );
  }

  /// Resets the field to its initial value.
  void reset() {
    emit(
      FieldState(
        value: _initialValue,
        validationError: null,
        asyncError: null,
        autovalidate: false,
        readOnly: false,
        status: FieldStatus.valid,
      ),
    );
  }
}

/// The status of a [FieldCubit].
enum FieldStatus {
  /// The field is valid.
  valid,

  /// The field is invalid.
  invalid,

  /// The field is pending validation.
  pending,
}

/// The state of a [FieldCubit].
class FieldState<T, E extends Object> {
  /// Creates a new [FieldState].
  const FieldState({
    required this.value,
    required this.validationError,
    required this.asyncError,
    required this.autovalidate,
    required this.readOnly,
    required this.status,
  });

  /// Returns true if there are no errors.
  bool get isValid => status == FieldStatus.valid;

  /// Returns true if field status is pending.
  bool get isPending => status == FieldStatus.pending;

  /// The current value.
  /// Can be set manually by calling [FieldCubit.setValue].
  final T value;

  /// The current validationError.
  /// If null, the value is considered valid.
  /// Can be set manually by calling [FieldCubit.setError].
  /// Can be cleared by calling [FieldCubit.clearErrors].
  /// Can be set by the validator when [FieldCubit.validate] is called.
  final E? validationError;

  /// The current async error.
  final E? asyncError;

  /// The current error.
  E? get error => validationError ?? asyncError;

  /// Whether autovalidate is on.
  /// If true, the validator will be run after each field change.
  /// If false, the validator will only be run when [FieldCubit.validate] is called.
  /// Can be changed by calling [FieldCubit.setAutovalidate].
  final bool autovalidate;

  /// Whether the field is readonly.
  /// If true, the value cannot be changed.
  /// Can be changed by calling [FieldCubit.markReadOnly] and [FieldCubit.unmarkReadOnly].
  final bool readOnly;

  /// The current status of the field.
  final FieldStatus status;
}
