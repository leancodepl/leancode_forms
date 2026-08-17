import 'package:advanced_forms/advanced_forms.dart';
import 'package:flutter_test/flutter_test.dart';

import 'field_test_helpers.dart';

void main() {
  late TestField field;
  late ValidatorMock validator;

  setUp(() {
    validator = ValidatorMock();
    field = AdvancedFieldController<int, TestError>(
      initialValue: initialValue,
      validator: validator,
    );
  });

  tearDown(() => field.dispose());

  group('async validation', () {
    late TestField asyncField;

    setUp(() {
      asyncField = AdvancedFieldController<int, TestError>(
        initialValue: initialValue,
        asyncValidation: AsyncValidation(
          validator: (value) async {
            await Future<void>.delayed(const Duration(milliseconds: 100));
            return validator.validationResult;
          },
        ),
      )..setValidationMode(ValidationMode.onUserInteraction);
    });

    tearDown(() {
      asyncField.dispose();
    });

    test('does not run in manual mode', () async {
      final (:field, :validated) = makeAsyncField(mode: ValidationMode.manual);
      addTearDown(field.dispose);
      final emissions = recordStates(field);

      field.setValue(10);
      await Future<void>.delayed(const Duration(milliseconds: 200));

      expect(validated, isEmpty);
      expect(emissions, const [TestState(value: 10)]);
    });

    test('emits pending, validating, then final invalid', () async {
      validator.validationResult = TestError.malformed;
      final emissions = recordStates(asyncField);

      asyncField.setValue(10);
      await Future<void>.delayed(const Duration(milliseconds: 600));

      expect(emissions, const [
        TestState(
          value: 10,
          status: FieldStatus.pending,
          validationMode: ValidationMode.onUserInteraction,
        ),
        TestState(
          value: 10,
          status: FieldStatus.validating,
          validationMode: ValidationMode.onUserInteraction,
        ),
        TestState(
          value: 10,
          status: FieldStatus.invalid,
          asyncError: TestError.malformed,
          validationMode: ValidationMode.onUserInteraction,
        ),
      ]);
    });

    test('restarts async validation when value changes while pending',
        () async {
      validator.validationResult = TestError.malformed;
      final emissions = recordStates(asyncField);

      asyncField.setValue(10);
      await Future<void>.delayed(const Duration(milliseconds: 150));
      asyncField.setValue(20);
      await Future<void>.delayed(const Duration(milliseconds: 600));

      expect(emissions, const [
        TestState(
          value: 10,
          status: FieldStatus.pending,
          validationMode: ValidationMode.onUserInteraction,
        ),
        TestState(
          value: 20,
          status: FieldStatus.pending,
          validationMode: ValidationMode.onUserInteraction,
        ),
        TestState(
          value: 20,
          status: FieldStatus.validating,
          validationMode: ValidationMode.onUserInteraction,
        ),
        TestState(
          value: 20,
          status: FieldStatus.invalid,
          asyncError: TestError.malformed,
          validationMode: ValidationMode.onUserInteraction,
        ),
      ]);
    });

    test('restarts async validation when value changes while validating',
        () async {
      validator.validationResult = TestError.malformed;
      final emissions = recordStates(asyncField);

      asyncField.setValue(10);
      await Future<void>.delayed(const Duration(milliseconds: 350));
      asyncField.setValue(20);
      await Future<void>.delayed(const Duration(milliseconds: 600));

      expect(emissions, const [
        TestState(
          value: 10,
          status: FieldStatus.pending,
          validationMode: ValidationMode.onUserInteraction,
        ),
        TestState(
          value: 10,
          status: FieldStatus.validating,
          validationMode: ValidationMode.onUserInteraction,
        ),
        TestState(
          value: 20,
          status: FieldStatus.pending,
          validationMode: ValidationMode.onUserInteraction,
        ),
        TestState(
          value: 20,
          status: FieldStatus.validating,
          validationMode: ValidationMode.onUserInteraction,
        ),
        TestState(
          value: 20,
          status: FieldStatus.invalid,
          asyncError: TestError.malformed,
          validationMode: ValidationMode.onUserInteraction,
        ),
      ]);
    });

    test(
        'rapid setValue calls within debounce window: validator runs only once '
        'with the final value', () async {
      final (:field, :validated) = makeAsyncField(
        debounce: const Duration(milliseconds: 200),
        validatorDelay: const Duration(milliseconds: 50),
      );
      final f = field;
      addTearDown(f.dispose);

      f.setValue(1);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      f.setValue(2);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      f.setValue(3);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      f.setValue(4);
      await Future<void>.delayed(const Duration(milliseconds: 400));

      expect(validated, const [4]);
    });

    test('dispose during pending state does not crash or emit after dispose',
        () async {
      final f = makeAsyncField(
        debounce: const Duration(milliseconds: 200),
        validatorDelay: const Duration(milliseconds: 100),
      ).field;
      final emissions = recordStates(f);

      f.setValue(10);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      // Field is in pending state, debounce not yet elapsed.
      expect(emissions, const [
        TestState(
          value: 10,
          status: FieldStatus.pending,
          validationMode: ValidationMode.onUserInteraction,
        ),
      ]);

      f.dispose();
      await Future<void>.delayed(const Duration(milliseconds: 500));

      // No further emissions after dispose.
      expect(emissions, const [
        TestState(
          value: 10,
          status: FieldStatus.pending,
          validationMode: ValidationMode.onUserInteraction,
        ),
      ]);
    });

    test('dispose during validating state does not crash or emit after dispose',
        () async {
      final f = makeAsyncField(
        validatorDelay: const Duration(milliseconds: 200),
      ).field;
      final emissions = recordStates(f);

      f.setValue(10);
      await Future<void>.delayed(const Duration(milliseconds: 100));
      // Debounce (50ms) has elapsed; validator (200ms) is running.
      expect(emissions, const [
        TestState(
          value: 10,
          status: FieldStatus.pending,
          validationMode: ValidationMode.onUserInteraction,
        ),
        TestState(
          value: 10,
          status: FieldStatus.validating,
          validationMode: ValidationMode.onUserInteraction,
        ),
      ]);

      f.dispose();
      await Future<void>.delayed(const Duration(milliseconds: 400));

      // Validator's natural completion arrives AFTER dispose; no emission.
      expect(emissions, const [
        TestState(
          value: 10,
          status: FieldStatus.pending,
          validationMode: ValidationMode.onUserInteraction,
        ),
        TestState(
          value: 10,
          status: FieldStatus.validating,
          validationMode: ValidationMode.onUserInteraction,
        ),
      ]);
    });

    test(
        'disposing while the validator is in flight does not emit when it '
        'resolves', () async {
      final (:field, :validated) = makeAsyncField(
        debounce: const Duration(milliseconds: 10),
        onValidate: (f) => f.dispose(),
      );
      final emissions = recordStates(field);

      field.setValue(10);
      await Future<void>.delayed(const Duration(milliseconds: 200));

      expect(field.isDisposed, isTrue);
      expect(validated, const [10]);
      // The validator resolved against a disposed controller, so the final
      // state is never emitted.
      expect(emissions, const [
        TestState(
          value: 10,
          status: FieldStatus.pending,
          validationMode: ValidationMode.onUserInteraction,
        ),
        TestState(
          value: 10,
          status: FieldStatus.validating,
          validationMode: ValidationMode.onUserInteraction,
        ),
      ]);
    });
  });

  group('round ownership', () {
    test(
        'a sync-invalid setValue during a pending round cannot resurrect the '
        'earlier value', () async {
      var reject = false;
      final (:field, :validated) = makeAsyncField(
        validatorDelay: const Duration(milliseconds: 100),
        validator: (_) => reject ? TestError.malformed : null,
      );
      addTearDown(field.dispose);

      field.setValue(10);
      await Future<void>.delayed(const Duration(milliseconds: 80));
      expect(field.value.isValidating, isTrue);

      reject = true;
      field.setValue(20);
      await Future<void>.delayed(const Duration(milliseconds: 300));

      expect(field.fieldValue, 20);
      expect(field.value.validationError, TestError.malformed);
      expect(validated, const [10]);
    });

    test('reset during a pending round is not undone by the round', () async {
      final (:field, :validated) = makeAsyncField(
        debounce: const Duration(milliseconds: 100),
        result: () => TestError.unavailable,
      );
      addTearDown(field.dispose);

      field.setValue(10);
      expect(field.value.isPending, isTrue);

      field.reset();
      final emissions = recordStates(field);
      await Future<void>.delayed(const Duration(milliseconds: 300));

      expect(field.fieldValue, initialValue);
      expect(field.value.isValid, isTrue);
      expect(emissions, isEmpty);
      expect(validated, isEmpty);
    });

    test('reset during a validating round is not undone by the round',
        () async {
      final (:field, :validated) = makeAsyncField(
        debounce: const Duration(milliseconds: 10),
        validatorDelay: const Duration(milliseconds: 100),
        result: () => TestError.unavailable,
      );
      addTearDown(field.dispose);

      field.setValue(10);
      await Future<void>.delayed(const Duration(milliseconds: 40));
      expect(field.value.isValidating, isTrue);

      field.reset();
      final emissions = recordStates(field);
      await Future<void>.delayed(const Duration(milliseconds: 300));

      expect(field.fieldValue, initialValue);
      expect(field.value.isValid, isTrue);
      expect(emissions, isEmpty);
    });

    test('setError during a pending round survives the round', () async {
      final (:field, :validated) = makeAsyncField(
        debounce: const Duration(milliseconds: 100),
        result: () => TestError.unavailable,
      );
      addTearDown(field.dispose);

      field.setValue(10);
      expect(field.value.isPending, isTrue);

      field.setError(TestError.valueRequired);
      final emissions = recordStates(field);
      await Future<void>.delayed(const Duration(milliseconds: 300));

      expect(field.value.validationError, TestError.valueRequired);
      expect(field.value.isInvalid, isTrue);
      expect(emissions, isEmpty);
      expect(validated, isEmpty);
    });

    test('clearErrors during a pending round is not undone by the round',
        () async {
      final (:field, :validated) = makeAsyncField(
        debounce: const Duration(milliseconds: 100),
        result: () => TestError.unavailable,
      );
      addTearDown(field.dispose);

      field.setValue(10);
      expect(field.value.isPending, isTrue);

      field.clearErrors();
      final emissions = recordStates(field);
      await Future<void>.delayed(const Duration(milliseconds: 300));

      expect(field.value.isValid, isTrue);
      expect(emissions, isEmpty);
      expect(validated, isEmpty);
    });

    test('clearErrors during a validating round is not undone by the round',
        () async {
      final (:field, :validated) = makeAsyncField(
        debounce: const Duration(milliseconds: 10),
        validatorDelay: const Duration(milliseconds: 100),
        result: () => TestError.unavailable,
      );
      addTearDown(field.dispose);

      field.setValue(10);
      await Future<void>.delayed(const Duration(milliseconds: 40));
      expect(field.value.isValidating, isTrue);

      field.clearErrors();
      final emissions = recordStates(field);
      await Future<void>.delayed(const Duration(milliseconds: 300));

      expect(field.value.asyncError, isNull);
      expect(field.value.isValid, isTrue);
      expect(emissions, isEmpty);
      expect(validated, const [10]);
    });

    test('setError during a validating round survives the round', () async {
      final (:field, :validated) = makeAsyncField(
        debounce: const Duration(milliseconds: 10),
        validatorDelay: const Duration(milliseconds: 100),
        result: () => TestError.unavailable,
      );
      addTearDown(field.dispose);

      field.setValue(10);
      await Future<void>.delayed(const Duration(milliseconds: 40));
      expect(field.value.isValidating, isTrue);

      field.setError(TestError.valueRequired);
      final emissions = recordStates(field);
      await Future<void>.delayed(const Duration(milliseconds: 300));

      expect(field.value.validationError, TestError.valueRequired);
      expect(emissions, isEmpty);
    });

    test('markReadOnly during an active round stops it and drops lastFailure',
        () async {
      final (:field, :validated) = makeAsyncField(
        debounce: const Duration(milliseconds: 10),
        validatorDelay: const Duration(milliseconds: 100),
        result: () => TestError.unavailable,
      );
      addTearDown(field.dispose);

      field.setValue(10);
      await Future<void>.delayed(const Duration(milliseconds: 40));
      expect(field.value.isValidating, isTrue);

      field.markReadOnly();
      final emissions = recordStates(field);
      await Future<void>.delayed(const Duration(milliseconds: 300));

      expect(field.value.readOnly, isTrue);
      expect(field.value.isValid, isTrue);
      expect(field.lastFailure, isNull);
      expect(emissions, isEmpty);
    });

    test('markReadOnly keeps a failed status while dropping its details',
        () async {
      final (:field, :validated) = makeAsyncField(
        onValidate: (_) => throw StateError('validator exploded'),
        onFailure: (error, stackTrace) async {},
      );
      addTearDown(field.dispose);

      await field.validate();
      expect(field.value.isFailedValidation, isTrue);
      expect(field.lastFailure, isNotNull);

      field.markReadOnly();

      expect(field.value.isFailedValidation, isTrue);
      expect(field.value.isValid, isFalse);
      expect(field.lastFailure, isNull);
    });

    test('a superseded round writes nothing after the abort', () async {
      final (:field, :validated) = makeAsyncField(
        debounce: const Duration(milliseconds: 10),
        validatorDelay: const Duration(milliseconds: 100),
        result: () => TestError.unavailable,
      );
      addTearDown(field.dispose);

      field.setValue(10);
      await Future<void>.delayed(const Duration(milliseconds: 40));

      field
        ..setValidationMode(ValidationMode.manual)
        ..setValue(10, force: true);
      final emissions = recordStates(field);
      await Future<void>.delayed(const Duration(milliseconds: 300));

      expect(emissions, isEmpty);
      expect(field.value.asyncError, isNull);
    });
  });
}
