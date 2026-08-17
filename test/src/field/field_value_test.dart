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

  group('setValue', () {
    test('updates the value', () {
      final emissions = recordStates(field);
      field.setValue(10);
      expect(emissions, const [TestState(value: 10)]);
    });

    test('does not run the validator in manual mode', () {
      validator.validationResult = TestError.malformed;
      final emissions = recordStates(field);
      field.setValue(10);
      expect(emissions, const [TestState(value: 10)]);
    });

    test('clears both error slots in manual mode', () {
      field.debugSetState(
        const TestState(
          value: 1,
          validationError: TestError.valueRequired,
          asyncError: TestError.malformed,
          status: FieldStatus.invalid,
        ),
      );
      final emissions = recordStates(field);

      field.setValue(10);

      expect(emissions, const [TestState(value: 10)]);
    });

    test('updates error in onUserInteraction mode', () {
      field.setValidationMode(ValidationMode.onUserInteraction);
      validator.validationResult = TestError.malformed;
      final emissions = recordStates(field);
      field.setValue(10);
      expect(emissions, const [
        TestState(
          value: 10,
          validationError: TestError.malformed,
          validationMode: ValidationMode.onUserInteraction,
          status: FieldStatus.invalid,
        ),
      ]);
    });

    test('does not update the value when field is readonly', () {
      field.markReadOnly();
      final emissions = recordStates(field);
      field.setValue(10);
      expect(emissions, isEmpty);
    });

    test('updates the value when field is readonly and force is true', () {
      field.markReadOnly();
      final emissions = recordStates(field);
      field.setValue(10, force: true);
      expect(emissions, const [TestState(value: 10, readOnly: true)]);
    });

    test('throws once the field is disposed', () {
      final disposed = AdvancedFieldController<int, TestError>(
        initialValue: initialValue,
      )..dispose();

      expect(() => disposed.setValue(10), throwsStateError);
    });

    test('starts no async validation once the field is disposed', () async {
      final (field: asyncField, :validated) = makeAsyncField();
      asyncField.dispose();

      expect(() => asyncField.setValue(10), throwsStateError);
      await pumpEventQueue();
      expect(validated, isEmpty);
    });
  });

  group('prefill', () {
    test('stores the value without validating it', () {
      validator.validationResult = TestError.malformed;
      field.setValidationMode(ValidationMode.onUserInteraction);
      final emissions = recordStates(field);

      field.prefill(10);

      expect(emissions, const [
        TestState(value: 10, validationMode: ValidationMode.onUserInteraction),
      ]);
    });

    test('does not count as the user having edited the field', () {
      field
        ..setValidationMode(ValidationMode.onUserInteraction)
        ..prefill(10);
      validator.validationResult = TestError.malformed;

      field.revalidateSync();

      expect(field.value.error, isNull);
    });

    test('clears the errors that described the old value', () {
      field
        ..setError(TestError.valueRequired)
        ..prefill(10);

      expect(field.value.error, isNull);
      expect(field.value.isValid, isTrue);
    });

    test('is a no-op on a read-only field unless forced', () {
      field
        ..markReadOnly()
        ..prefill(10);
      expect(field.fieldValue, initialValue);

      field.prefill(10, force: true);
      expect(field.fieldValue, 10);
    });

    test('validate still checks a prefilled value', () async {
      validator.validationResult = TestError.malformed;
      field
        ..setValidationMode(ValidationMode.onUserInteraction)
        ..prefill(10);

      expect(await field.validate(), isFalse);
    });
  });

  group('reset', () {
    test('resets the value and both error slots', () {
      field.debugSetState(
        const TestState(
          value: 10,
          validationError: TestError.malformed,
          asyncError: TestError.malformed,
          status: FieldStatus.invalid,
        ),
      );
      final emissions = recordStates(field);
      field.reset();
      expect(emissions, const [TestState(value: 0)]);
    });

    test('keeps the mode and readOnly', () {
      field
        ..setValidationMode(ValidationMode.onUserInteraction)
        ..markReadOnly()
        ..setValue(10, force: true);
      final emissions = recordStates(field);

      field.reset();

      expect(emissions, const [
        TestState(
          value: 0,
          validationMode: ValidationMode.onUserInteraction,
          readOnly: true,
        ),
      ]);
    });
  });

  group('clearErrors', () {
    test('clears validationError and asyncError. Sets status to valid', () {
      field.debugSetState(
        const TestState(
          value: 1,
          validationError: TestError.valueRequired,
          asyncError: TestError.malformed,
        ),
      );
      final emissions = recordStates(field);
      field.clearErrors();
      expect(emissions, const [TestState(value: 1)]);
    });

    test('does nothing if errors were not present', () {
      field.setValue(1);
      final emissions = recordStates(field);
      field.clearErrors();
      expect(emissions, isEmpty);
    });
  });

  group('getValueSetter', () {
    test('is null when field is readonly', () {
      field.markReadOnly();
      expect(field.getValueSetter(), null);
    });

    test('is setValue when field is not readonly', () {
      expect(field.getValueSetter(), field.setValue);
    });
  });
}
