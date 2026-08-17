import 'dart:async';

import 'package:advanced_forms/advanced_forms.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

enum _Error1 { valueRequired, taken }

enum _Error2 { malformed }

const _initialValue1 = 'initial';
const _initialValue2 = 0;

class _ValidatorMock<T, E> {
  E? validationResult;

  E? call(T? value) => validationResult;
}

/// Records every new state emitted by [notifier].
List<S> _record<S>(ValueListenable<S> notifier) {
  final emissions = <S>[];
  notifier.addListener(() => emissions.add(notifier.value));
  return emissions;
}

/// Counts how many times a [Listenable] fires.
int Function() _countCalls(Listenable listenable) {
  var count = 0;
  listenable.addListener(() => count++);
  return () => count;
}

void main() {
  group('AdvancedFormController', () {
    late AdvancedFormController form;
    late AdvancedFormController subform;
    late AdvancedTextFieldController<_Error1> field1;
    late AdvancedFieldController<int, _Error2> field2;
    late AdvancedFieldController<int, _Error2> subformField;
    late _ValidatorMock<String, _Error1> validator1;
    late _ValidatorMock<int, _Error2> validator2;

    setUp(() {
      validator1 = _ValidatorMock();
      validator2 = _ValidatorMock();
      field1 = AdvancedTextFieldController(
        initialValue: _initialValue1,
        validator: validator1,
      );
      field2 = AdvancedFieldController(
        initialValue: _initialValue2,
        validator: validator2,
      );
      subformField = AdvancedFieldController(
        initialValue: _initialValue2,
        validator: validator2,
      );
      form = AdvancedFormController();
      subform = AdvancedFormController();
    });

    tearDown(() {
      // The form owns field1/field2/subform/subformField transitively when
      // they get registered/added — but tests that don't register them have
      // to clean up by hand. dispose() is idempotent-ish so we keep tearDown
      // minimal and let each test handle its own scopes.
    });

    test('has correct initial state', () {
      expect(form.value, const AdvancedFormState());
      form.dispose();
    });

    group('getFieldValues', () {
      test('when no fields are registered', () {
        final values = form.getFieldValues();
        expect(values, isEmpty);
        form.dispose();
      });

      test('when fields are registered', () {
        form.registerFields([field1, field2]);
        final values = form.getFieldValues();
        expect(values, <dynamic>[_initialValue1, _initialValue2]);
        form.dispose();
      });

      test('when fields are registered and have new values', () {
        form.registerFields([field1, field2]);
        field1.setValue('hello');
        field2.setValue(10);
        final values = form.getFieldValues();
        expect(values, <dynamic>['hello', 10]);
        form.dispose();
      });

      test('when fields are unregistered', () {
        form
          ..registerFields([field1, field2])
          ..registerFields([]);
        field1.setValue('hello');
        field2.setValue(10);
        final values = form.getFieldValues();
        expect(values, isEmpty);
        form.dispose();
      });
    });

    group('wasModified', () {
      test('is false after register', () {
        final emissions = _record<AdvancedFormState>(form);
        form.registerFields([field1, field2]);
        expect(emissions, [
          AdvancedFormState(fields: [field1, field2]),
        ]);
        form.dispose();
      });

      test('is true if subform was modified', () async {
        subform.registerFields([subformField]);
        form
          ..addSubform(subform)
          ..registerFields([field1, field2]);

        await pumpEventQueue();
        final emissions = _record<AdvancedFormState>(form);
        subformField.setValue(123);
        await pumpEventQueue();

        expect(emissions, [
          AdvancedFormState(
            wasModified: true,
            fields: [field1, field2],
            subforms: {subform},
          ),
        ]);
        form.dispose();
      });

      test('is true if field1 changes', () async {
        form.registerFields([field1, field2]);

        await pumpEventQueue();
        final emissions = _record<AdvancedFormState>(form);
        field1.setValue('value');
        await pumpEventQueue();

        expect(emissions, [
          AdvancedFormState(wasModified: true, fields: [field1, field2]),
        ]);
        form.dispose();
      });

      test('is true if field2 changes', () async {
        form.registerFields([field1, field2]);

        await pumpEventQueue();
        final emissions = _record<AdvancedFormState>(form);
        field2.setValue(0xb0b);
        await pumpEventQueue();

        expect(emissions, [
          AdvancedFormState(wasModified: true, fields: [field1, field2]),
        ]);
        form.dispose();
      });

      test('does not change if field was unregistered', () async {
        form
          ..registerFields([field1, field2])
          ..registerFields([]);

        await pumpEventQueue();
        final emissions = _record<AdvancedFormState>(form);
        field2.setValue(0xb0b);
        await pumpEventQueue();

        expect(emissions, isEmpty);
        form.dispose();
      });
    });

    group('validate', () {
      test('leaves the mode of the tree untouched', () async {
        subform.registerFields([subformField]);
        form
          ..registerFields([field1, field2])
          ..addSubform(subform)
          ..setValidationMode(ValidationMode.onUnfocus);
        await form.validate();

        expect(form.value.validationMode, ValidationMode.onUnfocus);
        expect(field1.value.validationMode, ValidationMode.onUnfocus);
        expect(field2.value.validationMode, ValidationMode.onUnfocus);
        expect(subformField.value.validationMode, ValidationMode.onUnfocus);
        form.dispose();
      });

      test('runs everything in manual mode, including untouched fields',
          () async {
        validator1.validationResult = _Error1.valueRequired;
        subform.registerFields([subformField]);
        form
          ..registerFields([field1, field2])
          ..addSubform(subform);

        expect(await form.validate(), isFalse);
        expect(field1.value.error, _Error1.valueRequired);
        expect(form.value.validationMode, ValidationMode.manual);
        form.dispose();
      });

      test('is valid when all are valid', () async {
        subform.registerFields([subformField]);
        validator1.validationResult = null;
        validator2.validationResult = null;
        form
          ..registerFields([field1, field2])
          ..addSubform(subform);

        expect(await form.validate(), true);
        form.dispose();
      });

      test('is not valid if a subform is not valid', () async {
        subform.registerFields([subformField]);
        validator1.validationResult = null;
        validator2.validationResult = _Error2.malformed;
        form
          ..registerFields([field1])
          ..addSubform(subform);

        expect(await form.validate(), false);
        form.dispose();
        field2.dispose();
      });

      test('is not valid when any is invalid', () async {
        validator1.validationResult = _Error1.valueRequired;
        validator2.validationResult = null;
        form.registerFields([field1, field2]);

        expect(await form.validate(), false);
        form.dispose();
        subform.dispose();
        subformField.dispose();
      });

      test('does not short-circuit on validation', () async {
        subform.registerFields([subformField]);
        validator1.validationResult = _Error1.valueRequired;
        validator2.validationResult = _Error2.malformed;

        form
          ..registerFields([field1, field2])
          ..addSubform(subform);
        await form.validate();

        expect(field1.value.error, _Error1.valueRequired);
        expect(field2.value.error, _Error2.malformed);
        expect(subformField.value.error, _Error2.malformed);
        form.dispose();
      });

      test('is valid when validationEnabled is false', () async {
        validator1.validationResult = _Error1.valueRequired;
        form
          ..registerFields([field1])
          ..setValidationEnabled(false);

        expect(await form.validate(), true);
        form.dispose();
        field2.dispose();
        subform.dispose();
        subformField.dispose();
      });

      test('leaves the fields disabled when validationEnabled is false',
          () async {
        form
          ..registerFields([field1])
          ..setValidationMode(ValidationMode.onUserInteraction)
          ..setValidationEnabled(false);
        await form.validate();

        // Waking them would make the next keystroke run the async validators
        // the caller just switched off.
        expect(field1.value.validationMode, ValidationMode.manual);
        form.dispose();
        field2.dispose();
        subform.dispose();
        subformField.dispose();
      });

      test('reaches the async validators of every field', () async {
        final checked = <String>[];
        final asyncField = AdvancedTextFieldController<_Error1>(
          initialValue: _initialValue1,
          asyncValidation: AsyncValidation(
            validator: (value) async {
              checked.add(value);
              return validator1.validationResult;
            },
          ),
        );
        form.registerFields([asyncField]);
        addTearDown(form.dispose);
        addTearDown(field1.dispose);
        addTearDown(field2.dispose);
        addTearDown(subform.dispose);
        addTearDown(subformField.dispose);

        validator1.validationResult = _Error1.valueRequired;

        expect(await form.validate(), false);
        expect(checked, [_initialValue1]);
        expect(asyncField.value.asyncError, _Error1.valueRequired);
      });

      test('awaits a round that is still in flight', () async {
        validator1.validationResult = null;
        final asyncField = AdvancedTextFieldController<_Error1>(
          initialValue: _initialValue1,
          asyncValidation: AsyncValidation(
            validator: (_) async {
              await Future<void>.delayed(const Duration(milliseconds: 100));
              return validator1.validationResult;
            },
            debounce: const Duration(milliseconds: 10),
          ),
        )..setValidationMode(ValidationMode.onUserInteraction);
        form.registerFields([asyncField]);
        addTearDown(form.dispose);
        addTearDown(field1.dispose);
        addTearDown(field2.dispose);
        addTearDown(subform.dispose);
        addTearDown(subformField.dispose);

        asyncField.setValue('value');
        await Future<void>.delayed(const Duration(milliseconds: 40));
        expect(asyncField.value.isValidating, isTrue);

        expect(await form.validate(), true);
        expect(asyncField.value.isValid, isTrue);
      });

      test('is not valid when async validation of the field fails', () async {
        validator1.validationResult = _Error1.valueRequired;
        final asyncField = AdvancedTextFieldController<_Error1>(
          initialValue: _initialValue1,
          asyncValidation: AsyncValidation(
            validator: (_) async => validator1.validationResult,
          ),
        )..setValidationMode(ValidationMode.onUserInteraction);
        form.registerFields([asyncField]);

        asyncField.setValue('value');
        await Future<void>.delayed(const Duration(milliseconds: 500));
        expect(await form.validate(), false);

        form.dispose();
        field1.dispose();
        field2.dispose();
        subform.dispose();
        subformField.dispose();
      });

      test('reaches the async validators of a subform', () async {
        validator2.validationResult = _Error2.malformed;
        final asyncSubformField = AdvancedFieldController<int, _Error2>(
          initialValue: 0,
          asyncValidation: AsyncValidation(
            validator: (_) async => validator2.validationResult,
          ),
        );
        final asyncSubform = AdvancedFormController()
          ..registerFields([asyncSubformField]);
        form.addSubform(asyncSubform);

        expect(await form.validate(), false);
        expect(asyncSubformField.value.asyncError, _Error2.malformed);

        form.dispose();
        field1.dispose();
        field2.dispose();
        subform.dispose();
        subformField.dispose();
      });

      test('concurrent calls coalesce into one pass', () async {
        var calls = 0;
        final asyncField = AdvancedTextFieldController<_Error1>(
          initialValue: _initialValue1,
          asyncValidation: AsyncValidation(
            validator: (_) async {
              calls++;
              await Future<void>.delayed(const Duration(milliseconds: 50));
              return null;
            },
          ),
        );
        form.registerFields([asyncField]);
        addTearDown(form.dispose);
        addTearDown(field1.dispose);
        addTearDown(field2.dispose);
        addTearDown(subform.dispose);
        addTearDown(subformField.dispose);

        final first = form.validate();
        final second = form.validate();

        expect(identical(first, second), isTrue);
        expect(await first, true);
        expect(await second, true);
        expect(calls, 1);
      });

      test('a disabled form does not occupy the coalescing slot', () async {
        form.registerFields([field1]);
        addTearDown(form.dispose);
        addTearDown(field2.dispose);
        addTearDown(subform.dispose);
        addTearDown(subformField.dispose);
        validator1.validationResult = _Error1.valueRequired;

        form.setValidationEnabled(false);
        // Fire and forget, as a UI handler would. This returns `true` without
        // validating anything, so it must not become the run a later call
        // coalesces onto.
        form.validate().ignore();

        form.setValidationEnabled(true);
        expect(await form.validate(), isFalse);
      });

      test('a disposed form with a call in flight returns that call', () async {
        final asyncField = AdvancedTextFieldController<_Error1>(
          initialValue: _initialValue1,
          asyncValidation: AsyncValidation(
            validator: (_) async {
              await Future<void>.delayed(const Duration(milliseconds: 50));
              return null;
            },
          ),
        );
        form.registerFields([asyncField]);
        addTearDown(field1.dispose);
        addTearDown(field2.dispose);
        addTearDown(subform.dispose);
        addTearDown(subformField.dispose);

        final first = form.validate();
        form.dispose();

        expect(identical(form.validate(), first), isTrue);
        await first;
        // `first` resolves at dispose, so drain the validator before the next
        // test starts — this suite runs on wall-clock delays.
        await Future<void>.delayed(const Duration(milliseconds: 80));
      });
    });

    group('onValuesChanged', () {
      test('fires on field change', () async {
        form.registerFields([field1, field2]);
        await pumpEventQueue();
        final getCount = _countCalls(form.onValuesChanged);

        field1.setValue('value');
        await pumpEventQueue();

        expect(getCount(), greaterThanOrEqualTo(1));
        form.dispose();
      });

      test('fires on subform field change', () async {
        subform.registerFields([subformField]);
        form
          ..registerFields([field1, field2])
          ..addSubform(subform);

        await pumpEventQueue();
        final getCount = _countCalls(form.onValuesChanged);
        subformField.setValue(123);
        await pumpEventQueue();

        expect(getCount(), greaterThanOrEqualTo(1));
        form.dispose();
      });

      test('fires when new fields are registered', () async {
        form.registerFields([field1]);
        await pumpEventQueue();
        final getCount = _countCalls(form.onValuesChanged);

        form.registerFields([field1, field2]);
        await pumpEventQueue();

        expect(getCount(), greaterThanOrEqualTo(1));
        form.dispose();
        subform.dispose();
        subformField.dispose();
      });

      test('fires when new fields are registered for subform', () async {
        form
          ..registerFields([field1])
          ..addSubform(subform);
        await pumpEventQueue();
        final getCount = _countCalls(form.onValuesChanged);

        subform.registerFields([subformField]);
        await pumpEventQueue();

        expect(getCount(), greaterThanOrEqualTo(1));
        form.dispose();
        field2.dispose();
      });

      test('does not fire on validation error', () async {
        form.registerFields([field1, field2]);
        await pumpEventQueue();
        final getCount = _countCalls(form.onValuesChanged);

        field1.setError(_Error1.valueRequired);
        await Future<void>.delayed(const Duration(milliseconds: 10));

        expect(getCount(), 0);
        form.dispose();
        subform.dispose();
        subformField.dispose();
      });

      test('does not fire on a mode change', () async {
        form.registerFields([field1, field2]);
        await pumpEventQueue();
        final getCount = _countCalls(form.onValuesChanged);

        field1.setValidationMode(ValidationMode.onUserInteraction);
        await Future<void>.delayed(const Duration(milliseconds: 10));

        expect(getCount(), 0);
        form.dispose();
        subform.dispose();
        subformField.dispose();
      });

      test('does not fire on same value', () async {
        form.registerFields([field1, field2]);
        field1.setValue('value');
        await pumpEventQueue();
        final getCount = _countCalls(form.onValuesChanged);

        field1.setValue('value');
        await Future<void>.delayed(const Duration(milliseconds: 10));

        expect(getCount(), 0);
        form.dispose();
        subform.dispose();
        subformField.dispose();
      });
    });

    test('markReadOnly', () {
      subform.registerFields([subformField]);
      form
        ..registerFields([field1, field2])
        ..addSubform(subform)
        ..markReadOnly();

      expect(field1.value.readOnly, true);
      expect(field2.value.readOnly, true);
      expect(subformField.value.readOnly, true);
      form.dispose();
    });

    test('clearErrors', () {
      field1.setError(_Error1.valueRequired);
      field2.setError(_Error2.malformed);
      subformField.setError(_Error2.malformed);

      subform.registerFields([subformField]);
      form
        ..registerFields([field1, field2])
        ..addSubform(subform)
        ..clearErrors();

      expect(field1.value.error, null);
      expect(field2.value.error, null);
      expect(subformField.value.error, null);

      expect(field1.value.isValid, true);
      expect(field2.value.isValid, true);
      expect(subformField.value.isValid, true);
      form.dispose();
    });

    group('setValidationMode', () {
      test('reaches every field and subform', () {
        subform.registerFields([subformField]);
        form
          ..registerFields([field1, field2])
          ..addSubform(subform)
          ..setValidationMode(ValidationMode.onUserInteraction);

        expect(form.value.validationMode, ValidationMode.onUserInteraction);
        expect(field1.value.validationMode, ValidationMode.onUserInteraction);
        expect(field2.value.validationMode, ValidationMode.onUserInteraction);
        expect(
          subformField.value.validationMode,
          ValidationMode.onUserInteraction,
        );
        form.dispose();
      });

      test('a later change reaches them too', () {
        subform.registerFields([subformField]);
        form
          ..registerFields([field1, field2])
          ..addSubform(subform)
          ..setValidationMode(ValidationMode.onUserInteraction)
          ..setValidationMode(ValidationMode.onUnfocus);

        expect(field1.value.validationMode, ValidationMode.onUnfocus);
        expect(field2.value.validationMode, ValidationMode.onUnfocus);
        expect(subformField.value.validationMode, ValidationMode.onUnfocus);
        form.dispose();
      });

      test('reaches fields registered afterwards', () {
        form
          ..setValidationMode(ValidationMode.onUserInteraction)
          ..registerFields([field1, field2]);

        expect(field1.value.validationMode, ValidationMode.onUserInteraction);
        expect(field2.value.validationMode, ValidationMode.onUserInteraction);
        form.dispose();
        subform.dispose();
        subformField.dispose();
      });

      test('reaches a subform attached afterwards, and its later fields', () {
        form
          ..registerFields([field1, field2])
          ..setValidationMode(ValidationMode.onUnfocus)
          ..addSubform(subform);
        subform.registerFields([subformField]);

        expect(subform.value.validationMode, ValidationMode.onUnfocus);
        expect(subformField.value.validationMode, ValidationMode.onUnfocus);
        form.dispose();
      });

      test('a subform attached after a submit behaves like one attached before',
          () async {
        final early = AdvancedFormController();
        final earlyField = AdvancedFieldController<int, _Error2>(
          initialValue: 0,
          validator: validator2,
        );
        early.registerFields([earlyField]);
        form
          ..registerFields([field1])
          ..setValidationMode(ValidationMode.onUserInteraction)
          ..addSubform(early);

        await form.validate();

        subform.registerFields([subformField]);
        form.addSubform(subform);

        expect(
          subformField.value.validationMode,
          earlyField.value.validationMode,
        );
        expect(
          subformField.value.validationMode,
          ValidationMode.onUserInteraction,
        );
        form.dispose();
        field2.dispose();
      });

      test('leaves the fields of a de-registered batch quiet', () {
        form
          ..registerFields([field1, field2])
          ..setValidationMode(ValidationMode.onUserInteraction)
          ..registerFields([field2]);

        expect(field1.value.validationMode, ValidationMode.manual);
        expect(field2.value.validationMode, ValidationMode.onUserInteraction);
        form.dispose();
        subform.dispose();
        subformField.dispose();
      });
    });

    group('addSubform', () {
      test('adds a new subform', () {
        final emissions = _record<AdvancedFormState>(form);
        form.addSubform(subform);
        expect(emissions, [
          AdvancedFormState(subforms: {subform}),
        ]);
        form.dispose();
        field1.dispose();
        field2.dispose();
        subformField.dispose();
      });

      test('is noop if form was already added', () {
        form.addSubform(subform);
        final emissions = _record<AdvancedFormState>(form);
        form.addSubform(subform);
        expect(emissions, isEmpty);
        form.dispose();
        field1.dispose();
        field2.dispose();
        subformField.dispose();
      });
    });

    group('validateAll', () {
      late AdvancedFormController validateAllForm;

      setUp(() {
        validateAllForm = AdvancedFormController(validateAll: true);
      });

      test('validate is called on other live fields', () async {
        subform.registerFields([subformField]);
        validateAllForm
          ..registerFields([field1, field2])
          ..addSubform(subform);
        field1
          ..setValidationMode(ValidationMode.onUserInteraction)
          // The guarantee: only a field the user has edited revalidates.
          ..setValue('edited');
        validator1.validationResult = _Error1.valueRequired;

        field2.setValue(42);
        await pumpEventQueue();

        expect(field1.value.error, _Error1.valueRequired);
        expect(field2.value.error, null);
        expect(subformField.value.error, null);
        validateAllForm.dispose();
      });

      test('validate is called on other live subforms', () async {
        subform.registerFields([subformField]);
        validateAllForm
          ..registerFields([field1, field2])
          ..addSubform(subform);
        subformField
          ..setValidationMode(ValidationMode.onUserInteraction)
          // The guarantee: only a field the user has edited revalidates.
          ..setValue(7);
        validator2.validationResult = _Error2.malformed;

        field2.setValue(42);
        await pumpEventQueue();

        expect(field1.value.error, null);
        expect(field2.value.error, null);
        expect(subformField.value.error, _Error2.malformed);
        validateAllForm.dispose();
      });
    });

    group('setValidationEnabled', () {
      test('sets validationEnabled to false', () {
        final emissions = _record<AdvancedFormState>(form);
        form.setValidationEnabled(false);
        expect(emissions, [
          const AdvancedFormState(validationEnabled: false),
        ]);
        form.dispose();
        field1.dispose();
        field2.dispose();
        subform.dispose();
        subformField.dispose();
      });

      test('sets validationEnabled to true', () {
        form.setValidationEnabled(false);
        final emissions = _record<AdvancedFormState>(form);
        form.setValidationEnabled(true);
        expect(emissions, [const AdvancedFormState()]);
        form.dispose();
        field1.dispose();
        field2.dispose();
        subform.dispose();
        subformField.dispose();
      });

      test('is noop if the same validationEnabled was already set', () {
        final emissions = _record<AdvancedFormState>(form);
        form.setValidationEnabled(true);
        expect(emissions, isEmpty);
        form.dispose();
        field1.dispose();
        field2.dispose();
        subform.dispose();
        subformField.dispose();
      });

      test(
          'clears errors when validationEnabled is set to false and was true before',
          () {
        field1.setError(_Error1.valueRequired);
        field2.setError(_Error2.malformed);
        subformField.setError(_Error2.malformed);
        subform.registerFields([subformField]);

        form
          ..setValidationEnabled(true)
          ..registerFields([field1, field2])
          ..addSubform(subform)
          ..setValidationEnabled(false);

        expect(field1.value.error, null);
        expect(field2.value.error, null);
        expect(subformField.value.error, null);
        form.dispose();
      });

      test('does not clear errors when validationEnabled is set to true', () {
        subform.registerFields([subformField]);
        form
          ..setValidationEnabled(false)
          ..registerFields([field1, field2])
          ..addSubform(subform);

        field1.setError(_Error1.valueRequired);
        field2.setError(_Error2.malformed);
        subformField.setError(_Error2.malformed);

        form.setValidationEnabled(true);

        expect(field1.value.error, _Error1.valueRequired);
        expect(field2.value.error, _Error2.malformed);
        expect(subformField.value.error, _Error2.malformed);
        form.dispose();
      });

      test(
          'does not clear errors when validationEnabled is set to false and was already false before',
          () {
        subform.registerFields([subformField]);
        form
          ..setValidationEnabled(false)
          ..registerFields([field1, field2])
          ..addSubform(subform);

        field1.setError(_Error1.valueRequired);
        field2.setError(_Error2.malformed);
        subformField.setError(_Error2.malformed);

        form.setValidationEnabled(false);

        expect(field1.value.error, _Error1.valueRequired);
        expect(field2.value.error, _Error2.malformed);
        expect(subformField.value.error, _Error2.malformed);
        form.dispose();
      });
    });

    group('removeSubform', () {
      test('detaches a previously added subform without disposing it',
          () async {
        form.addSubform(subform);
        final emissions = _record<AdvancedFormState>(form);

        form.removeSubform(subform);

        expect(emissions, [const AdvancedFormState()]);
        expect(subform.isDisposed, isFalse);

        form.dispose();
        field1.dispose();
        field2.dispose();
        subformField.dispose();
      });

      test('a detached subform is re-attachable', () async {
        form
          ..addSubform(subform)
          ..removeSubform(subform)
          ..addSubform(subform);

        expect(form.value.subforms, {subform});

        form.dispose();
        field1.dispose();
        field2.dispose();
        subformField.dispose();
      });

      test('is noop if form was not added', () async {
        final emissions = _record<AdvancedFormState>(form);
        form.removeSubform(subform);
        expect(emissions, isEmpty);
        form.dispose();
        subform.dispose();
        field1.dispose();
        field2.dispose();
        subformField.dispose();
      });
    });

    test('disposes all dependencies', () {
      subform.registerFields([subformField]);
      form
        ..registerFields([field1, field2])
        ..addSubform(subform)
        ..dispose();

      expect(field1.isDisposed, isTrue);
      expect(field2.isDisposed, isTrue);
      expect(subform.isDisposed, isTrue);
      expect(subformField.isDisposed, isTrue);
    });

    test('disposes a subform it no longer holds', () {
      form
        ..addSubform(subform)
        ..removeSubform(subform)
        ..dispose();

      expect(subform.isDisposed, isTrue);
      field1.dispose();
      field2.dispose();
      subformField.dispose();
    });

    test('skips a subform the caller disposed itself', () {
      form
        ..addSubform(subform)
        ..removeSubform(subform);
      subform.dispose();

      expect(form.dispose, returnsNormally);

      field1.dispose();
      field2.dispose();
      subformField.dispose();
    });

    group('resetAll', () {
      test('resets all fields state to initial', () {
        subform.registerFields([subformField]);
        form
          ..registerFields([field1, field2])
          ..addSubform(subform);

        field1.setValue('value');
        field2.setValue(42);
        subformField.setValue(42);

        form.resetAll();

        expect(field1.value.value, _initialValue1);
        expect(field2.value.value, _initialValue2);
        expect(subformField.value.value, _initialValue2);
        form.dispose();
      });
    });

    group('revalidateSync', () {
      test('validates only the live fields the user has edited', () {
        subform.registerFields([subformField]);
        form
          ..registerFields([field1, field2])
          ..addSubform(subform);

        field1
          ..setValidationMode(ValidationMode.onUserInteraction)
          ..setValue('edited');
        field2
          ..setValidationMode(ValidationMode.manual)
          ..setValue(1);
        subformField
          ..setValidationMode(ValidationMode.onUserInteraction)
          ..setValue(1);

        validator1.validationResult = _Error1.valueRequired;
        validator2.validationResult = _Error2.malformed;

        form.revalidateSync();

        expect(field1.value.error, _Error1.valueRequired);
        expect(field2.value.error, null);
        expect(subformField.value.error, _Error2.malformed);
        form.dispose();
      });

      test('re-runs the sync validator of a read-only field', () {
        form.registerFields([field1]);
        field1
          ..setValidationMode(ValidationMode.onUserInteraction)
          ..setValue('edited')
          ..markReadOnly();
        validator1.validationResult = _Error1.valueRequired;

        form.revalidateSync();

        expect(field1.value.error, _Error1.valueRequired);
        form.dispose();
      });

      test('keeps a settled async answer when a sibling changes', () async {
        var asyncCalls = 0;
        final email = AdvancedTextFieldController<_Error1>();
        late final AdvancedTextFieldController<_Error1> confirm;
        confirm = AdvancedTextFieldController<_Error1>(
          validator: (value) =>
              value == email.fieldValue ? null : _Error1.valueRequired,
          asyncValidation: AsyncValidation(
            validator: (_) async {
              asyncCalls++;
              return _Error1.taken;
            },
            debounce: const Duration(milliseconds: 10),
          ),
        );
        final crossForm = AdvancedFormController(validateAll: true)
          ..registerFields([email, confirm]);

        email.setValue('a@x.com');
        crossForm.setValidationMode(ValidationMode.onUserInteraction);
        confirm.setValue('a@x.com');
        await Future<void>.delayed(const Duration(milliseconds: 120));

        expect(confirm.value.asyncError, _Error1.taken);
        expect(asyncCalls, 1);

        // The user edits the *other* field. `confirm`'s cross-field rule now
        // fails, but its own value never changed, so its verdict still stands
        // and nothing is owed to the network.
        email.setValue('a@x.corn');
        await Future<void>.delayed(const Duration(milliseconds: 120));

        expect(confirm.value.validationError, _Error1.valueRequired);
        expect(confirm.value.asyncError, _Error1.taken);
        expect(confirm.value.isInProgress, false);
        expect(asyncCalls, 1);

        crossForm.dispose();
      });
    });

    group('derived aggregates', () {
      /// A field whose async validator takes [delay] to answer [result].
      AdvancedFieldController<int, _Error2> asyncField({
        Duration delay = const Duration(milliseconds: 100),
        _Error2? Function()? result,
        bool throws = false,
      }) =>
          AdvancedFieldController<int, _Error2>(
            initialValue: 0,
            asyncValidation: AsyncValidation(
              validator: (_) async {
                await Future<void>.delayed(delay);
                if (throws) {
                  throw StateError('validator exploded');
                }
                return result?.call();
              },
              debounce: const Duration(milliseconds: 10),
              onFailure: (error, stackTrace) async {},
            ),
          )..setValidationMode(ValidationMode.onUserInteraction);

      test('validating follows the fields rather than a stored flag', () async {
        final live = asyncField();
        form.registerFields([live]);
        addTearDown(form.dispose);
        addTearDown(field1.dispose);
        addTearDown(field2.dispose);
        addTearDown(subform.dispose);
        addTearDown(subformField.dispose);

        expect(form.value.validating, isFalse);

        live.setValue(10);
        expect(form.value.validating, isTrue);

        await Future<void>.delayed(const Duration(milliseconds: 300));
        expect(form.value.validating, isFalse);
      });

      test('removeSubform mid-validation clears validating and wasModified',
          () async {
        final live = asyncField();
        final liveSubform = AdvancedFormController()..registerFields([live]);
        form.addSubform(liveSubform);
        addTearDown(form.dispose);
        addTearDown(field1.dispose);
        addTearDown(field2.dispose);
        addTearDown(subform.dispose);
        addTearDown(subformField.dispose);

        live.setValue(10);
        await pumpEventQueue();
        expect(form.value.validating, isTrue);
        expect(form.value.wasModified, isTrue);

        form.removeSubform(liveSubform);

        expect(form.value.validating, isFalse);
        expect(form.value.wasModified, isFalse);
      });

      test('registerFields mid-validation rebaselines wasModified', () async {
        final live = asyncField();
        form.registerFields([live]);
        addTearDown(form.dispose);
        addTearDown(field1.dispose);
        addTearDown(field2.dispose);
        addTearDown(subform.dispose);
        addTearDown(subformField.dispose);

        live.setValue(10);
        await pumpEventQueue();
        expect(form.value.wasModified, isTrue);
        expect(form.value.validating, isTrue);

        form.registerFields([live]);

        expect(form.value.wasModified, isFalse);
        expect(form.value.validating, isTrue);

        await Future<void>.delayed(const Duration(milliseconds: 300));
        expect(form.value.validating, isFalse);
      });

      test('hasFailedValidation reports a round that could not complete',
          () async {
        final failing = asyncField(throws: true);
        form.registerFields([failing]);
        addTearDown(form.dispose);
        addTearDown(field1.dispose);
        addTearDown(field2.dispose);
        addTearDown(subform.dispose);
        addTearDown(subformField.dispose);

        expect(form.value.hasFailedValidation, isFalse);

        expect(await form.validate(), isFalse);

        expect(form.value.hasFailedValidation, isTrue);
        expect(form.value.canSubmit, isFalse);
      });

      test('canSubmit is a snapshot of known errors', () async {
        validator1.validationResult = _Error1.valueRequired;
        form.registerFields([field1, field2]);
        addTearDown(form.dispose);
        addTearDown(subform.dispose);
        addTearDown(subformField.dispose);

        // Nothing has been checked yet.
        expect(form.value.canSubmit, isTrue);

        expect(await form.validate(), isFalse);
        expect(form.value.canSubmit, isFalse);
      });

      test('validationErrors includes a field invalid from an async check',
          () async {
        final rejected = asyncField(result: () => _Error2.malformed);
        form.registerFields([rejected]);
        addTearDown(form.dispose);
        addTearDown(field1.dispose);
        addTearDown(field2.dispose);
        addTearDown(subform.dispose);
        addTearDown(subformField.dispose);

        expect(await form.validate(), isFalse);

        expect(rejected.value.validationError, isNull);
        expect(rejected.value.asyncError, _Error2.malformed);
        expect(form.value.validationErrors, {rejected: _Error2.malformed});
      });

      test('notifies listeners when a derived aggregate changes', () async {
        final live = asyncField();
        form.registerFields([live]);
        addTearDown(form.dispose);
        addTearDown(field1.dispose);
        addTearDown(field2.dispose);
        addTearDown(subform.dispose);
        addTearDown(subformField.dispose);

        final getCount = _countCalls(form);

        live.setValue(10);
        await Future<void>.delayed(const Duration(milliseconds: 300));

        expect(getCount(), greaterThanOrEqualTo(2));
      });

      test('notifies when a field swaps one error code for another', () async {
        form.registerFields([field1, field2]);
        addTearDown(form.dispose);
        addTearDown(subform.dispose);
        addTearDown(subformField.dispose);

        field1.setError(_Error1.valueRequired);
        await pumpEventQueue();
        expect(form.value.validationErrors, {field1: _Error1.valueRequired});

        final getCount = _countCalls(form);
        final getStatusCount = _countCalls(form.onStatusChanged);
        final getValuesCount = _countCalls(form.onValuesChanged);

        // The status stays `invalid`, so only the error tells the form that a
        // derived aggregate moved.
        field1.setError(_Error1.taken);

        expect(field1.value.status, FieldStatus.invalid);
        expect(form.value.validationErrors, {field1: _Error1.taken});
        expect(getCount(), 1);
        expect(getStatusCount(), 1);
        expect(getValuesCount(), 0);
      });

      test('notifies when a subform field swaps one error code for another',
          () async {
        subform.registerFields([field1]);
        form
          ..addSubform(subform)
          ..registerFields([field2]);
        addTearDown(form.dispose);
        addTearDown(subformField.dispose);

        field1.setError(_Error1.valueRequired);
        await pumpEventQueue();

        final getCount = _countCalls(form);
        final getStatusCount = _countCalls(form.onStatusChanged);

        field1.setError(_Error1.taken);

        expect(form.value.validationErrors, {field1: _Error1.taken});
        expect(getCount(), 1);
        expect(getStatusCount(), 1);
      });
    });

    group('addSubform — disposed guards', () {
      test('isDisposed flips from false to true after dispose', () {
        final f = AdvancedFormController();
        expect(f.isDisposed, false);
        f.dispose();
        expect(f.isDisposed, true);
      });

      test('throws StateError when the parent has been disposed', () {
        final parent = AdvancedFormController()..dispose();
        final child = AdvancedFormController();
        addTearDown(child.dispose);

        expect(() => parent.addSubform(child), throwsStateError);
      });

      test('throws StateError when the subform has been disposed', () {
        final parent = AdvancedFormController();
        addTearDown(parent.dispose);
        final child = AdvancedFormController()..dispose();

        expect(() => parent.addSubform(child), throwsStateError);
      });

      test('registerFields throws StateError when disposed', () {
        final f = AdvancedFormController()..dispose();
        final field = AdvancedFieldController<int, _Error2>(initialValue: 0);
        addTearDown(field.dispose);

        expect(() => f.registerFields([field]), throwsStateError);
      });

      test('registerFields throws StateError when a field has been disposed',
          () {
        final f = AdvancedFormController();
        addTearDown(f.dispose);
        final field = AdvancedFieldController<int, _Error2>(initialValue: 0)
          ..dispose();

        expect(() => f.registerFields([field]), throwsStateError);
      });

      test('setValidationEnabled throws StateError when disposed', () {
        final f = AdvancedFormController()..dispose();

        expect(() => f.setValidationEnabled(false), throwsStateError);
      });

      test('removeSubform throws StateError when disposed', () {
        final parent = AdvancedFormController();
        final child = AdvancedFormController();
        parent
          ..addSubform(child)
          ..dispose();

        expect(() => parent.removeSubform(child), throwsStateError);
      });
    });

    group('addRelation', () {
      test('calls onChange with the new part when the selected part changes',
          () {
        form.registerFields([field2]);
        final parts = <int>[];
        form.addRelation(field2, (value) => value ~/ 10, parts.add);

        field2.setValue(9);
        expect(parts, isEmpty);

        field2.setValue(25);
        expect(parts, [2]);

        form.dispose();
      });

      test('does not fire on a status-only change', () {
        form.registerFields([field2]);
        final parts = <int>[];
        form.addRelation(field2, (value) => value, parts.add);

        field2.setError(_Error2.malformed);
        expect(parts, isEmpty);

        form.dispose();
      });

      test('stops listening when the form is disposed', () {
        addTearDown(field2.dispose);
        final parts = <int>[];
        form
          ..addRelation(field2, (value) => value, parts.add)
          ..dispose();

        field2.setValue(42);
        expect(parts, isEmpty);
      });

      test('throws StateError when the form or the source is disposed', () {
        final disposedForm = AdvancedFormController()..dispose();
        expect(
          () => disposedForm.addRelation(field2, (value) => value, (_) {}),
          throwsStateError,
        );

        field2.dispose();
        expect(
          () => form.addRelation(field2, (value) => value, (_) {}),
          throwsStateError,
        );
        form.dispose();
      });
    });

    group('AdvancedTextFieldController focusNode', () {
      test('throws StateError when read after dispose', () {
        final field = AdvancedTextFieldController<_Error1>()..dispose();

        expect(() => field.focusNode, throwsStateError);
      });

      test('dispose is safe when the focusNode was never read', () {
        final field = AdvancedTextFieldController<_Error1>();

        expect(field.dispose, returnsNormally);
      });
    });

    group('validation mode and the validation switch', () {
      test('a subform keeps a mode of its own against its parent', () {
        final own = AdvancedFormController(
          validationMode: ValidationMode.onUnfocus,
        )..registerFields([subformField]);
        form
          ..registerFields([field1, field2])
          ..addSubform(own)
          ..setValidationMode(ValidationMode.onUserInteraction);

        expect(own.value.validationMode, ValidationMode.onUnfocus);
        expect(subformField.value.validationMode, ValidationMode.onUnfocus);
        expect(field1.value.validationMode, ValidationMode.onUserInteraction);
        form.dispose();
      });

      test('a subform that claims a mode later keeps it too', () {
        subform.registerFields([subformField]);
        form
          ..registerFields([field1])
          ..addSubform(subform)
          ..setValidationMode(ValidationMode.onUserInteraction);

        subform.setValidationMode(ValidationMode.onUnfocus);
        form.setValidationMode(ValidationMode.manual);

        expect(subformField.value.validationMode, ValidationMode.onUnfocus);
        expect(field1.value.validationMode, ValidationMode.manual);
        form.dispose();
        field2.dispose();
      });

      test('the parent switch outranks a subform that claimed a mode', () {
        subform.registerFields([subformField]);
        form
          ..registerFields([field1])
          ..addSubform(subform);
        subform.setValidationMode(ValidationMode.onUserInteraction);

        form.setValidationEnabled(false);
        expect(subformField.value.validationMode, ValidationMode.manual);
        expect(subform.value.validationEnabled, isFalse);

        form.setValidationEnabled(true);
        expect(
          subformField.value.validationMode,
          ValidationMode.onUserInteraction,
        );
        form.dispose();
        field2.dispose();
      });

      test(
          'a subform that switched itself off stays off when the parent '
          'switches back on', () {
        subform.registerFields([subformField]);
        form
          ..registerFields([field1])
          ..addSubform(subform);

        subform.setValidationEnabled(false);
        form
          ..setValidationEnabled(false)
          ..setValidationEnabled(true);

        expect(form.value.validationEnabled, isTrue);
        expect(subform.value.validationEnabled, isFalse);
        form.dispose();
        field2.dispose();
      });

      test('a switched-off subtree does not count toward canSubmit', () async {
        subform.registerFields([subformField]);
        form
          ..registerFields([field1])
          ..addSubform(subform);
        subformField.setError(_Error2.malformed);
        expect(form.value.canSubmit, isFalse);

        subform.setValidationEnabled(false);

        expect(form.value.canSubmit, isTrue);
        expect(form.value.validationErrors, isEmpty);
        expect(await form.validate(), isTrue);
        form.dispose();
        field2.dispose();
      });

      test('a switched-off subtree runs no validators on an edit', () async {
        validator2.validationResult = _Error2.malformed;
        subform.registerFields([subformField]);
        form
          ..registerFields([field1])
          ..addSubform(subform)
          ..setValidationMode(ValidationMode.onUserInteraction);
        subform.setValidationEnabled(false);

        subformField.setValue(42);
        await pumpEventQueue();

        expect(subformField.value.error, isNull);
        form.dispose();
        field2.dispose();
      });
    });

    test('a throwing sync validator reports its error once, to the caller',
        () async {
      final unhandled = <Object>[];

      await runZonedGuarded(
        () async {
          final field = AdvancedFieldController<int, _Error2>(
            initialValue: 0,
            validator: (_) => throw StateError('validator exploded'),
          );
          final f = AdvancedFormController()..registerFields([field]);

          await expectLater(f.validate(), throwsStateError);
          // Give an unhandled error a turn to reach the zone.
          await Future<void>.delayed(const Duration(milliseconds: 50));
          f.dispose();
        },
        (error, stackTrace) => unhandled.add(error),
      );

      expect(unhandled, isEmpty);
    });
  });
}
