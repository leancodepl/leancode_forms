import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:leancode_forms/leancode_forms.dart';

enum _Error {
  malformed,
  valueRequired,
}

class _ValidatorMock {
  _Error? validationResult;

  _Error? call(int? value) => validationResult;
}

const _initialValue = 0;

typedef _Field = AdvancedFieldController<int, _Error>;
typedef _State = AdvancedFieldState<int, _Error>;

/// Returns a list that records every new state emitted by [notifier].
List<_State> _record(_Field notifier) {
  final emissions = <_State>[];
  notifier.addListener(() => emissions.add(notifier.value));
  return emissions;
}

void main() {
  late _Field field;
  late _ValidatorMock validator;

  setUp(() {
    validator = _ValidatorMock();
    field = AdvancedFieldController<int, _Error>(
      initialValue: _initialValue,
      validator: validator,
    );
  });

  tearDown(() {
    field.dispose();
  });

  group('setValue', () {
    test('updates the value', () {
      final emissions = _record(field);
      field.setValue(10);
      expect(emissions, const [_State(value: 10)]);
    });

    test('does not update error if autovalidate is off', () {
      validator.validationResult = _Error.malformed;
      final emissions = _record(field);
      field.setValue(10);
      expect(emissions, const [_State(value: 10)]);
    });

    test('updates error if autovalidate is on', () {
      field.setAutovalidate(true);
      validator.validationResult = _Error.malformed;
      final emissions = _record(field);
      field.setValue(10);
      expect(emissions, const [
        _State(
          value: 10,
          validationError: _Error.malformed,
          autovalidate: true,
          status: FieldStatus.invalid,
        ),
      ]);
    });

    test('does not update the value when field is readonly', () {
      field.markReadOnly();
      final emissions = _record(field);
      field.setValue(10);
      expect(emissions, isEmpty);
    });

    test('updates the value when field is readonly and force is true', () {
      field.markReadOnly();
      final emissions = _record(field);
      field.setValue(10, force: true);
      expect(emissions, const [_State(value: 10, readOnly: true)]);
    });
  });

  group('reset', () {
    test('resets state to initial state', () {
      field.debugSetState(const _State(
        value: 10,
        validationError: _Error.malformed,
        asyncError: _Error.malformed,
        autovalidate: true,
        readOnly: true,
        status: FieldStatus.invalid,
      ),);
      final emissions = _record(field);
      field.reset();
      expect(emissions, const [_State(value: 0)]);
    });
  });

  group('clearErrors', () {
    test('clears validationError and asyncError. Sets status to valid', () {
      field.debugSetState(const _State(
        value: 1,
        validationError: _Error.valueRequired,
        asyncError: _Error.malformed,
      ),);
      final emissions = _record(field);
      field.clearErrors();
      expect(emissions, const [_State(value: 1)]);
    });

    test('does nothing if errors were not present', () {
      field.setValue(1);
      final emissions = _record(field);
      field.clearErrors();
      expect(emissions, isEmpty);
    });
  });

  group('validate', () {
    test('when is valid', () {
      validator.validationResult = null;
      final result = field.validate();

      expect(result, true);
      expect(field.value, const _State(value: _initialValue));
      expect(field.value.isValid, true);
    });

    test('when is not valid', () {
      validator.validationResult = _Error.malformed;
      final result = field.validate();

      expect(result, false);
      expect(
        field.value,
        const _State(
          value: _initialValue,
          validationError: _Error.malformed,
          status: FieldStatus.invalid,
        ),
      );
      expect(field.value.isValid, false);
    });

    test(
        'when validation result is the same as previous, does not emit new state',
        () {
      validator.validationResult = _Error.malformed;
      field.setError(_Error.malformed);
      final emissions = _record(field);
      field.validate();
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

  group('async validation', () {
    late _Field asyncField;

    setUp(() {
      asyncField = AdvancedFieldController<int, _Error>(
        initialValue: _initialValue,
        asyncValidator: (value) async {
          await Future<void>.delayed(const Duration(milliseconds: 100));
          return validator.validationResult;
        },
      );
    });

    tearDown(() {
      asyncField.dispose();
    });

    test('emits pending, validating, then final invalid', () async {
      validator.validationResult = _Error.malformed;
      final emissions = _record(asyncField);

      asyncField.setValue(10);
      await Future<void>.delayed(const Duration(milliseconds: 600));

      expect(emissions, const [
        _State(value: 10, status: FieldStatus.pending),
        _State(value: 10, status: FieldStatus.validating),
        _State(
          value: 10,
          status: FieldStatus.invalid,
          asyncError: _Error.malformed,
        ),
      ]);
    });

    test('restarts async validation when value changes while pending',
        () async {
      validator.validationResult = _Error.malformed;
      final emissions = _record(asyncField);

      asyncField.setValue(10);
      await Future<void>.delayed(const Duration(milliseconds: 150));
      asyncField.setValue(20);
      await Future<void>.delayed(const Duration(milliseconds: 600));

      expect(emissions, const [
        _State(value: 10, status: FieldStatus.pending),
        _State(value: 20, status: FieldStatus.pending),
        _State(value: 20, status: FieldStatus.validating),
        _State(
          value: 20,
          status: FieldStatus.invalid,
          asyncError: _Error.malformed,
        ),
      ]);
    });

    test('restarts async validation when value changes while validating',
        () async {
      validator.validationResult = _Error.malformed;
      final emissions = _record(asyncField);

      asyncField.setValue(10);
      await Future<void>.delayed(const Duration(milliseconds: 300));
      asyncField.setValue(20);
      await Future<void>.delayed(const Duration(milliseconds: 600));

      expect(emissions, const [
        _State(value: 10, status: FieldStatus.pending),
        _State(value: 10, status: FieldStatus.validating),
        _State(value: 20, status: FieldStatus.pending),
        _State(value: 20, status: FieldStatus.validating),
        _State(
          value: 20,
          status: FieldStatus.invalid,
          asyncError: _Error.malformed,
        ),
      ]);
    });
  });

  group('setError', () {
    test('sets error and changes field status to invalid', () {
      final emissions = _record(field);
      field.setError(_Error.malformed);
      expect(emissions, const [
        _State(
          value: _initialValue,
          validationError: _Error.malformed,
          status: FieldStatus.invalid,
        ),
      ]);
    });
  });

  group('subscribeToFields', () {
    test('should run validation when subscribed field changes', () async {
      validator.validationResult = _Error.malformed;
      final field2 = AdvancedFieldController<int, _Error>(initialValue: 0);
      final field1 = AdvancedFieldController<int, _Error>(
        initialValue: 0,
        validator: validator,
      )
        ..setAutovalidate(true)
        ..subscribeToFields([field2]);

      field2.setValue(10);
      await Future<void>.delayed(Duration.zero);
      expect(field1.value.error, _Error.malformed);

      field1.dispose();
      field2.dispose();
    });

    test('should run async validation when subscribed field changes', () async {
      validator.validationResult = _Error.malformed;
      final field2 = AdvancedFieldController<int, _Error>(initialValue: 0);
      final field1 = AdvancedFieldController<int, _Error>(
        initialValue: 0,
        asyncValidator: (_) async => validator.validationResult,
      )
        ..setAutovalidate(true)
        ..subscribeToFields([field2]);

      field2.setValue(10);
      await Future<void>.delayed(const Duration(milliseconds: 500));
      expect(field1.value.error, _Error.malformed);

      field1.dispose();
      field2.dispose();
    });
  });

  group('AdvancedTextFieldController text controller sync', () {
    test('typing into textController updates field value', () {
      final tf = AdvancedTextFieldController<_Error>(initialValue: 'a')
        ..textController.text = 'abc';
      expect(tf.value.value, 'abc');
      tf.dispose();
    });

    test('setValue mirrors to textController', () {
      final tf = AdvancedTextFieldController<_Error>(initialValue: 'a')
        ..setValue('hello');
      expect(tf.textController.text, 'hello');
      tf.dispose();
    });

    test('reset clears both field and textController', () {
      final tf = AdvancedTextFieldController<_Error>()
        ..setValue('typed')
        ..reset();
      expect(tf.value.value, '');
      expect(tf.textController.text, '');
      tf.dispose();
    });
  });

  group('AdvancedTextFieldController focus node', () {
    test('focusNode is created and not focused initially', () {
      final tf = AdvancedTextFieldController<_Error>();
      expect(tf.focusNode.hasFocus, false);
      tf.dispose();
    });

    testWidgets('focus() requests focus on the focusNode', (tester) async {
      final tf = AdvancedTextFieldController<_Error>();
      addTearDown(tf.dispose);
      await tester.pumpWidget(MaterialApp(
        home: Material(
          child: TextField(focusNode: tf.focusNode),
        ),
      ),);
      tf.focus();
      await tester.pump();
      expect(tf.focusNode.hasFocus, true);
    });

    test('dispose disposes the focusNode', () {
      final tf = AdvancedTextFieldController<_Error>();
      final node = tf.focusNode;
      tf.dispose();
      expect(node.dispose, throwsAssertionError);
    });
  });
}
