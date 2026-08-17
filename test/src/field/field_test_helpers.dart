import 'dart:async';

import 'package:advanced_forms/advanced_forms.dart';
import 'package:flutter_test/flutter_test.dart';

enum TestError {
  malformed,
  valueRequired,
  unavailable,
}

class ValidatorMock {
  TestError? validationResult;

  TestError? call(int? value) => validationResult;
}

const initialValue = 0;

typedef TestField = AdvancedFieldController<int, TestError>;
typedef TestState = AdvancedFieldState<int, TestError>;

/// Returns a list that records every new state emitted by [notifier].
List<TestState> recordStates(TestField notifier) {
  final emissions = <TestState>[];
  notifier.addListener(() => emissions.add(notifier.value));
  return emissions;
}

/// A field whose async validator records each value it is called with in
/// `validated`, runs [onValidate], waits [validatorDelay] and then returns
/// whatever [result] gives.
///
/// The mode is [ValidationMode.onUserInteraction] by default, since that is
/// what lets a value change start a round at all.
({TestField field, List<int> validated}) makeAsyncField({
  Duration debounce = const Duration(milliseconds: 50),
  Duration validatorDelay = Duration.zero,
  Duration? timeout,
  TestError? Function()? result,
  void Function(TestField field)? onValidate,
  AsyncValidationFailureHandler? onFailure,
  AsyncValidationFailureMapper<TestError>? failureToError,
  Validator<int, TestError>? validator,
  ValidationMode mode = ValidationMode.onUserInteraction,
}) {
  final validated = <int>[];
  late TestField field;
  field = AdvancedFieldController<int, TestError>(
    initialValue: initialValue,
    validator: validator,
    asyncValidation: AsyncValidation(
      validator: (value) async {
        validated.add(value);
        onValidate?.call(field);
        await Future<void>.delayed(validatorDelay);
        return result?.call();
      },
      debounce: debounce,
      timeout: timeout,
      onFailure: onFailure,
      failureToError: failureToError,
    ),
  )..setValidationMode(mode);
  return (field: field, validated: validated);
}
