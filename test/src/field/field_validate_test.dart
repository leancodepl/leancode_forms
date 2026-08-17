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

  group('validate', () {
    test('when is valid', () async {
      validator.validationResult = null;
      final result = await field.validate();

      expect(result, true);
      expect(field.value, const TestState(value: initialValue));
      expect(field.value.isValid, true);
    });

    test('when is not valid', () async {
      validator.validationResult = TestError.malformed;
      final result = await field.validate();

      expect(result, false);
      expect(
        field.value,
        const TestState(
          value: initialValue,
          validationError: TestError.malformed,
          status: FieldStatus.invalid,
        ),
      );
      expect(field.value.isValid, false);
    });

    test(
        'when validation result is the same as previous, does not emit new state',
        () async {
      validator.validationResult = TestError.malformed;
      field.setError(TestError.malformed);
      final emissions = recordStates(field);
      await field.validate();
      expect(emissions, isEmpty);
    });

    test('surfaces a sync error on a field that already carries an async one',
        () async {
      validator.validationResult = TestError.malformed;
      field.debugSetState(
        const TestState(
          value: initialValue,
          asyncError: TestError.unavailable,
          status: FieldStatus.invalid,
        ),
      );

      expect(await field.validate(), false);
      expect(field.value.validationError, TestError.malformed);
      expect(field.value.asyncError, TestError.unavailable);
      expect(field.error, TestError.malformed);
    });

    test('does not call the async validator when the sync verdict fails',
        () async {
      final (:field, :validated) = makeAsyncField(
        validator: (_) => TestError.malformed,
        mode: ValidationMode.manual,
      );
      addTearDown(field.dispose);

      expect(await field.validate(), false);
      expect(validated, isEmpty);
      expect(field.value.validationError, TestError.malformed);
    });

    test('runs the async validator even in manual mode', () async {
      final (:field, :validated) = makeAsyncField(mode: ValidationMode.manual);
      addTearDown(field.dispose);

      expect(await field.validate(), true);
      expect(validated, const [initialValue]);
    });

    test('completes false when the field is disposed mid-round', () async {
      final (:field, :validated) = makeAsyncField(
        debounce: const Duration(milliseconds: 10),
        validatorDelay: const Duration(milliseconds: 200),
      );

      final result = field.validate();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      field.dispose();

      expect(await result, false);
    });

    test('reports a superseded round as not known good', () async {
      final (:field, :validated) = makeAsyncField(
        validatorDelay: const Duration(milliseconds: 100),
        mode: ValidationMode.manual,
      );
      addTearDown(field.dispose);

      final result = field.validate();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(field.value.isValidating, isTrue);

      // The gate is closed, so this stores the value and runs nothing. The
      // status is back to `valid` — but nothing ever checked 20, so the
      // pending `validate()` must not claim it did.
      field.setValue(20);
      expect(field.value.isValid, isTrue);

      expect(await result, isFalse);
    });

    test('two concurrent calls coalesce into one pass', () async {
      final (:field, :validated) = makeAsyncField(
        validatorDelay: const Duration(milliseconds: 50),
      );
      addTearDown(field.dispose);

      final first = field.validate();
      final second = field.validate();

      expect(identical(first, second), isTrue);
      expect(await first, true);
      expect(await second, true);
      expect(validated, const [initialValue]);
    });

    test('flushes a round still waiting out its debounce', () async {
      final (:field, :validated) = makeAsyncField(
        debounce: const Duration(seconds: 10),
      );
      addTearDown(field.dispose);

      field.setValue(10);
      expect(field.value.isPending, isTrue);

      expect(await field.validate(), true);
      expect(validated, const [10]);
    });

    test('awaits an in-flight round instead of starting another', () async {
      final (:field, :validated) = makeAsyncField(
        debounce: const Duration(milliseconds: 10),
        validatorDelay: const Duration(milliseconds: 100),
      );
      addTearDown(field.dispose);

      field.setValue(10);
      await Future<void>.delayed(const Duration(milliseconds: 40));
      expect(field.value.isValidating, isTrue);

      expect(await field.validate(), true);
      expect(validated, const [10]);
    });

    test('reuses a verdict that still describes the current value', () async {
      final (:field, :validated) = makeAsyncField(mode: ValidationMode.manual);
      addTearDown(field.dispose);

      expect(await field.validate(), true);
      expect(await field.validate(), true);

      expect(validated, const [initialValue]);
    });

    test('a value change invalidates the verdict', () async {
      final (:field, :validated) = makeAsyncField(mode: ValidationMode.manual);
      addTearDown(field.dispose);

      await field.validate();
      field.setValue(10);
      await field.validate();

      expect(validated, const [initialValue, 10]);
    });

    test('re-runs a round that failed, so submit is the retry', () async {
      var shouldThrow = true;
      final validated = <int>[];
      final f = AdvancedFieldController<int, TestError>(
        initialValue: initialValue,
        asyncValidation: AsyncValidation(
          validator: (value) async {
            validated.add(value);
            if (shouldThrow) {
              throw StateError('validator exploded');
            }
            return null;
          },
          onFailure: (error, stackTrace) async {},
        ),
      );
      addTearDown(f.dispose);

      expect(await f.validate(), false);
      expect(f.value.isFailedValidation, isTrue);

      shouldThrow = false;
      expect(await f.validate(), true);
      expect(validated, const [initialValue, initialValue]);
    });
  });
}
