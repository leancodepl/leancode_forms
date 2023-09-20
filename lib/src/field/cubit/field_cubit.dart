import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:leancode_forms/src/utils/cancelable_future.dart';
import 'package:rxdart/rxdart.dart';

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
          FieldState<T, E>(value: initialValue),
        );

  final T _initialValue;

  final Validator<T, E> _validator;

  final AsyncValidator<T, E>? _asyncValidator;

  final Duration _asyncValidationDebounce;

  Timer? _debounceTimer;

  CancelableFuture<E?>? _asyncValidationFuture;

  StreamSubscription<void>? _fieldsSubscription;

  /// Subscribes to the [fields] and revalidate the field when any of the fields change.
  void subscribeToFields(List<FieldCubit<dynamic, dynamic>> fields) {
    _fieldsSubscription?.cancel();

    _fieldsSubscription = Rx.combineLatest(
      fields.map((field) => field.stream.map((s) => s.value).distinct()),
      (_) => <dynamic>{},
    ).listen((_) {
      if (state.autovalidate) {
        // Setting the same value will trigger a validation.
        setValue(state.value);
      }
    });
  }

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
    _asyncValidationFuture?.cancel();

    // Create a new Completer to handle the async validation result.
    final completer = Completer<E?>();

    /// Update the field state with the pending status.
    emit(
      FieldState<T, E>(
        value: value,
        validationError: state.validationError,
        asyncError: state.asyncError,
        autovalidate: state.autovalidate,
        readOnly: state.readOnly,
        status: FieldStatus.pending,
      ),
    );

    // Start a new debounce timer.
    _debounceTimer = Timer(_asyncValidationDebounce, () async {
      /// Update the field state with the validating status.
      emit(
        FieldState<T, E>(
          value: value,
          validationError: state.validationError,
          asyncError: state.asyncError,
          autovalidate: state.autovalidate,
          readOnly: state.readOnly,
          status: FieldStatus.validating,
        ),
      );

      // Run the async validator and complete the Completer with the result.
      _asyncValidationFuture = CancelableFuture(
        future: _asyncValidator!(value),
        onComplete: completer.complete,
      );
    });

    // Wait for the async validation to complete.
    final error = await completer.future;

    // Update the field state with the async validation result.
    emit(
      FieldState<T, E>(
        value: value,
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
        autovalidate: state.autovalidate,
        readOnly: state.readOnly,
        status: FieldStatus.invalid,
      ),
    );
  }

  /// Returns true if there are no errors.
  /// If validator return different error than the current one, the state is updated.
  bool validate() {
    if (state.asyncError != null || state.isInProgress) {
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
        status: state.status,
      ),
    );
  }

  /// Clears all errors on this field.
  void clearErrors() {
    emit(
      FieldState<T, E>(
        value: state.value,
        autovalidate: state.autovalidate,
        readOnly: state.readOnly,
      ),
    );
  }

  /// Resets the field to its initial value.
  void reset() {
    emit(FieldState(value: _initialValue));
  }

  @override
  Future<void> close() {
    _fieldsSubscription?.cancel();
    return super.close();
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

  /// The field is being async validated.
  validating,
}

/// The state of a [FieldCubit].
class FieldState<T, E extends Object> with EquatableMixin {
  /// Creates a new [FieldState].
  const FieldState({
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

  @override
  List<Object?> get props => [
        value,
        validationError,
        asyncError,
        autovalidate,
        readOnly,
        status,
      ];
}
