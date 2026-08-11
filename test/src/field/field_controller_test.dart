import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:leancode_forms/leancode_forms.dart';

enum _Error {
  malformed,
  valueRequired,
  unavailable,
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
/// `validated`, runs [onValidate], waits [validatorDelay] and then returns
/// whatever [result] gives.
///
/// The gate is open by default, since that is what lets a value change start a
/// round at all.
({_Field field, List<int> validated}) _asyncField({
  Duration debounce = const Duration(milliseconds: 50),
  Duration validatorDelay = Duration.zero,
  Duration? timeout,
  _Error? Function()? result,
  void Function(_Field field)? onValidate,
  AsyncValidationFailureHandler? onFailure,
  AsyncValidationFailureMapper<_Error>? failureToError,
  Validator<int, _Error>? validator,
  bool autovalidate = true,
}) {
  final validated = <int>[];
  late _Field field;
  field = AdvancedFieldController<int, _Error>(
    initialValue: _initialValue,
    validator: validator,
    asyncValidation: AsyncValidation(
      validator: (value) async {
        validated.add(value);
        onValidate?.call(field);
        await Future<void>.delayed(validatorDelay);
        return result?.call();
      },
      debounce: debounce,
      timeout: timeout,
      onFailure: onFailure,
      failureToError: failureToError,
    ),
  );
  if (autovalidate) {
    field.setAutovalidate(true);
  }
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

    test('does not run the validator if autovalidate is off', () {
      validator.validationResult = _Error.malformed;
      final emissions = _record(field);
      field.setValue(10);
      expect(emissions, const [_State(value: 10)]);
    });

    test('clears both error slots when the gate is closed', () {
      field.debugSetState(
        const _State(
          value: 1,
          validationError: _Error.valueRequired,
          asyncError: _Error.malformed,
          status: FieldStatus.invalid,
        ),
      );
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
    test('resets the value and both error slots', () {
      field.debugSetState(
        const _State(
          value: 10,
          validationError: _Error.malformed,
          asyncError: _Error.malformed,
          status: FieldStatus.invalid,
        ),
      );
      final emissions = _record(field);
      field.reset();
      expect(emissions, const [_State(value: 0)]);
    });

    test('keeps autovalidate and readOnly', () {
      field
        ..setAutovalidate(true)
        ..markReadOnly()
        ..setValue(10, force: true);
      final emissions = _record(field);

      field.reset();

      expect(emissions, const [
        _State(value: 0, autovalidate: true, readOnly: true),
      ]);
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
    test('when is valid', () async {
      validator.validationResult = null;
      final result = await field.validate();

      expect(result, true);
      expect(field.value, const _State(value: _initialValue));
      expect(field.value.isValid, true);
    });

    test('when is not valid', () async {
      validator.validationResult = _Error.malformed;
      final result = await field.validate();

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
        () async {
      validator.validationResult = _Error.malformed;
      field.setError(_Error.malformed);
      final emissions = _record(field);
      await field.validate();
      expect(emissions, isEmpty);
    });

    test('surfaces a sync error on a field that already carries an async one',
        () async {
      validator.validationResult = _Error.malformed;
      field.debugSetState(
        const _State(
          value: _initialValue,
          asyncError: _Error.unavailable,
          status: FieldStatus.invalid,
        ),
      );

      expect(await field.validate(), false);
      expect(field.value.validationError, _Error.malformed);
      expect(field.value.asyncError, _Error.unavailable);
      expect(field.error, _Error.malformed);
    });

    test('does not call the async validator when the sync verdict fails',
        () async {
      final (:field, :validated) = _asyncField(
        validator: (_) => _Error.malformed,
        autovalidate: false,
      );
      addTearDown(field.dispose);

      expect(await field.validate(), false);
      expect(validated, isEmpty);
      expect(field.value.validationError, _Error.malformed);
    });

    test('runs the async validator even with the gate closed', () async {
      final (:field, :validated) = _asyncField(autovalidate: false);
      addTearDown(field.dispose);

      expect(await field.validate(), true);
      expect(validated, const [_initialValue]);
    });

    test('completes false when the field is disposed mid-round', () async {
      final (:field, :validated) = _asyncField(
        debounce: const Duration(milliseconds: 10),
        validatorDelay: const Duration(milliseconds: 200),
      );

      final result = field.validate();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      field.dispose();

      expect(await result, false);
    });

    test('reports a superseded round as not known good', () async {
      final (:field, :validated) = _asyncField(
        validatorDelay: const Duration(milliseconds: 100),
        autovalidate: false,
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
      final (:field, :validated) = _asyncField(
        validatorDelay: const Duration(milliseconds: 50),
      );
      addTearDown(field.dispose);

      final first = field.validate();
      final second = field.validate();

      expect(identical(first, second), isTrue);
      expect(await first, true);
      expect(await second, true);
      expect(validated, const [_initialValue]);
    });

    test('flushes a round still waiting out its debounce', () async {
      final (:field, :validated) = _asyncField(
        debounce: const Duration(seconds: 10),
      );
      addTearDown(field.dispose);

      field.setValue(10);
      expect(field.value.isPending, isTrue);

      expect(await field.validate(), true);
      expect(validated, const [10]);
    });

    test('awaits an in-flight round instead of starting another', () async {
      final (:field, :validated) = _asyncField(
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
      final (:field, :validated) = _asyncField(autovalidate: false);
      addTearDown(field.dispose);

      expect(await field.validate(), true);
      expect(await field.validate(), true);

      expect(validated, const [_initialValue]);
    });

    test('a value change invalidates the verdict', () async {
      final (:field, :validated) = _asyncField(autovalidate: false);
      addTearDown(field.dispose);

      await field.validate();
      field.setValue(10);
      await field.validate();

      expect(validated, const [_initialValue, 10]);
    });

    test('re-runs a round that failed, so submit is the retry', () async {
      var shouldThrow = true;
      final validated = <int>[];
      final f = AdvancedFieldController<int, _Error>(
        initialValue: _initialValue,
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
      expect(validated, const [_initialValue, _initialValue]);
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
      )..setAutovalidate(true);
    });

    tearDown(() {
      asyncField.dispose();
    });

    test('does not run while the gate is closed', () async {
      final (:field, :validated) = _asyncField(autovalidate: false);
      addTearDown(field.dispose);
      final emissions = _record(field);

      field.setValue(10);
      await Future<void>.delayed(const Duration(milliseconds: 200));

      expect(validated, isEmpty);
      expect(emissions, const [_State(value: 10)]);
    });

    test('emits pending, validating, then final invalid', () async {
      validator.validationResult = _Error.malformed;
      final emissions = _record(asyncField);

      asyncField.setValue(10);
      await Future<void>.delayed(const Duration(milliseconds: 600));

      expect(emissions, const [
        _State(value: 10, status: FieldStatus.pending, autovalidate: true),
        _State(value: 10, status: FieldStatus.validating, autovalidate: true),
        _State(
          value: 10,
          status: FieldStatus.invalid,
          asyncError: _Error.malformed,
          autovalidate: true,
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
        _State(value: 10, status: FieldStatus.pending, autovalidate: true),
        _State(value: 20, status: FieldStatus.pending, autovalidate: true),
        _State(value: 20, status: FieldStatus.validating, autovalidate: true),
        _State(
          value: 20,
          status: FieldStatus.invalid,
          asyncError: _Error.malformed,
          autovalidate: true,
        ),
      ]);
    });

    test('restarts async validation when value changes while validating',
        () async {
      validator.validationResult = _Error.malformed;
      final emissions = _record(asyncField);

      asyncField.setValue(10);
      await Future<void>.delayed(const Duration(milliseconds: 350));
      asyncField.setValue(20);
      await Future<void>.delayed(const Duration(milliseconds: 600));

      expect(emissions, const [
        _State(value: 10, status: FieldStatus.pending, autovalidate: true),
        _State(value: 10, status: FieldStatus.validating, autovalidate: true),
        _State(value: 20, status: FieldStatus.pending, autovalidate: true),
        _State(value: 20, status: FieldStatus.validating, autovalidate: true),
        _State(
          value: 20,
          status: FieldStatus.invalid,
          asyncError: _Error.malformed,
          autovalidate: true,
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
      expect(emissions, const [
        _State(value: 10, status: FieldStatus.pending, autovalidate: true),
      ]);

      f.dispose();
      await Future<void>.delayed(const Duration(milliseconds: 500));

      // No further emissions after dispose.
      expect(emissions, const [
        _State(value: 10, status: FieldStatus.pending, autovalidate: true),
      ]);
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
        _State(value: 10, status: FieldStatus.pending, autovalidate: true),
        _State(value: 10, status: FieldStatus.validating, autovalidate: true),
      ]);

      f.dispose();
      await Future<void>.delayed(const Duration(milliseconds: 400));

      // Validator's natural completion arrives AFTER dispose; no emission.
      expect(emissions, const [
        _State(value: 10, status: FieldStatus.pending, autovalidate: true),
        _State(value: 10, status: FieldStatus.validating, autovalidate: true),
      ]);
    });

    test(
        'disposing while the validator is in flight does not emit when it '
        'resolves', () async {
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
        _State(value: 10, status: FieldStatus.pending, autovalidate: true),
        _State(value: 10, status: FieldStatus.validating, autovalidate: true),
      ]);
    });
  });

  group('round ownership', () {
    test(
        'a sync-invalid setValue during a pending round cannot resurrect the '
        'earlier value', () async {
      var reject = false;
      final (:field, :validated) = _asyncField(
        validatorDelay: const Duration(milliseconds: 100),
        validator: (_) => reject ? _Error.malformed : null,
      );
      addTearDown(field.dispose);

      field.setValue(10);
      await Future<void>.delayed(const Duration(milliseconds: 80));
      expect(field.value.isValidating, isTrue);

      reject = true;
      field.setValue(20);
      await Future<void>.delayed(const Duration(milliseconds: 300));

      expect(field.fieldValue, 20);
      expect(field.value.validationError, _Error.malformed);
      expect(validated, const [10]);
    });

    test(
        'a sync-invalid keystroke during a pending round cannot resurrect the '
        'earlier text', () async {
      final text = AdvancedTextFieldController<_Error>(
        validator: (value) => value.length > 2 ? _Error.malformed : null,
        asyncValidation: const AsyncValidation(
          validator: _alwaysValid,
          debounce: Duration(milliseconds: 50),
        ),
      )..setAutovalidate(true);
      addTearDown(text.dispose);

      text.textController.text = 'ab';
      await Future<void>.delayed(const Duration(milliseconds: 80));

      text.textController.text = 'abc';
      await Future<void>.delayed(const Duration(milliseconds: 300));

      expect(text.fieldValue, 'abc');
      expect(text.textController.text, 'abc');
      expect(text.value.validationError, _Error.malformed);
    });

    test('reset during a pending round is not undone by the round', () async {
      final (:field, :validated) = _asyncField(
        debounce: const Duration(milliseconds: 100),
        result: () => _Error.unavailable,
      );
      addTearDown(field.dispose);

      field.setValue(10);
      expect(field.value.isPending, isTrue);

      field.reset();
      final emissions = _record(field);
      await Future<void>.delayed(const Duration(milliseconds: 300));

      expect(field.fieldValue, _initialValue);
      expect(field.value.isValid, isTrue);
      expect(emissions, isEmpty);
      expect(validated, isEmpty);
    });

    test('reset during a validating round is not undone by the round',
        () async {
      final (:field, :validated) = _asyncField(
        debounce: const Duration(milliseconds: 10),
        validatorDelay: const Duration(milliseconds: 100),
        result: () => _Error.unavailable,
      );
      addTearDown(field.dispose);

      field.setValue(10);
      await Future<void>.delayed(const Duration(milliseconds: 40));
      expect(field.value.isValidating, isTrue);

      field.reset();
      final emissions = _record(field);
      await Future<void>.delayed(const Duration(milliseconds: 300));

      expect(field.fieldValue, _initialValue);
      expect(field.value.isValid, isTrue);
      expect(emissions, isEmpty);
    });

    test('setError during a pending round survives the round', () async {
      final (:field, :validated) = _asyncField(
        debounce: const Duration(milliseconds: 100),
        result: () => _Error.unavailable,
      );
      addTearDown(field.dispose);

      field.setValue(10);
      expect(field.value.isPending, isTrue);

      field.setError(_Error.valueRequired);
      final emissions = _record(field);
      await Future<void>.delayed(const Duration(milliseconds: 300));

      expect(field.value.validationError, _Error.valueRequired);
      expect(field.value.isInvalid, isTrue);
      expect(emissions, isEmpty);
      expect(validated, isEmpty);
    });

    test('clearErrors during a pending round is not undone by the round',
        () async {
      final (:field, :validated) = _asyncField(
        debounce: const Duration(milliseconds: 100),
        result: () => _Error.unavailable,
      );
      addTearDown(field.dispose);

      field.setValue(10);
      expect(field.value.isPending, isTrue);

      field.clearErrors();
      final emissions = _record(field);
      await Future<void>.delayed(const Duration(milliseconds: 300));

      expect(field.value.isValid, isTrue);
      expect(emissions, isEmpty);
      expect(validated, isEmpty);
    });

    test('clearErrors during a validating round is not undone by the round',
        () async {
      final (:field, :validated) = _asyncField(
        debounce: const Duration(milliseconds: 10),
        validatorDelay: const Duration(milliseconds: 100),
        result: () => _Error.unavailable,
      );
      addTearDown(field.dispose);

      field.setValue(10);
      await Future<void>.delayed(const Duration(milliseconds: 40));
      expect(field.value.isValidating, isTrue);

      field.clearErrors();
      final emissions = _record(field);
      await Future<void>.delayed(const Duration(milliseconds: 300));

      expect(field.value.asyncError, isNull);
      expect(field.value.isValid, isTrue);
      expect(emissions, isEmpty);
      expect(validated, const [10]);
    });

    test('setError during a validating round survives the round', () async {
      final (:field, :validated) = _asyncField(
        debounce: const Duration(milliseconds: 10),
        validatorDelay: const Duration(milliseconds: 100),
        result: () => _Error.unavailable,
      );
      addTearDown(field.dispose);

      field.setValue(10);
      await Future<void>.delayed(const Duration(milliseconds: 40));
      expect(field.value.isValidating, isTrue);

      field.setError(_Error.valueRequired);
      final emissions = _record(field);
      await Future<void>.delayed(const Duration(milliseconds: 300));

      expect(field.value.validationError, _Error.valueRequired);
      expect(emissions, isEmpty);
    });

    test('markReadOnly during an active round stops it and drops lastFailure',
        () async {
      final (:field, :validated) = _asyncField(
        debounce: const Duration(milliseconds: 10),
        validatorDelay: const Duration(milliseconds: 100),
        result: () => _Error.unavailable,
      );
      addTearDown(field.dispose);

      field.setValue(10);
      await Future<void>.delayed(const Duration(milliseconds: 40));
      expect(field.value.isValidating, isTrue);

      field.markReadOnly();
      final emissions = _record(field);
      await Future<void>.delayed(const Duration(milliseconds: 300));

      expect(field.value.readOnly, isTrue);
      expect(field.value.isValid, isTrue);
      expect(field.lastFailure, isNull);
      expect(emissions, isEmpty);
    });

    test('markReadOnly keeps a failed status while dropping its details',
        () async {
      final (:field, :validated) = _asyncField(
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

    test('a listener writing during the pending notification kills the round',
        () async {
      // `_currentRound` is installed before the `pending` state is published,
      // so a listener re-entering from inside that notification supersedes the
      // round that is publishing it. The superseded round must then stay
      // silent rather than resurrect its own value.
      final (:field, :validated) = _asyncField(
        debounce: const Duration(milliseconds: 20),
        result: () => _Error.unavailable,
      );
      addTearDown(field.dispose);

      var reentered = false;
      field
        ..addListener(() {
          if (field.value.isPending && !reentered) {
            reentered = true;
            field.setValue(2);
          }
        })
        ..setValue(1);
      await Future<void>.delayed(const Duration(milliseconds: 120));

      expect(reentered, isTrue);
      // The superseded round never reached the validator.
      expect(validated, const [2]);
      expect(field.fieldValue, 2);
      expect(field.value.asyncError, _Error.unavailable);
    });

    test('a superseded round writes nothing after the abort', () async {
      final (:field, :validated) = _asyncField(
        debounce: const Duration(milliseconds: 10),
        validatorDelay: const Duration(milliseconds: 100),
        result: () => _Error.unavailable,
      );
      addTearDown(field.dispose);

      field.setValue(10);
      await Future<void>.delayed(const Duration(milliseconds: 40));

      field
        ..setAutovalidate(false)
        ..setValue(10, force: true);
      final emissions = _record(field);
      await Future<void>.delayed(const Duration(milliseconds: 300));

      expect(emissions, isEmpty);
      expect(field.value.asyncError, isNull);
    });

    test(
        'a re-entrant setValue during the pending notification leaves one '
        'live round', () async {
      late _Field f;
      var reentered = false;
      final (:field, :validated) = _asyncField();
      f = field;
      addTearDown(f.dispose);

      f
        ..addListener(() {
          if (!reentered && f.value.isPending) {
            reentered = true;
            f.setValue(99);
          }
        })
        ..setValue(10);
      await Future<void>.delayed(const Duration(milliseconds: 300));

      expect(validated, const [99]);
      expect(f.fieldValue, 99);
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
      )..setAutovalidate(true);
    });

    tearDown(() {
      FlutterError.onError = previousOnError;
      throwingField.dispose();
    });

    test('marks the field failedValidation instead of leaving it validating',
        () async {
      final emissions = _record(throwingField);

      throwingField.setValue(10);
      await Future<void>.delayed(const Duration(milliseconds: 600));

      expect(emissions, const [
        _State(value: 10, status: FieldStatus.pending, autovalidate: true),
        _State(value: 10, status: FieldStatus.validating, autovalidate: true),
        _State(
          value: 10,
          status: FieldStatus.failedValidation,
          autovalidate: true,
        ),
      ]);
      expect(throwingField.value.isInProgress, isFalse);
      expect(throwingField.value.isValid, isFalse);
      expect(throwingField.error, isNull);
      expect(throwingField.lastFailure?.error, isStateError);
      expect(throwingField.lastFailure?.timedOut, isFalse);
    });

    test('a synchronous throw takes the same path as a rejected future',
        () async {
      final handled = <Object>[];
      final syncThrower = AdvancedFieldController<int, _Error>(
        name: 'sync-throwing',
        initialValue: _initialValue,
        asyncValidation: AsyncValidation(
          validator: (value) => throw StateError('validator exploded'),
          onFailure: (error, stackTrace) async => handled.add(error),
        ),
      )..setAutovalidate(true);
      addTearDown(syncThrower.dispose);
      final emissions = _record(syncThrower);

      syncThrower.setValue(10);
      await Future<void>.delayed(const Duration(milliseconds: 600));

      expect(emissions, const [
        _State(value: 10, status: FieldStatus.pending, autovalidate: true),
        _State(value: 10, status: FieldStatus.validating, autovalidate: true),
        _State(
          value: 10,
          status: FieldStatus.failedValidation,
          autovalidate: true,
        ),
      ]);
      expect(syncThrower.lastFailure?.error, isStateError);
      expect(handled, hasLength(1));
      expect(handled.single, isStateError);
      expect(reported, isEmpty);
    });

    test('validate returns false for a failed field', () async {
      throwingField.setValue(10);
      await Future<void>.delayed(const Duration(milliseconds: 600));

      expect(await throwingField.validate(), isFalse);
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

      expect(await form.validate(), isFalse);
      expect(form.value.hasFailedValidation, isTrue);
    });

    test('timeout abandons the round and drops its later result', () async {
      final (:field, :validated) = _asyncField(
        debounce: const Duration(milliseconds: 10),
        validatorDelay: const Duration(milliseconds: 300),
        timeout: const Duration(milliseconds: 50),
        result: () => _Error.unavailable,
        onFailure: (error, stackTrace) async {},
      );
      addTearDown(field.dispose);

      field.setValue(10);
      await Future<void>.delayed(const Duration(milliseconds: 150));

      expect(field.value.isFailedValidation, isTrue);
      expect(field.lastFailure?.error, isA<TimeoutException>());
      expect(field.lastFailure?.timedOut, isTrue);

      final emissions = _record(field);
      await Future<void>.delayed(const Duration(milliseconds: 400));

      // The abandoned validator resolved with `unavailable`; it is dropped.
      expect(emissions, isEmpty);
      expect(field.value.asyncError, isNull);
      expect(field.value.isFailedValidation, isTrue);
    });

    test('a validator throwing after its timeout still reports the timeout',
        () async {
      final (:field, :validated) = _asyncField(
        debounce: const Duration(milliseconds: 10),
        validatorDelay: const Duration(milliseconds: 300),
        timeout: const Duration(milliseconds: 50),
        result: () => throw StateError('late explosion'),
        onFailure: (error, stackTrace) async {},
      );
      addTearDown(field.dispose);

      field.setValue(10);
      await Future<void>.delayed(const Duration(milliseconds: 250));

      // The timeout won the race, so the later throw is the loser and is
      // dropped rather than overwriting the reported failure.
      expect(field.lastFailure?.error, isA<TimeoutException>());
      expect(field.lastFailure?.timedOut, isTrue);

      final emissions = _record(field);
      await Future<void>.delayed(const Duration(milliseconds: 400));

      expect(emissions, isEmpty);
      expect(field.lastFailure?.error, isA<TimeoutException>());
    });

    test('failureToError gives a failed round something to display', () async {
      final (:field, :validated) = _asyncField(
        onValidate: (_) => throw StateError('validator exploded'),
        onFailure: (error, stackTrace) async {},
        failureToError: (error, stackTrace) => _Error.unavailable,
      );
      addTearDown(field.dispose);

      expect(await field.validate(), isFalse);

      expect(field.value.isFailedValidation, isTrue);
      expect(field.value.asyncError, _Error.unavailable);
      expect(field.error, _Error.unavailable);
      expect(field.lastFailure?.error, isStateError);
    });

    group('AsyncValidation.onFailure', () {
      _Field fieldWithHandler(AsyncValidationFailureHandler onFailure) {
        final field = AdvancedFieldController<int, _Error>(
          name: 'handled',
          initialValue: _initialValue,
          asyncValidation: AsyncValidation(
            validator: (value) async {
              await Future<void>.delayed(const Duration(milliseconds: 100));
              throw StateError('validator exploded');
            },
            onFailure: onFailure,
          ),
        )..setAutovalidate(true);
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

      test('still moves the field to failedValidation', () async {
        final field = fieldWithHandler((error, stackTrace) async {})
          ..setValue(10);

        await Future<void>.delayed(const Duration(milliseconds: 600));

        expect(field.value.status, FieldStatus.failedValidation);
      });

      test('does not delay the field resolving when it is slow', () async {
        final field = fieldWithHandler((error, stackTrace) async {
          await Future<void>.delayed(const Duration(seconds: 5));
        })
          ..setValue(10);

        await Future<void>.delayed(const Duration(milliseconds: 600));

        expect(field.value.status, FieldStatus.failedValidation);
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
          contains('onFailure handler of field handled'),
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

    test('null clears the sync slot and the status follows', () async {
      field.setError(_Error.malformed);
      final emissions = _record(field);

      field.setError(null);

      expect(emissions, const [_State(value: _initialValue)]);
      expect(field.value.isValid, isTrue);
      expect(await field.validate(), isTrue);
    });

    test('leaves a still-current verdict reusable', () async {
      final (:field, :validated) = _asyncField(autovalidate: false);
      addTearDown(field.dispose);

      await field.validate();
      expect(validated, const [_initialValue]);

      field
        ..setError(_Error.valueRequired)
        ..setError(null);

      expect(await field.validate(), isTrue);
      expect(validated, const [_initialValue]);
    });
  });

  group('both error slots', () {
    test('a cross-field sync error stands alongside a current verdict',
        () async {
      var mismatch = false;
      final (:field, :validated) = _asyncField(
        validator: (_) => mismatch ? _Error.malformed : null,
        result: () => _Error.unavailable,
        autovalidate: false,
      );
      addTearDown(field.dispose);

      // The server answers `unavailable`; the round is settled.
      expect(await field.validate(), isFalse);
      expect(field.value.asyncError, _Error.unavailable);

      // A sibling changes, so the cross-field rule now rejects the value.
      mismatch = true;
      expect(await field.validate(), isFalse);

      expect(field.value.validationError, _Error.malformed);
      expect(field.value.asyncError, _Error.unavailable);
      expect(field.error, _Error.malformed);
      // The value never changed, so the verdict was never re-fetched.
      expect(validated, const [_initialValue]);
    });

    test('a flag write re-derives a status that disagrees with the slots',
        () async {
      // `AdvancedFieldState` can represent `valid` alongside an error, so a
      // write that touches only a flag still has to settle the status rather
      // than carry the stale one through.
      for (final write in <void Function(_Field)>[
        (field) => field.setAutovalidate(true),
        (field) => field.unmarkReadOnly(),
      ]) {
        final field = _Field(initialValue: _initialValue)
          ..debugSetState(
            const _State(value: _initialValue, asyncError: _Error.unavailable),
          );
        addTearDown(field.dispose);
        expect(field.value.status, FieldStatus.valid);

        write(field);

        expect(field.value.status, FieldStatus.invalid);
      }
    });
  });

  group('subscribeToFields', () {
    test('re-runs the sync validator when a subscribed field changes',
        () async {
      validator.validationResult = _Error.malformed;
      final field2 = AdvancedFieldController<int, _Error>(initialValue: 0);
      final field1 = AdvancedFieldController<int, _Error>(
        initialValue: 0,
        validator: validator,
      )
        ..setAutovalidate(true)
        ..subscribeToFields([field2]);
      addTearDown(field1.dispose);
      addTearDown(field2.dispose);

      field2.setValue(10);
      await pumpEventQueue();

      expect(field1.value.error, _Error.malformed);
    });

    test('does not re-run the async validator: this field did not change',
        () async {
      final field2 = AdvancedFieldController<int, _Error>(initialValue: 0);
      addTearDown(field2.dispose);
      final (:field, :validated) = _asyncField();
      addTearDown(field.dispose);
      field.subscribeToFields([field2]);

      field2.setValue(10);
      await Future<void>.delayed(const Duration(milliseconds: 200));

      expect(validated, isEmpty);
      expect(field.value.isValid, isTrue);
    });

    test('does nothing while the gate is closed, including clearing errors',
        () async {
      final field2 = AdvancedFieldController<int, _Error>(initialValue: 0);
      final field1 = AdvancedFieldController<int, _Error>(
        initialValue: 0,
        validator: validator,
      )..subscribeToFields([field2]);
      addTearDown(field1.dispose);
      addTearDown(field2.dispose);

      field1.setError(_Error.valueRequired);

      field2.setValue(10);
      await pumpEventQueue();

      expect(field1.value.error, _Error.valueRequired);
    });

    test('enabling the gate does not validate immediately (issue #29)',
        () async {
      validator.validationResult = _Error.malformed;
      final field2 = AdvancedFieldController<int, _Error>(initialValue: 0);
      final field1 = AdvancedFieldController<int, _Error>(
        initialValue: 0,
        validator: validator,
      )..subscribeToFields([field2]);
      addTearDown(field1.dispose);
      addTearDown(field2.dispose);

      field1.setAutovalidate(true);
      await pumpEventQueue();

      expect(field1.value.error, isNull);
      expect(field1.value.isValid, isTrue);
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

    test('input into a read-only field is reconciled in the same turn', () {
      final tf = AdvancedTextFieldController<_Error>(initialValue: 'locked')
        ..markReadOnly();
      addTearDown(tf.dispose);

      tf.textController.text = 'typed over';

      expect(tf.fieldValue, 'locked');
      expect(tf.textController.text, 'locked');
    });

    test('reconciling keeps the selection when it still fits', () {
      final tf = AdvancedTextFieldController<_Error>(initialValue: 'abcdef');
      addTearDown(tf.dispose);
      tf.textController.selection = const TextSelection.collapsed(offset: 3);

      tf.setValue('abcxyz');

      expect(tf.textController.text, 'abcxyz');
      expect(tf.textController.selection.baseOffset, 3);
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

  group('AdvancedFieldState', () {
    test('toString prints both slots, the status and the flags', () {
      const state = _State(
        value: 7,
        validationError: _Error.malformed,
        asyncError: _Error.unavailable,
        autovalidate: true,
        readOnly: true,
        status: FieldStatus.invalid,
      );

      expect(
        state.toString(),
        'AdvancedFieldState('
        'value: 7, '
        'validationError: _Error.malformed, '
        'asyncError: _Error.unavailable, '
        'status: invalid, '
        'autovalidate: true, '
        'readOnly: true)',
      );
    });
  });
}

Future<_Error?> _alwaysValid(String value) async => null;
