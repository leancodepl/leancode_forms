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
  ValidationMode mode = ValidationMode.onUserInteraction,
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
  )..setValidationMode(mode);
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

    test('does not run the validator in disabled mode', () {
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

    test('updates error in onUserInteraction mode', () {
      field.setValidationMode(ValidationMode.onUserInteraction);
      validator.validationResult = _Error.malformed;
      final emissions = _record(field);
      field.setValue(10);
      expect(emissions, const [
        _State(
          value: 10,
          validationError: _Error.malformed,
          mode: ValidationMode.onUserInteraction,
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

    test('keeps the mode and readOnly', () {
      field
        ..setValidationMode(ValidationMode.onUserInteraction)
        ..markReadOnly()
        ..setValue(10, force: true);
      final emissions = _record(field);

      field.reset();

      expect(emissions, const [
        _State(value: 0, mode: ValidationMode.onUserInteraction, readOnly: true),
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
        mode: ValidationMode.disabled,
      );
      addTearDown(field.dispose);

      expect(await field.validate(), false);
      expect(validated, isEmpty);
      expect(field.value.validationError, _Error.malformed);
    });

    test('runs the async validator even with the gate closed', () async {
      final (:field, :validated) = _asyncField(mode: ValidationMode.disabled);
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
        mode: ValidationMode.disabled,
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
      final (:field, :validated) = _asyncField(mode: ValidationMode.disabled);
      addTearDown(field.dispose);

      expect(await field.validate(), true);
      expect(await field.validate(), true);

      expect(validated, const [_initialValue]);
    });

    test('a value change invalidates the verdict', () async {
      final (:field, :validated) = _asyncField(mode: ValidationMode.disabled);
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
      )..setValidationMode(ValidationMode.onUserInteraction);
    });

    tearDown(() {
      asyncField.dispose();
    });

    test('does not run while the gate is closed', () async {
      final (:field, :validated) = _asyncField(mode: ValidationMode.disabled);
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
        _State(value: 10, status: FieldStatus.pending, mode: ValidationMode.onUserInteraction),
        _State(value: 10, status: FieldStatus.validating, mode: ValidationMode.onUserInteraction),
        _State(
          value: 10,
          status: FieldStatus.invalid,
          asyncError: _Error.malformed,
          mode: ValidationMode.onUserInteraction,
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
        _State(value: 10, status: FieldStatus.pending, mode: ValidationMode.onUserInteraction),
        _State(value: 20, status: FieldStatus.pending, mode: ValidationMode.onUserInteraction),
        _State(value: 20, status: FieldStatus.validating, mode: ValidationMode.onUserInteraction),
        _State(
          value: 20,
          status: FieldStatus.invalid,
          asyncError: _Error.malformed,
          mode: ValidationMode.onUserInteraction,
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
        _State(value: 10, status: FieldStatus.pending, mode: ValidationMode.onUserInteraction),
        _State(value: 10, status: FieldStatus.validating, mode: ValidationMode.onUserInteraction),
        _State(value: 20, status: FieldStatus.pending, mode: ValidationMode.onUserInteraction),
        _State(value: 20, status: FieldStatus.validating, mode: ValidationMode.onUserInteraction),
        _State(
          value: 20,
          status: FieldStatus.invalid,
          asyncError: _Error.malformed,
          mode: ValidationMode.onUserInteraction,
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
        _State(value: 10, status: FieldStatus.pending, mode: ValidationMode.onUserInteraction),
      ]);

      f.dispose();
      await Future<void>.delayed(const Duration(milliseconds: 500));

      // No further emissions after dispose.
      expect(emissions, const [
        _State(value: 10, status: FieldStatus.pending, mode: ValidationMode.onUserInteraction),
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
        _State(value: 10, status: FieldStatus.pending, mode: ValidationMode.onUserInteraction),
        _State(value: 10, status: FieldStatus.validating, mode: ValidationMode.onUserInteraction),
      ]);

      f.dispose();
      await Future<void>.delayed(const Duration(milliseconds: 400));

      // Validator's natural completion arrives AFTER dispose; no emission.
      expect(emissions, const [
        _State(value: 10, status: FieldStatus.pending, mode: ValidationMode.onUserInteraction),
        _State(value: 10, status: FieldStatus.validating, mode: ValidationMode.onUserInteraction),
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
        _State(value: 10, status: FieldStatus.pending, mode: ValidationMode.onUserInteraction),
        _State(value: 10, status: FieldStatus.validating, mode: ValidationMode.onUserInteraction),
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
        ..setValidationMode(ValidationMode.disabled)
        ..setValue(10, force: true);
      final emissions = _record(field);
      await Future<void>.delayed(const Duration(milliseconds: 300));

      expect(emissions, isEmpty);
      expect(field.value.asyncError, isNull);
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
      )..setValidationMode(ValidationMode.onUserInteraction);
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
        _State(value: 10, status: FieldStatus.pending, mode: ValidationMode.onUserInteraction),
        _State(value: 10, status: FieldStatus.validating, mode: ValidationMode.onUserInteraction),
        _State(
          value: 10,
          status: FieldStatus.failedValidation,
          mode: ValidationMode.onUserInteraction,
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
      )..setValidationMode(ValidationMode.onUserInteraction);
      addTearDown(syncThrower.dispose);
      final emissions = _record(syncThrower);

      syncThrower.setValue(10);
      await Future<void>.delayed(const Duration(milliseconds: 600));

      expect(emissions, const [
        _State(value: 10, status: FieldStatus.pending, mode: ValidationMode.onUserInteraction),
        _State(value: 10, status: FieldStatus.validating, mode: ValidationMode.onUserInteraction),
        _State(
          value: 10,
          status: FieldStatus.failedValidation,
          mode: ValidationMode.onUserInteraction,
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
        )..setValidationMode(ValidationMode.onUserInteraction);
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
      final (:field, :validated) = _asyncField(mode: ValidationMode.disabled);
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
        mode: ValidationMode.disabled,
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
        (field) => field.setValidationMode(ValidationMode.onUserInteraction),
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
    test('throws StateError when this field has been disposed', () {
      final observed = AdvancedFieldController<int, _Error>(initialValue: 0);
      addTearDown(observed.dispose);
      var validatorCalls = 0;
      final field = AdvancedFieldController<int, _Error>(
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
      final observed = AdvancedFieldController<int, _Error>(initialValue: 0);
      addTearDown(observed.dispose);
      var validatorCalls = 0;
      final field = AdvancedFieldController<int, _Error>(
        initialValue: 0,
        validator: (_) {
          validatorCalls++;
          return null;
        },
      )
        ..setValidationMode(ValidationMode.onUserInteraction)
        // A dependency only reaches a field the user has edited.
        ..setValue(1)
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
      final field2 = AdvancedFieldController<int, _Error>(initialValue: 0);
      final field1 = AdvancedFieldController<int, _Error>(
        initialValue: 0,
        validator: validator,
      )
        ..setValidationMode(ValidationMode.onUserInteraction)
        ..setValue(1)
        ..subscribeToFields([field2]);
      validator.validationResult = _Error.malformed;
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

    test('enabling the gate does not validate immediately', () async {
      validator.validationResult = _Error.malformed;
      final field2 = AdvancedFieldController<int, _Error>(initialValue: 0);
      final field1 = AdvancedFieldController<int, _Error>(
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

  group('the mode gate', () {
    // One test per cell of the mode-by-trigger table. Where the trigger is not
    // itself an edit the field is edited first, because a field the user has
    // never edited validates nothing in any mode — the next group.
    for (final (mode, onEdit, onUnfocus, onDependency) in const [
      (ValidationMode.disabled, false, false, false),
      (ValidationMode.onUserInteraction, true, false, true),
      (ValidationMode.onUnfocus, false, true, true),
    ]) {
      group(mode.name, () {
        late _Field gated;
        late _Field dependency;

        setUp(() {
          dependency = AdvancedFieldController<int, _Error>(initialValue: 0);
          gated = AdvancedFieldController<int, _Error>(
            initialValue: _initialValue,
            validator: validator,
          )..setValidationMode(mode);
        });

        tearDown(() {
          gated.dispose();
          dependency.dispose();
        });

        test('edit', () {
          validator.validationResult = _Error.malformed;

          gated.setValue(10);

          expect(gated.error, onEdit ? _Error.malformed : isNull);
        });

        test('unfocus', () async {
          gated.setValue(10);
          validator.validationResult = _Error.malformed;

          gated.handleUnfocus();
          await pumpEventQueue();

          expect(gated.error, onUnfocus ? _Error.malformed : isNull);
        });

        test('dependency changed', () async {
          gated
            ..setValue(10)
            ..subscribeToFields([dependency]);
          validator.validationResult = _Error.malformed;

          dependency.setValue(1);
          await pumpEventQueue();

          expect(gated.error, onDependency ? _Error.malformed : isNull);
        });
      });
    }
  });

  group('the interaction guarantee', () {
    for (final mode in ValidationMode.values) {
      group(mode.name, () {
        late _Field untouched;
        late _Field dependency;

        setUp(() {
          dependency = AdvancedFieldController<int, _Error>(initialValue: 0);
          untouched = AdvancedFieldController<int, _Error>(
            initialValue: _initialValue,
            validator: validator,
          )..setValidationMode(mode);
          validator.validationResult = _Error.malformed;
        });

        tearDown(() {
          untouched.dispose();
          dependency.dispose();
        });

        test('a dependency change leaves an untouched field unmarked',
            () async {
          untouched.subscribeToFields([dependency]);

          dependency.setValue(1);
          await pumpEventQueue();

          expect(untouched.error, isNull);
        });

        test('unfocus leaves an untouched field unmarked', () async {
          untouched.handleUnfocus();
          await pumpEventQueue();

          expect(untouched.error, isNull);
        });

        test('validate still checks an untouched field', () async {
          expect(await untouched.validate(), isFalse);
          expect(untouched.error, _Error.malformed);
        });
      });
    }

    test('prefill does not count as an edit', () async {
      field
        ..setValidationMode(ValidationMode.onUserInteraction)
        ..prefill(10);
      validator.validationResult = _Error.malformed;

      field.handleUnfocus();
      await pumpEventQueue();

      expect(field.fieldValue, 10);
      expect(field.error, isNull);
    });

    test('reset forgets that the user ever edited the field', () async {
      field
        ..setValidationMode(ValidationMode.onUnfocus)
        ..setValue(10)
        ..reset();
      validator.validationResult = _Error.malformed;

      field.handleUnfocus();
      await pumpEventQueue();

      expect(field.error, isNull);
    });
  });

  group('handleUnfocus', () {
    test('flushes a round still waiting out its debounce, in any mode',
        () async {
      final (:field, :validated) = _asyncField(
        debounce: const Duration(seconds: 5),
      );
      addTearDown(field.dispose);

      field.setValue(1);
      expect(field.value.isPending, isTrue);

      field.handleUnfocus();
      await pumpEventQueue();

      expect(validated, [1]);
    });

    test('reuses a settled verdict across a second focus cycle', () async {
      final (:field, :validated) = _asyncField(mode: ValidationMode.onUnfocus);
      addTearDown(field.dispose);

      field
        ..setValue(1)
        ..handleUnfocus();
      await pumpEventQueue();
      expect(validated, [1]);

      // Tabbing back in and out without typing owes no new request.
      field.handleUnfocus();
      await pumpEventQueue();

      expect(validated, [1]);
    });

    test('retries a round that failed, since it recorded no verdict', () async {
      final (:field, :validated) = _asyncField(
        mode: ValidationMode.onUnfocus,
        result: () => throw StateError('network down'),
        onFailure: (_, __) async {},
      );
      addTearDown(field.dispose);

      field
        ..setValue(1)
        ..handleUnfocus();
      await pumpEventQueue();
      expect(field.value.isFailedValidation, isTrue);

      field.handleUnfocus();
      await pumpEventQueue();

      expect(validated, [1, 1]);
    });

    test('validates a read-only field, matching validate', () async {
      field
        ..setValidationMode(ValidationMode.onUnfocus)
        ..setValue(10)
        ..markReadOnly();
      validator.validationResult = _Error.malformed;

      field.handleUnfocus();
      await pumpEventQueue();

      expect(field.error, _Error.malformed);
    });

    testWidgets('runs when a bound focusNode loses focus', (tester) async {
      final text = AdvancedTextFieldController<_Error>(
        validator: (value) => value.isEmpty ? _Error.valueRequired : null,
      )..setValidationMode(ValidationMode.onUnfocus);
      addTearDown(text.dispose);
      final other = FocusNode();
      addTearDown(other.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                TextField(
                  controller: text.textController,
                  focusNode: text.focusNode,
                ),
                TextField(focusNode: other),
              ],
            ),
          ),
        ),
      );

      text.focusNode.requestFocus();
      await tester.pump();
      await tester.enterText(find.byType(TextField).first, 'x');
      await tester.enterText(find.byType(TextField).first, '');
      expect(text.error, isNull);

      other.requestFocus();
      await tester.pump();

      expect(text.error, _Error.valueRequired);
    });
  });

  group('setValidationMode', () {
    test('drops a round the old mode started', () async {
      final (:field, :validated) = _asyncField();
      addTearDown(field.dispose);

      field.setValue(1);
      expect(field.value.isPending, isTrue);

      field.setValidationMode(ValidationMode.disabled);
      await pumpEventQueue();

      expect(validated, isEmpty);
      expect(field.value.isValid, isTrue);
      expect(field.value.mode, ValidationMode.disabled);
    });

    test('re-publishing the same mode leaves a live round alone', () async {
      final (:field, :validated) = _asyncField();
      addTearDown(field.dispose);

      field
        ..setValue(1)
        ..setValidationMode(ValidationMode.onUserInteraction);
      await Future<void>.delayed(const Duration(milliseconds: 100));

      expect(validated, [1]);
    });

    test('validates nothing by itself', () async {
      validator.validationResult = _Error.malformed;
      field
        ..setValue(10)
        ..setValidationMode(ValidationMode.onUserInteraction);
      await pumpEventQueue();

      expect(field.error, isNull);
    });
  });

  group('prefill', () {
    test('stores the value and clears both errors without validating', () {
      validator.validationResult = _Error.malformed;
      field
        ..setValidationMode(ValidationMode.onUserInteraction)
        ..debugSetState(
          const _State(
            value: 1,
            validationError: _Error.valueRequired,
            asyncError: _Error.malformed,
            mode: ValidationMode.onUserInteraction,
            status: FieldStatus.invalid,
          ),
        )
        ..prefill(10);

      expect(field.fieldValue, 10);
      expect(field.error, isNull);
      expect(field.value.isValid, isTrue);
    });

    test('starts no async round', () async {
      final (:field, :validated) = _asyncField();
      addTearDown(field.dispose);

      field.prefill(10);
      await pumpEventQueue();

      expect(validated, isEmpty);
    });

    test('writes through a read-only field', () {
      field
        ..markReadOnly()
        ..prefill(10);

      expect(field.fieldValue, 10);
    });

    test('validate still checks a bad prefilled value', () async {
      validator.validationResult = _Error.malformed;
      field.prefill(10);

      expect(await field.validate(), isFalse);
      expect(field.error, _Error.malformed);
    });
  });

  group('disabled mode', () {
    test('an edit clears a stale error without running anything', () async {
      final (:field, :validated) = _asyncField(mode: ValidationMode.disabled);
      addTearDown(field.dispose);
      field
        ..setError(_Error.valueRequired)
        ..setValue(10);
      await pumpEventQueue();

      expect(field.error, isNull);
      expect(field.value.isValid, isTrue);
      expect(validated, isEmpty);
    });
  });
}
