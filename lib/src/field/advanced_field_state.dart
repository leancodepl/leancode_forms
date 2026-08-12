part of 'advanced_field_controller.dart';

/// Translates an error to a string.
typedef ErrorTranslator<E extends Object> = String Function(E);

/// The status of a [AdvancedFieldController].
enum FieldStatus {
  /// No error is recorded on the field.
  ///
  /// Not the same as *checked and passed*: a field nobody has validated yet is
  /// `valid`. `await AdvancedFormController.validate()` is the guarantee.
  valid,

  /// An error is recorded on the field.
  invalid,

  /// The value changed and the async validator is about to run, once the
  /// [AsyncValidation.debounce] wait is over.
  pending,

  /// The async validator is running.
  validating,

  /// The async validator threw, or its round timed out, so validation could not
  /// complete — a technical fault, not a verdict about the value.
  ///
  /// Carries no error code unless [AsyncValidation.failureToError] supplied
  /// one, but the field does not count as valid. Not sticky: the next
  /// `validate()` re-runs the round, so submit is the retry.
  failedValidation,
}

/// An immutable snapshot of an [AdvancedFieldController]. Obtain it from
/// [AdvancedFieldController.value], or listen to the controller for changes.
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

  /// The current value. Set it with [AdvancedFieldController.setValue].
  final T value;

  /// The error the sync path recorded — the sync validator or
  /// [AdvancedFieldController.setError].
  final E? validationError;

  /// The error the async round recorded. Only the async pipeline writes it.
  final E? asyncError;

  /// Whether a value change runs the validators. With it off,
  /// [AdvancedFieldController.setValue] stores the value, clears both errors
  /// and resets the status to [FieldStatus.valid].
  final bool autovalidate;

  /// Whether the value is frozen against [AdvancedFieldController.setValue].
  final bool readOnly;

  /// Where validation currently stands.
  final FieldStatus status;

  /// The current error: [validationError] falling back to [asyncError].
  ///
  /// [validationError] wins because a rule about the value outranks a verdict
  /// that may predate the app state the rule reads.
  E? get error => validationError ?? asyncError;

  /// Whether the status is [FieldStatus.valid]: not the same as *checked and
  /// passed*.
  bool get isValid => status == FieldStatus.valid;

  /// Whether the status is [FieldStatus.invalid] — not a failed round.
  bool get isInvalid => status == FieldStatus.invalid;

  /// Whether a round is waiting out its debounce.
  bool get isPending => status == FieldStatus.pending;

  /// Whether the async validator is running.
  bool get isValidating => status == FieldStatus.validating;

  /// Whether a round is pending or validating.
  bool get isInProgress => isPending || isValidating;

  /// Whether the async validator failed, so validation never completed.
  bool get isFailedValidation => status == FieldStatus.failedValidation;

  AdvancedFieldState<T, E> _copyWithNullable({
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

  @override
  String toString() => 'AdvancedFieldState('
      'value: $value, '
      'validationError: $validationError, '
      'asyncError: $asyncError, '
      'status: ${status.name}, '
      'autovalidate: $autovalidate, '
      'readOnly: $readOnly)';
}

enum _Unset { unset }

const _unset = _Unset.unset;
