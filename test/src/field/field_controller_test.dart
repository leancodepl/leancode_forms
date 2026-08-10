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

/// A field whose async validator records each value it is called with in
/// `validated`, runs [onValidate], then resolves `null` after
/// [validatorDelay].
({_Field field, List<int> validated}) _asyncField({
  Duration debounce = const Duration(milliseconds: 50),
  Duration validatorDelay = Duration.zero,
  void Function(_Field field)? onValidate,
}) {
  final validated = <int>[];
  late _Field field;
  field = AdvancedFieldController<int, _Error>(
    initialValue: 0,
    asyncValidation: AsyncValidation(
      validator: (value) async {
        validated.add(value);
        onValidate?.call(field);
        await Future<void>.delayed(validatorDelay);
        return null;
      },
      debounce: debounce,
    ),
  );
  return (field: field, validated: validated);
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
      field.debugSetState(
        const _State(
          value: 10,
          validationError: _Error.malformed,
          asyncError: _Error.malformed,
          autovalidate: true,
          readOnly: true,
          status: FieldStatus.invalid,
        ),
      );
      final emissions = _record(field);
      field.reset();
      expect(emissions, const [_State(value: 0)]);
    });
  });

  group('clearErrors', () {
    test('clears validationError and asyncError. Sets status to valid', () {
      field.debugSetState(
        const _State(
          value: 1,
          validationError: _Error.valueRequired,
          asyncError: _Error.malformed,
        ),
      );
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
        asyncValidation: AsyncValidation(
          validator: (value) async {
            await Future<void>.delayed(const Duration(milliseconds: 100));
            return validator.validationResult;
          },
        ),
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

    test(
        'rapid setValue calls within debounce window: validator runs only once '
        'with the final value', () async {
      final (:field, :validated) = _asyncField(
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
      final f = _asyncField(
        debounce: const Duration(milliseconds: 200),
        validatorDelay: const Duration(milliseconds: 100),
      ).field;
      final emissions = _record(f);

      f.setValue(10);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      // Field is in pending state, debounce not yet elapsed.
      expect(emissions, const [_State(value: 10, status: FieldStatus.pending)]);

      f.dispose();
      await Future<void>.delayed(const Duration(milliseconds: 500));

      // No further emissions after dispose.
      expect(emissions, const [_State(value: 10, status: FieldStatus.pending)]);
    });

    test('dispose during validating state does not crash or emit after dispose',
        () async {
      final f = _asyncField(
        validatorDelay: const Duration(milliseconds: 200),
      ).field;
      final emissions = _record(f);

      f.setValue(10);
      await Future<void>.delayed(const Duration(milliseconds: 100));
      // Debounce (50ms) has elapsed; validator (200ms) is running.
      expect(emissions, const [
        _State(value: 10, status: FieldStatus.pending),
        _State(value: 10, status: FieldStatus.validating),
      ]);

      f.dispose();
      await Future<void>.delayed(const Duration(milliseconds: 400));

      // Validator's natural completion arrives AFTER dispose; no emission.
      expect(emissions, const [
        _State(value: 10, status: FieldStatus.pending),
        _State(value: 10, status: FieldStatus.validating),
      ]);
    });

    test('disposing while the validator is in flight does not emit when it '
        'resolves', () async {
      // Disposing inside the validator happens before `_asyncValidationFuture`
      // is assigned, so `dispose()` has nothing to cancel.
      final (:field, :validated) = _asyncField(
        debounce: const Duration(milliseconds: 10),
        onValidate: (f) => f.dispose(),
      );
      final emissions = _record(field);

      field.setValue(10);
      await Future<void>.delayed(const Duration(milliseconds: 200));

      expect(field.isDisposed, isTrue);
      expect(validated, const [10]);
      // The validator resolved against a disposed controller, so the final
      // state is never emitted.
      expect(emissions, const [
        _State(value: 10, status: FieldStatus.pending),
        _State(value: 10, status: FieldStatus.validating),
      ]);
    });
  });

  group('async validation failure', () {
    late _Field throwingField;
    late List<FlutterErrorDetails> reported;
    void Function(FlutterErrorDetails)? previousOnError;

    setUp(() {
      reported = [];
      previousOnError = FlutterError.onError;
      FlutterError.onError = reported.add;

      throwingField = AdvancedFieldController<int, _Error>(
        name: 'throwing',
        initialValue: _initialValue,
        asyncValidation: AsyncValidation(
          validator: (value) async {
            await Future<void>.delayed(const Duration(milliseconds: 100));
            throw StateError('validator exploded');
          },
        ),
      );
    });

    tearDown(() {
      FlutterError.onError = previousOnError;
      throwingField.dispose();
    });

    test('marks the field failed instead of leaving it validating', () async {
      final emissions = _record(throwingField);

      throwingField.setValue(10);
      await Future<void>.delayed(const Duration(milliseconds: 600));

      expect(emissions, const [
        _State(value: 10, status: FieldStatus.pending),
        _State(value: 10, status: FieldStatus.validating),
        _State(value: 10, status: FieldStatus.failed),
      ]);
      expect(throwingField.value.isInProgress, isFalse);
      expect(throwingField.value.isValid, isFalse);
      expect(throwingField.error, isNull);
    });

    test('validate returns false for a failed field', () async {
      throwingField.setValue(10);
      await Future<void>.delayed(const Duration(milliseconds: 600));

      expect(throwingField.validate(), isFalse);
    });

    test('reports the exception through FlutterError', () async {
      throwingField.setValue(10);
      await Future<void>.delayed(const Duration(milliseconds: 600));

      expect(reported, hasLength(1));
      expect(reported.single.exception, isStateError);
      expect(reported.single.library, 'advanced_forms');
    });

    test('leaves the form unsubmittable rather than silently passing',
        () async {
      // A dedicated field, since the form takes ownership and disposes it.
      final ownedField = AdvancedFieldController<int, _Error>(
        initialValue: _initialValue,
        asyncValidation: AsyncValidation(
          validator: (value) async {
            await Future<void>.delayed(const Duration(milliseconds: 100));
            throw StateError('validator exploded');
          },
        ),
      );
      final form = AdvancedFormController()..registerFields([ownedField]);
      addTearDown(form.dispose);

      ownedField.setValue(10);
      await Future<void>.delayed(const Duration(milliseconds: 600));

      expect(form.validate(), isFalse);
    });

    group('AsyncValidation.onError', () {
      _Field fieldWithHandler(AsyncValidationErrorHandler onError) {
        final field = AdvancedFieldController<int, _Error>(
          name: 'handled',
          initialValue: _initialValue,
          asyncValidation: AsyncValidation(
            validator: (value) async {
              await Future<void>.delayed(const Duration(milliseconds: 100));
              throw StateError('validator exploded');
            },
            onError: onError,
          ),
        );
        addTearDown(field.dispose);
        return field;
      }

      test('receives the exception instead of FlutterError', () async {
        final handled = <Object>[];
        fieldWithHandler((error, stackTrace) async {
          handled.add(error);
        }).setValue(10);

        await Future<void>.delayed(const Duration(milliseconds: 600));

        expect(handled, hasLength(1));
        expect(handled.single, isStateError);
        expect(reported, isEmpty);
      });

      test('still moves the field to failed', () async {
        final field = fieldWithHandler((error, stackTrace) async {})
          ..setValue(10);

        await Future<void>.delayed(const Duration(milliseconds: 600));

        expect(field.value.status, FieldStatus.failed);
        expect(field.validate(), isFalse);
      });

      test('does not delay the field resolving when it is slow', () async {
        final field = fieldWithHandler((error, stackTrace) async {
          await Future<void>.delayed(const Duration(seconds: 5));
        })
          ..setValue(10);

        await Future<void>.delayed(const Duration(milliseconds: 600));

        expect(field.value.status, FieldStatus.failed);
      });

      test('is itself reported through FlutterError when it throws', () async {
        fieldWithHandler((error, stackTrace) async {
          throw ArgumentError('handler exploded');
        }).setValue(10);

        await Future<void>.delayed(const Duration(milliseconds: 600));

        expect(reported, hasLength(1));
        expect(reported.single.exception, isArgumentError);
        expect(reported.single.library, 'advanced_forms');
        expect(
          reported.single.context.toString(),
          contains('onError handler of field handled'),
        );
      });
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
      await pumpEventQueue();
      expect(field1.value.error, _Error.malformed);

      field1.dispose();
      field2.dispose();
    });

    test('should run async validation when subscribed field changes', () async {
      validator.validationResult = _Error.malformed;
      final field2 = AdvancedFieldController<int, _Error>(initialValue: 0);
      final field1 = AdvancedFieldController<int, _Error>(
        initialValue: 0,
        asyncValidation: AsyncValidation(
          validator: (_) async => validator.validationResult,
        ),
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
      await tester.pumpWidget(
        MaterialApp(
          home: Material(
            child: TextField(focusNode: tf.focusNode),
          ),
        ),
      );
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
