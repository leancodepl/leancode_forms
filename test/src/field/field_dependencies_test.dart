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

  group('subscribeToFields', () {
    test('throws StateError when this field has been disposed', () {
      final observed = AdvancedFieldController<int, TestError>(initialValue: 0);
      addTearDown(observed.dispose);
      var validatorCalls = 0;
      final field = AdvancedFieldController<int, TestError>(
        initialValue: 0,
        validator: (_) {
          validatorCalls++;
          return null;
        },
      )
        ..setValidationMode(ValidationMode.onUserInteraction)
        ..dispose();

      expect(() => field.subscribeToFields([observed]), throwsStateError);

      // The guard is what keeps the listener off the live field.
      observed.setValue(10);

      expect(validatorCalls, 0);
    });

    test('drops the subscription on dispose', () {
      final observed = AdvancedFieldController<int, TestError>(initialValue: 0);
      addTearDown(observed.dispose);
      var validatorCalls = 0;
      final field = AdvancedFieldController<int, TestError>(
        initialValue: 0,
        validator: (_) {
          validatorCalls++;
          return null;
        },
      )
        ..setValidationMode(ValidationMode.onUserInteraction)
        // The guarantee: only a field the user has edited revalidates.
        ..setValue(0)
        ..subscribeToFields([observed]);
      validatorCalls = 0;

      observed.setValue(10);

      expect(validatorCalls, 1);

      field.dispose();
      observed.setValue(20);

      expect(validatorCalls, 1);
    });

    test('re-runs the sync validator when a subscribed field changes',
        () async {
      final field2 = AdvancedFieldController<int, TestError>(initialValue: 0);
      final field1 = AdvancedFieldController<int, TestError>(
        initialValue: 0,
        validator: validator,
      )
        ..setValidationMode(ValidationMode.onUserInteraction)
        // The guarantee: only a field the user has edited revalidates.
        ..setValue(0)
        ..subscribeToFields([field2]);
      addTearDown(field1.dispose);
      addTearDown(field2.dispose);
      validator.validationResult = TestError.malformed;

      field2.setValue(10);
      await pumpEventQueue();

      expect(field1.value.error, TestError.malformed);
    });

    test('does not re-run the async validator: this field did not change',
        () async {
      final field2 = AdvancedFieldController<int, TestError>(initialValue: 0);
      addTearDown(field2.dispose);
      final (:field, :validated) = makeAsyncField();
      addTearDown(field.dispose);
      field.subscribeToFields([field2]);

      field2.setValue(10);
      await Future<void>.delayed(const Duration(milliseconds: 200));

      expect(validated, isEmpty);
      expect(field.value.isValid, isTrue);
    });

    test('does nothing in manual mode, including clearing errors', () async {
      final field2 = AdvancedFieldController<int, TestError>(initialValue: 0);
      final field1 = AdvancedFieldController<int, TestError>(
        initialValue: 0,
        validator: validator,
      )..subscribeToFields([field2]);
      addTearDown(field1.dispose);
      addTearDown(field2.dispose);

      field1.setError(TestError.valueRequired);

      field2.setValue(10);
      await pumpEventQueue();

      expect(field1.value.error, TestError.valueRequired);
    });

    test('changing the mode does not validate immediately', () async {
      validator.validationResult = TestError.malformed;
      final field2 = AdvancedFieldController<int, TestError>(initialValue: 0);
      final field1 = AdvancedFieldController<int, TestError>(
        initialValue: 0,
        validator: validator,
      )..subscribeToFields([field2]);
      addTearDown(field1.dispose);
      addTearDown(field2.dispose);

      field1.setValidationMode(ValidationMode.onUserInteraction);
      await pumpEventQueue();

      expect(field1.value.error, isNull);
      expect(field1.value.isValid, isTrue);
    });
  });
}
