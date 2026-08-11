part of 'advanced_field_controller.dart';

/// An async validate function receiving the current value and returning an
/// error code. If null is returned, the value is considered valid.
typedef AsyncValidator<T, E extends Object> = Future<E?> Function(T);

/// Handles a failure of an [AsyncValidator] — an exception it threw, or the
/// [TimeoutException] of a round that ran out of time.
typedef AsyncValidationFailureHandler = Future<void> Function(
  Object error,
  StackTrace? stackTrace,
);

/// Maps a failure of an [AsyncValidator] to an error code, so a failed round
/// can show something. Returning null leaves the field with no code; the status
/// is [FieldStatus.failedValidation] either way.
typedef AsyncValidationFailureMapper<E extends Object> = E? Function(
  Object error,
  StackTrace stackTrace,
);

/// Diagnostic details of an async validation round that could not complete.
/// Read it from [AdvancedFieldController.lastFailure].
///
/// Deliberately without value equality: it must never gate a state comparison
/// or a rebuild.
class AsyncValidationFailure {
  /// Creates a new [AsyncValidationFailure].
  AsyncValidationFailure({
    required this.error,
    required this.stackTrace,
    required this.timedOut,
  });

  /// What went wrong: the exception the validator threw, or a
  /// [TimeoutException] when [AsyncValidation.timeout] expired.
  final Object error;

  /// The stack trace that came with [error].
  final StackTrace stackTrace;

  /// Whether the round was abandoned because [AsyncValidation.timeout] expired.
  final bool timedOut;

  @override
  String toString() =>
      'AsyncValidationFailure(error: $error, timedOut: $timedOut)';
}

/// Everything a field needs to validate its value asynchronously.
///
/// The validator is treated as a function of the value: while a settled verdict
/// still describes the value the field holds, it is reused instead of calling
/// [validator] again. A check depending on state outside the value must be
/// invalidated explicitly with [AdvancedFieldController.clearErrors].
class AsyncValidation<T, E extends Object> {
  /// Creates a new [AsyncValidation].
  const AsyncValidation({
    required this.validator,
    this.debounce = const Duration(milliseconds: 300),
    this.timeout,
    this.onFailure,
    this.failureToError,
  });

  /// Validates the field's value. Returning null means valid.
  ///
  /// Only called when the sync validator passed, and only when a round starts.
  final AsyncValidator<T, E> validator;

  /// How long to wait after a value change before running [validator]. Each new
  /// value restarts the wait, so a burst of changes runs [validator] once.
  /// [AdvancedFieldController.validate] ignores it — it flushes instead.
  final Duration debounce;

  /// How long a round may run before it is abandoned. Null — the default —
  /// means no bound, so a [validator] that never settles hangs
  /// [AdvancedFieldController.validate] forever. On expiry the field moves to
  /// [FieldStatus.failedValidation] and the abandoned result is dropped.
  final Duration? timeout;

  /// Called when a round fails. If omitted, the failure goes to
  /// [FlutterError.reportError]. Invoked unawaited after the state resolved, so
  /// a slow handler cannot hold the field in [FieldStatus.validating], and it
  /// cannot turn a failed round into a passing one.
  final AsyncValidationFailureHandler? onFailure;

  /// Turns a failure into an error code, so a failed round can show something.
  /// Without it a failed field carries no code. A code produced here lands in
  /// [AdvancedFieldState.asyncError].
  final AsyncValidationFailureMapper<E>? failureToError;
}

extension _Failures<T, E extends Object> on AsyncValidation<T, E> {
  E? mapFailure(AsyncValidationFailure failure, String? field) {
    if (failureToError case final map?) {
      try {
        return map(failure.error, failure.stackTrace);
      } catch (error, stack) {
        _report(field, 'mapping the async validation failure', error, stack);
      }
    }
    return null;
  }

  Future<void> reportFailure(
    AsyncValidationFailure failure,
    String? field,
  ) async {
    if (onFailure case final handle?) {
      try {
        return await handle(failure.error, failure.stackTrace);
      } catch (error, stack) {
        _report(field, 'running the onFailure handler', error, stack);
      }
    } else {
      _report(
        field,
        'running the async validator',
        failure.error,
        failure.stackTrace,
      );
    }
  }
}

void _report(String? field, String action, Object error, StackTrace? stack) =>
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: error,
        stack: stack,
        library: 'advanced_forms',
        context: ErrorDescription('$action of field ${field ?? '<unnamed>'}'),
      ),
    );
