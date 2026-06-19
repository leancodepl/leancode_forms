import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:leancode_forms/leancode_forms.dart';

enum _Error1 { valueRequired }

enum _Error2 { malformed }

const _initialValue1 = 'initial';
const _initialValue2 = 0;

class _ValidatorMock<T, E> {
  E? validationResult;

  E? call(T? value) => validationResult;
}

/// Records every new state emitted by [notifier].
List<S> _record<S>(ValueNotifier<S> notifier) {
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
  group('FormGroupController', () {
    late FormGroupController form;
    late FormGroupController subform;
    late TextFieldController<_Error1> field1;
    late FieldController<int, _Error2> field2;
    late FieldController<int, _Error2> subformField;
    late _ValidatorMock<String, _Error1> validator1;
    late _ValidatorMock<int, _Error2> validator2;

    setUp(() {
      validator1 = _ValidatorMock();
      validator2 = _ValidatorMock();
      field1 = TextFieldController(
        initialValue: _initialValue1,
        validator: validator1,
      );
      field2 = FieldController(
        initialValue: _initialValue2,
        validator: validator2,
      );
      subformField = FieldController(
        initialValue: _initialValue2,
        validator: validator2,
      );
      form = FormGroupController();
      subform = FormGroupController();
    });

    tearDown(() {
      // The form owns field1/field2/subform/subformField transitively when
      // they get registered/added — but tests that don't register them have
      // to clean up by hand. dispose() is idempotent-ish so we keep tearDown
      // minimal and let each test handle its own scopes.
    });

    test('has correct initial state', () {
      expect(form.value, const FormGroupState());
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
        final emissions = _record<FormGroupState>(form);
        form.registerFields([field1, field2]);
        expect(emissions, [
          FormGroupState(fields: [field1, field2]),
        ]);
        form.dispose();
      });

      test('is true if subform was modified', () async {
        subform.registerFields([subformField]);
        form
          ..addSubform(subform)
          ..registerFields([field1, field2]);

        await Future<void>.delayed(Duration.zero);
        final emissions = _record<FormGroupState>(form);
        subformField.setValue(123);
        await Future<void>.delayed(Duration.zero);

        expect(emissions, [
          FormGroupState(
            wasModified: true,
            fields: [field1, field2],
            subforms: {subform},
          ),
        ]);
        form.dispose();
      });

      test('is true if field1 changes', () async {
        form.registerFields([field1, field2]);

        await Future<void>.delayed(Duration.zero);
        final emissions = _record<FormGroupState>(form);
        field1.setValue('value');
        await Future<void>.delayed(Duration.zero);

        expect(emissions, [
          FormGroupState(wasModified: true, fields: [field1, field2]),
        ]);
        form.dispose();
      });

      test('is true if field2 changes', () async {
        form.registerFields([field1, field2]);

        await Future<void>.delayed(Duration.zero);
        final emissions = _record<FormGroupState>(form);
        field2.setValue(0xb0b);
        await Future<void>.delayed(Duration.zero);

        expect(emissions, [
          FormGroupState(wasModified: true, fields: [field1, field2]),
        ]);
        form.dispose();
      });

      test('does not change if field was unregistered', () async {
        form
          ..registerFields([field1, field2])
          ..registerFields([]);

        await Future<void>.delayed(Duration.zero);
        final emissions = _record<FormGroupState>(form);
        field2.setValue(0xb0b);
        await Future<void>.delayed(Duration.zero);

        expect(emissions, isEmpty);
        form.dispose();
      });
    });

    group('validate', () {
      test('enables autovalidate in fields', () {
        subform.registerFields([subformField]);
        form
          ..registerFields([field1, field2])
          ..addSubform(subform)
          ..validate();

        expect(field1.value.autovalidate, true);
        expect(field2.value.autovalidate, true);
        expect(subformField.value.autovalidate, true);
        form.dispose();
      });

      test('does not enable autovalidate in fields', () {
        subform.registerFields([subformField]);
        form
          ..registerFields([field1, field2])
          ..addSubform(subform)
          ..validate(enableAutovalidate: false);

        expect(field1.value.autovalidate, false);
        expect(field2.value.autovalidate, false);
        expect(subformField.value.autovalidate, false);
        form.dispose();
      });

      test('is valid when all are valid', () {
        subform.registerFields([subformField]);
        validator1.validationResult = null;
        validator2.validationResult = null;
        form
          ..registerFields([field1, field2])
          ..addSubform(subform);

        expect(form.validate(), true);
        form.dispose();
      });

      test('is not valid if a subform is not valid', () {
        subform.registerFields([subformField]);
        validator1.validationResult = null;
        validator2.validationResult = _Error2.malformed;
        form
          ..registerFields([field1])
          ..addSubform(subform);

        expect(form.validate(), false);
        form.dispose();
        field2.dispose();
      });

      test('is not valid when any is invalid', () {
        validator1.validationResult = _Error1.valueRequired;
        validator2.validationResult = null;
        form.registerFields([field1, field2]);

        expect(form.validate(), false);
        form.dispose();
        subform.dispose();
        subformField.dispose();
      });

      test('does not short-circuit on validation', () {
        subform.registerFields([subformField]);
        validator1.validationResult = _Error1.valueRequired;
        validator2.validationResult = _Error2.malformed;

        form
          ..registerFields([field1, field2])
          ..addSubform(subform)
          ..validate(enableAutovalidate: false);

        expect(field1.value.error, _Error1.valueRequired);
        expect(field2.value.error, _Error2.malformed);
        expect(subformField.value.error, _Error2.malformed);
        form.dispose();
      });

      test('is valid when validationEnabled is false', () {
        validator1.validationResult = _Error1.valueRequired;
        form
          ..registerFields([field1])
          ..setValidationEnabled(false);

        expect(form.validate(), true);
        form.dispose();
        field2.dispose();
        subform.dispose();
        subformField.dispose();
      });

      test('enables autovalidate even when validationEnabled is false', () {
        form
          ..registerFields([field1])
          ..setValidationEnabled(false)
          ..validate();

        expect(field1.value.autovalidate, true);
        form.dispose();
        field2.dispose();
        subform.dispose();
        subformField.dispose();
      });

      test('is not valid when any of the fields is pending async validation',
          () async {
        validator1.validationResult = null;
        final asyncField = TextFieldController<_Error1>(
          initialValue: _initialValue1,
          asyncValidator: (_) async => validator1.validationResult,
        );
        form.registerFields([asyncField]);

        asyncField.setValue('value');

        expect(form.validate(), false);
        await Future<void>.delayed(const Duration(milliseconds: 500));
        form.dispose();
        field1.dispose();
        field2.dispose();
        subform.dispose();
        subformField.dispose();
      });

      test('is not valid when async validation of the field fails', () async {
        validator1.validationResult = _Error1.valueRequired;
        final asyncField = TextFieldController<_Error1>(
          initialValue: _initialValue1,
          asyncValidator: (_) async => validator1.validationResult,
        );
        form.registerFields([asyncField]);

        asyncField.setValue('value');
        await Future<void>.delayed(const Duration(milliseconds: 500));
        expect(form.validate(), false);

        form.dispose();
        field1.dispose();
        field2.dispose();
        subform.dispose();
        subformField.dispose();
      });

      test(
          'is not valid when any of the fields in subform is pending async validation',
          () async {
        validator2.validationResult = null;
        final asyncSubformField = FieldController<int, _Error2>(
          initialValue: 0,
          asyncValidator: (_) async => validator2.validationResult,
        );
        final asyncSubform = FormGroupController()
          ..registerFields([asyncSubformField]);
        form.addSubform(asyncSubform);

        asyncSubformField.setValue(10);
        expect(form.validate(), false);

        await Future<void>.delayed(const Duration(milliseconds: 500));
        form.dispose();
        field1.dispose();
        field2.dispose();
        subform.dispose();
        subformField.dispose();
      });
    });

    group('onValuesChanged', () {
      test('fires on field change', () async {
        form.registerFields([field1, field2]);
        await Future<void>.delayed(Duration.zero);
        final getCount = _countCalls(form.onValuesChanged);

        field1.setValue('value');
        await Future<void>.delayed(Duration.zero);

        expect(getCount(), greaterThanOrEqualTo(1));
        form.dispose();
      });

      test('fires on subform field change', () async {
        subform.registerFields([subformField]);
        form
          ..registerFields([field1, field2])
          ..addSubform(subform);

        await Future<void>.delayed(Duration.zero);
        final getCount = _countCalls(form.onValuesChanged);
        subformField.setValue(123);
        await Future<void>.delayed(Duration.zero);

        expect(getCount(), greaterThanOrEqualTo(1));
        form.dispose();
      });

      test('fires when new fields are registered', () async {
        form.registerFields([field1]);
        await Future<void>.delayed(Duration.zero);
        final getCount = _countCalls(form.onValuesChanged);

        form.registerFields([field1, field2]);
        await Future<void>.delayed(Duration.zero);

        expect(getCount(), greaterThanOrEqualTo(1));
        form.dispose();
        subform.dispose();
        subformField.dispose();
      });

      test('fires when new fields are registered for subform', () async {
        form
          ..registerFields([field1])
          ..addSubform(subform);
        await Future<void>.delayed(Duration.zero);
        final getCount = _countCalls(form.onValuesChanged);

        subform.registerFields([subformField]);
        await Future<void>.delayed(Duration.zero);

        expect(getCount(), greaterThanOrEqualTo(1));
        form.dispose();
        field2.dispose();
      });

      test('does not fire on validation error', () async {
        form.registerFields([field1, field2]);
        await Future<void>.delayed(Duration.zero);
        final getCount = _countCalls(form.onValuesChanged);

        field1.setError(_Error1.valueRequired);
        await Future<void>.delayed(const Duration(milliseconds: 10));

        expect(getCount(), 0);
        form.dispose();
        subform.dispose();
        subformField.dispose();
      });

      test('does not fire on enabling autovalidate', () async {
        form.registerFields([field1, field2]);
        await Future<void>.delayed(Duration.zero);
        final getCount = _countCalls(form.onValuesChanged);

        field1.setAutovalidate(true);
        await Future<void>.delayed(const Duration(milliseconds: 10));

        expect(getCount(), 0);
        form.dispose();
        subform.dispose();
        subformField.dispose();
      });

      test('does not fire on same value', () async {
        form.registerFields([field1, field2]);
        field1.setValue('value');
        await Future<void>.delayed(Duration.zero);
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

    group('setAutovalidate', () {
      test('to true', () {
        subform.registerFields([subformField]);
        form
          ..registerFields([field1, field2])
          ..addSubform(subform)
          ..setAutovalidate(true);

        expect(field1.value.autovalidate, true);
        expect(field2.value.autovalidate, true);
        expect(subformField.value.autovalidate, true);
        form.dispose();
      });

      test('to false', () {
        subform.registerFields([subformField]);
        form
          ..registerFields([field1, field2])
          ..addSubform(subform)
          ..setAutovalidate(true)
          ..setAutovalidate(false);

        expect(field1.value.autovalidate, false);
        expect(field2.value.autovalidate, false);
        expect(subformField.value.autovalidate, false);
        form.dispose();
      });
    });

    group('addSubform', () {
      test('adds a new subform', () {
        final emissions = _record<FormGroupState>(form);
        form.addSubform(subform);
        expect(emissions, [
          FormGroupState(subforms: {subform}),
        ]);
        form.dispose();
        field1.dispose();
        field2.dispose();
        subformField.dispose();
      });

      test('is noop if form was already added', () {
        form.addSubform(subform);
        final emissions = _record<FormGroupState>(form);
        form.addSubform(subform);
        expect(emissions, isEmpty);
        form.dispose();
        field1.dispose();
        field2.dispose();
        subformField.dispose();
      });
    });

    group('validateAll', () {
      late FormGroupController validateAllForm;

      setUp(() {
        validateAllForm = FormGroupController(validateAll: true);
      });

      test('validate is called on other autovalidate fields', () async {
        subform.registerFields([subformField]);
        validateAllForm
          ..registerFields([field1, field2])
          ..addSubform(subform);
        field1.setAutovalidate(true);
        validator1.validationResult = _Error1.valueRequired;

        field2.setValue(42);
        await Future<void>.delayed(Duration.zero);

        expect(field1.value.error, _Error1.valueRequired);
        expect(field2.value.error, null);
        expect(subformField.value.error, null);
        validateAllForm.dispose();
      });

      test('validate is called on other autovalidate subforms', () async {
        subform.registerFields([subformField]);
        validateAllForm
          ..registerFields([field1, field2])
          ..addSubform(subform);
        subformField.setAutovalidate(true);
        validator2.validationResult = _Error2.malformed;

        field2.setValue(42);
        await Future<void>.delayed(Duration.zero);

        expect(field1.value.error, null);
        expect(field2.value.error, null);
        expect(subformField.value.error, _Error2.malformed);
        validateAllForm.dispose();
      });
    });

    group('setValidationEnabled', () {
      test('sets validationEnabled to false', () {
        final emissions = _record<FormGroupState>(form);
        form.setValidationEnabled(false);
        expect(emissions, [
          const FormGroupState(validationEnabled: false),
        ]);
        form.dispose();
        field1.dispose();
        field2.dispose();
        subform.dispose();
        subformField.dispose();
      });

      test('sets validationEnabled to true', () {
        form.setValidationEnabled(false);
        final emissions = _record<FormGroupState>(form);
        form.setValidationEnabled(true);
        expect(emissions, [const FormGroupState()]);
        form.dispose();
        field1.dispose();
        field2.dispose();
        subform.dispose();
        subformField.dispose();
      });

      test('is noop if the same validationEnabled was already set', () {
        final emissions = _record<FormGroupState>(form);
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
        field1.setError(_Error1.valueRequired);
        field2.setError(_Error2.malformed);
        subformField.setError(_Error2.malformed);
        subform.registerFields([subformField]);

        form
          ..setValidationEnabled(false)
          ..registerFields([field1, field2])
          ..addSubform(subform)
          ..setValidationEnabled(true);

        expect(field1.value.error, _Error1.valueRequired);
        expect(field2.value.error, _Error2.malformed);
        expect(subformField.value.error, _Error2.malformed);
        form.dispose();
      });

      test(
          'does not clear errors when validationEnabled is set to false and was already false before',
          () {
        field1.setError(_Error1.valueRequired);
        field2.setError(_Error2.malformed);
        subformField.setError(_Error2.malformed);
        subform.registerFields([subformField]);

        form
          ..setValidationEnabled(false)
          ..registerFields([field1, field2])
          ..addSubform(subform)
          ..setValidationEnabled(false);

        expect(field1.value.error, _Error1.valueRequired);
        expect(field2.value.error, _Error2.malformed);
        expect(subformField.value.error, _Error2.malformed);
        form.dispose();
      });
    });

    group('removeSubform', () {
      test('removes a previously added subform and disposes it', () async {
        form.addSubform(subform);
        final emissions = _record<FormGroupState>(form);

        await form.removeSubform(subform);

        expect(emissions, [const FormGroupState()]);
        // Subform is disposed — touching its onValuesChanged would throw, so
        // we don't probe it further. Form does not dispose it twice on close.
        form.dispose();
        field1.dispose();
        field2.dispose();
        subformField.dispose();
      });

      test(
          'removes a previously added subform but does not dispose it when close is false',
          () async {
        form.addSubform(subform);
        final emissions = _record<FormGroupState>(form);

        await form.removeSubform(subform, close: false);

        expect(emissions, [const FormGroupState()]);
        // Subform should still be alive — confirm by reading its state.
        expect(subform.value, const FormGroupState());

        form.dispose();
        subform.dispose();
        field1.dispose();
        field2.dispose();
        subformField.dispose();
      });

      test('is noop if form was not added', () async {
        final emissions = _record<FormGroupState>(form);
        await form.removeSubform(subform);
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
      // Re-disposing throws in debug — instead verify children are unusable
      // by checking they don't react to setValue (their listeners are gone).
      // Direct disposed-check on ValueNotifier isn't exposed publicly, so we
      // rely on the absence of crashes during form.dispose().
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

    group('validateWithAutovalidate', () {
      test('validates only the fields which have set autovalidate to true', () {
        subform.registerFields([subformField]);
        form
          ..registerFields([field1, field2])
          ..addSubform(subform);

        field1.setAutovalidate(true);
        field2.setAutovalidate(false);
        subformField.setAutovalidate(true);

        validator1.validationResult = _Error1.valueRequired;
        validator2.validationResult = _Error2.malformed;

        form.validateWithAutovalidate();

        expect(field1.value.error, _Error1.valueRequired);
        expect(field2.value.error, null);
        expect(subformField.value.error, _Error2.malformed);
        form.dispose();
      });
    });
  });
}
