import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:leancode_forms/src/field/cubit/field_cubit.dart';
import 'package:leancode_forms/src/field/text_field_cubit.dart';
import 'package:leancode_forms/src/form_group_cubit/form_group_cubit.dart';

enum _Error1 { valueRequired }

enum _Error2 { malformed }

const _initialValue1 = 'initial';
const _initialValue2 = 0;

class _ValidatorMock<T, E> {
  E? validationResult;

  E? call(T? value) => validationResult;
}

void main() {
  group('FormGroupCubit', () {
    late FormGroupCubit form;
    late FormGroupCubit subform;
    late TextFieldCubit<_Error1> field1;
    late FieldCubit<int, _Error2> field2;
    late FieldCubit<int, _Error2> subformField;
    late _ValidatorMock<String, _Error1> validator1;
    late _ValidatorMock<int, _Error2> validator2;

    setUp(() {
      validator1 = _ValidatorMock();
      validator2 = _ValidatorMock();
      field1 = TextFieldCubit(
        initialValue: _initialValue1,
        validator: validator1,
      );
      field2 = FieldCubit(
        initialValue: _initialValue2,
        validator: validator2,
      );
      subformField = FieldCubit(
        initialValue: _initialValue2,
        validator: validator2,
      );
      form = FormGroupCubit();
      subform = FormGroupCubit();
    });

    tearDown(() async {
      await field1.close();
      await field2.close();
      await subformField.close();
      await subform.close();
      await form.close();
    });

    test('has correct initial state', () {
      expect(form.state, const FormGroupState());
    });

    group('getFieldValues', () {
      test('when no fields are registered', () {
        final values = form.getFieldValues();

        expect(values, isEmpty);
      });

      test('when fields are registered', () {
        form.registerFields([field1, field2]);
        final values = form.getFieldValues();

        expect(values, <dynamic>[_initialValue1, _initialValue2]);
      });

      test('when fields are registered and have new values', () {
        form.registerFields([field1, field2]);

        field1.setValue('hello');
        field2.setValue(10);

        final values = form.getFieldValues();

        expect(values, <dynamic>['hello', 10]);
      });

      test('when fields are unregistered', () {
        form
          ..registerFields([field1, field2])
          ..registerFields([]);

        field1.setValue('hello');
        field2.setValue(10);

        final values = form.getFieldValues();

        expect(values, isEmpty);
      });
    });

    group('wasModified', () {
      blocTest<FormGroupCubit, FormGroupState>(
        'is false after register',
        build: () => form,
        act: (cubit) => cubit.registerFields([field1, field2]),
        expect: () => <dynamic>[
          FormGroupState(
            fields: [field1, field2],
          ),
        ],
      );

      blocTest<FormGroupCubit, FormGroupState>(
        'is true if subform was modified',
        build: () => form,
        setUp: () {
          subform.registerFields([subformField]);
          form
            ..addSubform(subform)
            ..registerFields([field1, field2]);
        },
        act: (cubit) async {
          await Future<void>.delayed(Duration.zero);
          subformField.setValue(123);
        },
        expect: () => <dynamic>[
          FormGroupState(
            wasModified: true,
            fields: [field1, field2],
            subforms: {subform},
          ),
        ],
      );

      blocTest<FormGroupCubit, FormGroupState>(
        'is true if field1 changes',
        build: () => form,
        setUp: () {
          form.registerFields([field1, field2]);
        },
        act: (cubit) async {
          await Future<void>.delayed(Duration.zero);
          field1.setValue('value');
        },
        expect: () => [
          FormGroupState(
            wasModified: true,
            fields: [field1, field2],
          ),
        ],
      );

      blocTest<FormGroupCubit, FormGroupState>(
        'is true if field2 changes',
        build: () => form,
        setUp: () {
          form.registerFields([field1, field2]);
        },
        act: (cubit) async {
          await Future<void>.delayed(Duration.zero);
          field2.setValue(0xb0b);
        },
        expect: () => [
          FormGroupState(wasModified: true, fields: [field1, field2]),
        ],
      );

      blocTest<FormGroupCubit, FormGroupState>(
        'does not change if field was unregistered',
        build: () => form,
        setUp: () {
          form
            ..registerFields([field1, field2])
            ..registerFields([]);
        },
        act: (cubit) {
          field2.setValue(0xb0b);
        },
        expect: () => <dynamic>[],
      );
    });

    group('validate', () {
      test('enables autovalidate in fields', () {
        subform.registerFields([subformField]);
        form
          ..registerFields([field1, field2])
          ..addSubform(subform)
          ..validate();

        expect(field1.state.autovalidate, true);
        expect(field2.state.autovalidate, true);
        expect(subformField.state.autovalidate, true);
      });

      test('does not enable autovalidate in fields', () {
        subform.registerFields([subformField]);
        form
          ..registerFields([field1, field2])
          ..addSubform(subform)
          ..validate(enableAutovalidate: false);

        expect(field1.state.autovalidate, false);
        expect(field2.state.autovalidate, false);
        expect(subformField.state.autovalidate, false);
      });

      test('is valid when all are valid', () {
        subform.registerFields([subformField]);
        validator1.validationResult = null;
        validator2.validationResult = null;
        form
          ..registerFields([field1, field2])
          ..addSubform(subform);

        final isValid = form.validate();

        expect(isValid, true);
      });

      test('is not valid if a subform is not valid', () {
        subform.registerFields([subformField]);
        validator1.validationResult = null;
        validator2.validationResult = _Error2.malformed;
        form
          ..registerFields([field1])
          ..addSubform(subform);

        final isValid = form.validate();

        expect(isValid, false);
      });

      test('is not valid when any is invalid', () {
        validator1.validationResult = _Error1.valueRequired;
        validator2.validationResult = null;
        form.registerFields([field1, field2]);

        final isValid = form.validate();

        expect(isValid, false);
      });

      test('does not short-circuit on validation', () {
        subform.registerFields([subformField]);
        validator1.validationResult = _Error1.valueRequired;
        validator2.validationResult = _Error2.malformed;

        form
          ..registerFields([field1, field2])
          ..addSubform(subform)
          ..validate(enableAutovalidate: false);

        expect(field1.state.error, _Error1.valueRequired);
        expect(field2.state.error, _Error2.malformed);
        expect(subformField.state.error, _Error2.malformed);
      });

      test('is valid when validationEnabled is false', () {
        validator1.validationResult = _Error1.valueRequired;
        form
          ..registerFields([field1])
          ..setValidationEnabled(false);

        final isValid = form.validate();

        expect(isValid, true);
      });

      test('enables autovalidate even when validationEnabled is false', () {
        form
          ..registerFields([field1])
          ..setValidationEnabled(false)
          ..validate();

        expect(field1.state.autovalidate, true);
      });

      test('is not valid when any of the fields is pending async validation',
          () {
        validator1.validationResult = null;
        final field = TextFieldCubit<_Error1>(
          initialValue: _initialValue1,
          asyncValidator: (_) async => validator1.validationResult,
        );
        form.registerFields([field]);

        field.setValue('value');
        final isValid = form.validate();

        expect(isValid, false);
      });

      test('is not valid when async validation of the field fails', () async {
        validator1.validationResult = _Error1.valueRequired;
        final field = TextFieldCubit<_Error1>(
          initialValue: _initialValue1,
          asyncValidator: (_) async => validator1.validationResult,
        );
        form.registerFields([field]);

        field.setValue('value');
        await Future<void>.delayed(const Duration(milliseconds: 500));
        final isValid = form.validate();

        expect(isValid, false);
      });

      test(
          'is not valid when any of the fields in subform is pending async validation',
          () {
        validator2.validationResult = null;
        subformField = FieldCubit(
          initialValue: 0,
          asyncValidator: (_) async => validator2.validationResult,
        );
        subform = FormGroupCubit()..registerFields([subformField]);
        form.addSubform(subform);

        subformField.setValue(10);
        final isValid = form.validate();

        expect(isValid, false);
      });
    });

    group('onValuesChangedStream', () {
      test('pings on field change', () async {
        form.registerFields([field1, field2]);

        unawaited(expectLater(form.onValuesChangedStream, emits(anything)));
        await Future<void>.delayed(Duration.zero);
        field1.setValue('value');
      });

      test('pings on subform field change', () async {
        subform.registerFields([subformField]);
        form
          ..registerFields([field1, field2])
          ..addSubform(subform);

        unawaited(expectLater(form.onValuesChangedStream, emits(anything)));
        await Future<void>.delayed(Duration.zero);
        subformField.setValue(123);
      });

      test('pings when new fields are registered', () async {
        form.registerFields([field1]);

        unawaited(expectLater(form.onValuesChangedStream, emits(anything)));
        await Future<void>.delayed(Duration.zero);
        form.registerFields([field1, field2]);
      });

      test('pings when new fields are registered for subform', () async {
        form
          ..registerFields([field1])
          ..addSubform(subform);

        unawaited(expectLater(form.onValuesChangedStream, emits(anything)));
        await Future<void>.delayed(Duration.zero);
        subform.registerFields([subformField]);
      });

      test('does not ping on validation error', () async {
        form.registerFields([field1, field2]);

        final sub = form.onValuesChangedStream.listen((event) {
          fail('got an event');
        });

        field1.setError(_Error1.valueRequired);

        await Future<void>.delayed(const Duration(milliseconds: 10));

        await sub.cancel();
      });

      test('does not ping on enabling autovalidate', () async {
        form.registerFields([field1, field2]);

        final sub = form.onValuesChangedStream.listen((event) {
          fail('got an event');
        });

        field1.setAutovalidate(true);

        await Future<void>.delayed(const Duration(milliseconds: 10));

        await sub.cancel();
      });

      test('does not ping on same value', () async {
        form.registerFields([field1, field2]);
        field1.setValue('value');

        final sub = form.onValuesChangedStream.listen((event) {
          fail('got an event');
        });

        field1.setValue('value');

        await Future<void>.delayed(const Duration(milliseconds: 10));

        await sub.cancel();
      });
    });
    test('markReadOnly', () {
      subform.registerFields([subformField]);
      form
        ..registerFields([field1, field2])
        ..addSubform(subform)
        ..markReadOnly();

      expect(field1.state.readOnly, true);
      expect(field2.state.readOnly, true);
      expect(subformField.state.readOnly, true);
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

      expect(field1.state.error, null);
      expect(field2.state.error, null);
      expect(subformField.state.error, null);

      expect(field1.state.isValid, true);
      expect(field2.state.isValid, true);
      expect(subformField.state.isValid, true);
    });

    group('setAutovalidate', () {
      test('to true', () {
        subform.registerFields([subformField]);
        form
          ..registerFields([field1, field2])
          ..addSubform(subform)
          ..setAutovalidate(true);

        expect(field1.state.autovalidate, true);
        expect(field2.state.autovalidate, true);
        expect(subformField.state.autovalidate, true);
      });
      test('to false', () {
        subform.registerFields([subformField]);
        form
          ..registerFields([field1, field2])
          ..addSubform(subform)
          ..setAutovalidate(true)
          ..setAutovalidate(false);

        expect(field1.state.autovalidate, false);
        expect(field2.state.autovalidate, false);
        expect(subformField.state.autovalidate, false);
      });
    });

    group('addSubform', () {
      blocTest<FormGroupCubit, FormGroupState>(
        'adds a new subform',
        build: () => form,
        act: (cubit) {
          cubit.addSubform(subform);
        },
        expect: () => <dynamic>[
          FormGroupState(subforms: {subform}),
        ],
      );

      blocTest<FormGroupCubit, FormGroupState>(
        'is noop if form was already added',
        build: () => form,
        setUp: () => form.addSubform(subform),
        act: (cubit) {
          cubit.addSubform(subform);
        },
        expect: () => <dynamic>[],
      );
    });

    group('validateAll', () {
      late FormGroupCubit form;

      setUp(() {
        form = FormGroupCubit(validateAll: true);
      });

      test('validate is called on other autovalidate fields', () async {
        subform.registerFields([subformField]);
        form
          ..registerFields([field1, field2])
          ..addSubform(subform);
        field1.setAutovalidate(true);
        validator1.validationResult = _Error1.valueRequired;

        field2.setValue(42);
        await Future<void>.delayed(Duration.zero);

        expect(field1.state.error, _Error1.valueRequired);
        expect(field2.state.error, null);
        expect(subformField.state.error, null);
      });

      test('validate is called on other autovalidate subforms', () async {
        subform.registerFields([subformField]);
        form
          ..registerFields([field1, field2])
          ..addSubform(subform);
        subformField.setAutovalidate(true);
        validator2.validationResult = _Error2.malformed;

        field2.setValue(42);
        await Future<void>.delayed(Duration.zero);

        expect(field1.state.error, null);
        expect(field2.state.error, null);
        expect(subformField.state.error, _Error2.malformed);
      });
    });

    group('setValidationEnabled', () {
      blocTest<FormGroupCubit, FormGroupState>(
        'sets validationEnabled to false',
        build: () => form,
        seed: () => const FormGroupState(),
        act: (cubit) {
          cubit.setValidationEnabled(false);
        },
        expect: () => [
          const FormGroupState(validationEnabled: false),
        ],
      );

      blocTest<FormGroupCubit, FormGroupState>(
        'sets validationEnabled to true',
        build: () => form,
        seed: () => const FormGroupState(validationEnabled: false),
        act: (cubit) {
          cubit.setValidationEnabled(true);
        },
        expect: () => [
          const FormGroupState(),
        ],
      );

      blocTest<FormGroupCubit, FormGroupState>(
        'is noop if the same validationEnabled was already set',
        build: () => form,
        seed: () => const FormGroupState(),
        act: (cubit) {
          cubit.setValidationEnabled(true);
        },
        expect: () => <dynamic>[],
      );

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

        expect(field1.state.error, null);
        expect(field2.state.error, null);
        expect(subformField.state.error, null);
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

        expect(field1.state.error, _Error1.valueRequired);
        expect(field2.state.error, _Error2.malformed);
        expect(subformField.state.error, _Error2.malformed);
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

        expect(field1.state.error, _Error1.valueRequired);
        expect(field2.state.error, _Error2.malformed);
        expect(subformField.state.error, _Error2.malformed);
      });
    });

    group('removeSubform', () {
      blocTest<FormGroupCubit, FormGroupState>(
        'removes a previously added subform and disposes it',
        build: () => form,
        setUp: () {
          form.addSubform(subform);
        },
        act: (cubit) async {
          await cubit.removeSubform(subform);
        },
        expect: () => <dynamic>[
          const FormGroupState(),
        ],
        verify: (cubit) {
          expect(subform.isClosed, true);
        },
      );

      blocTest<FormGroupCubit, FormGroupState>(
        'removes a previously added subform but does not disposes it when close is false',
        build: () => form,
        setUp: () {
          form.addSubform(subform);
        },
        act: (cubit) async {
          await cubit.removeSubform(subform, close: false);
        },
        expect: () => <dynamic>[
          const FormGroupState(),
        ],
        verify: (cubit) {
          expect(subform.isClosed, false);
        },
      );

      blocTest<FormGroupCubit, FormGroupState>(
        'is noop if form was not added',
        build: () => form,
        act: (cubit) {
          cubit.removeSubform(subform);
        },
        expect: () => <dynamic>[],
        verify: (cubit) {
          expect(subform.isClosed, false);
        },
      );
    });

    test('disposes all dependencies', () async {
      subform.registerFields([subformField]);

      form
        ..registerFields([field1, field2])
        ..addSubform(subform);
      await form.close();

      expect(form.isDisposed, true);
      expect(form.isClosed, true);
      expect(field1.isClosed, true);
      expect(field2.isClosed, true);
      expect(subform.isClosed, true);
      expect(subform.isDisposed, true);
      expect(subformField.isClosed, true);
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

        expect(field1.state.value, _initialValue1);
        expect(field2.state.value, _initialValue2);
        expect(subformField.state.value, _initialValue2);
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

        expect(field1.state.error, _Error1.valueRequired);
        expect(field2.state.error, null);
        expect(subformField.state.error, _Error2.malformed);
      });
    });
  });
}
