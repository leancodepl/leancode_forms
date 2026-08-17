import 'package:flutter_test/flutter_test.dart';
import 'package:leancode_forms/leancode_forms.dart';

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

  group('setError', () {
    test('sets error and changes field status to invalid', () {
      final emissions = recordStates(field);
      field.setError(TestError.malformed);
      expect(emissions, const [
        TestState(
          value: initialValue,
          validationError: TestError.malformed,
          status: FieldStatus.invalid,
        ),
      ]);
    });

    test('null clears the sync slot and the status follows', () async {
      field.setError(TestError.malformed);
      final emissions = recordStates(field);

      field.setError(null);

      expect(emissions, const [TestState(value: initialValue)]);
      expect(field.value.isValid, isTrue);
      expect(await field.validate(), isTrue);
    });

    test('leaves a still-current verdict reusable', () async {
      final (:field, :validated) = makeAsyncField(mode: ValidationMode.manual);
      addTearDown(field.dispose);

      await field.validate();
      expect(validated, const [initialValue]);

      field
        ..setError(TestError.valueRequired)
        ..setError(null);

      expect(await field.validate(), isTrue);
      expect(validated, const [initialValue]);
    });
  });

  group('both error slots', () {
    test('a cross-field sync error stands alongside a current verdict',
        () async {
      var mismatch = false;
      final (:field, :validated) = makeAsyncField(
        validator: (_) => mismatch ? TestError.malformed : null,
        result: () => TestError.unavailable,
        mode: ValidationMode.manual,
      );
      addTearDown(field.dispose);

      // The server answers `unavailable`; the round is settled.
      expect(await field.validate(), isFalse);
      expect(field.value.asyncError, TestError.unavailable);

      // A sibling changes, so the cross-field rule now rejects the value.
      mismatch = true;
      expect(await field.validate(), isFalse);

      expect(field.value.validationError, TestError.malformed);
      expect(field.value.asyncError, TestError.unavailable);
      expect(field.error, TestError.malformed);
      // The value never changed, so the verdict was never re-fetched.
      expect(validated, const [initialValue]);
    });

    test('a flag write re-derives a status that disagrees with the slots',
        () async {
      // `AdvancedFieldState` can represent `valid` alongside an error, so a
      // write that touches only a flag still has to settle the status rather
      // than carry the stale one through.
      for (final write in <void Function(TestField)>[
        (field) => field.setValidationMode(ValidationMode.onUserInteraction),
        (field) => field.unmarkReadOnly(),
      ]) {
        final field = TestField(initialValue: initialValue)
          ..debugSetState(
            const TestState(
              value: initialValue,
              asyncError: TestError.unavailable,
            ),
          );
        addTearDown(field.dispose);
        expect(field.value.status, FieldStatus.valid);

        write(field);

        expect(field.value.status, FieldStatus.invalid);
      }
    });
  });
}
