import 'dart:async';

import 'package:advanced_forms/advanced_forms.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'field_test_helpers.dart';

void main() {
  group('async validation failure', () {
    late TestField throwingField;
    late List<FlutterErrorDetails> reported;
    void Function(FlutterErrorDetails)? previousOnError;

    setUp(() {
      reported = [];
      previousOnError = FlutterError.onError;
      FlutterError.onError = reported.add;

      throwingField = AdvancedFieldController<int, TestError>(
        name: 'throwing',
        initialValue: initialValue,
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
      final emissions = recordStates(throwingField);

      throwingField.setValue(10);
      await Future<void>.delayed(const Duration(milliseconds: 600));

      expect(emissions, const [
        TestState(
          value: 10,
          status: FieldStatus.pending,
          validationMode: ValidationMode.onUserInteraction,
        ),
        TestState(
          value: 10,
          status: FieldStatus.validating,
          validationMode: ValidationMode.onUserInteraction,
        ),
        TestState(
          value: 10,
          status: FieldStatus.failedValidation,
          validationMode: ValidationMode.onUserInteraction,
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
      final syncThrower = AdvancedFieldController<int, TestError>(
        name: 'sync-throwing',
        initialValue: initialValue,
        asyncValidation: AsyncValidation(
          validator: (value) => throw StateError('validator exploded'),
          onFailure: (error, stackTrace) async => handled.add(error),
        ),
      )..setValidationMode(ValidationMode.onUserInteraction);
      addTearDown(syncThrower.dispose);
      final emissions = recordStates(syncThrower);

      syncThrower.setValue(10);
      await Future<void>.delayed(const Duration(milliseconds: 600));

      expect(emissions, const [
        TestState(
          value: 10,
          status: FieldStatus.pending,
          validationMode: ValidationMode.onUserInteraction,
        ),
        TestState(
          value: 10,
          status: FieldStatus.validating,
          validationMode: ValidationMode.onUserInteraction,
        ),
        TestState(
          value: 10,
          status: FieldStatus.failedValidation,
          validationMode: ValidationMode.onUserInteraction,
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
      final ownedField = AdvancedFieldController<int, TestError>(
        initialValue: initialValue,
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
      final (:field, :validated) = makeAsyncField(
        debounce: const Duration(milliseconds: 10),
        validatorDelay: const Duration(milliseconds: 300),
        timeout: const Duration(milliseconds: 50),
        result: () => TestError.unavailable,
        onFailure: (error, stackTrace) async {},
      );
      addTearDown(field.dispose);

      field.setValue(10);
      await Future<void>.delayed(const Duration(milliseconds: 150));

      expect(field.value.isFailedValidation, isTrue);
      expect(field.lastFailure?.error, isA<TimeoutException>());
      expect(field.lastFailure?.timedOut, isTrue);

      final emissions = recordStates(field);
      await Future<void>.delayed(const Duration(milliseconds: 400));

      // The abandoned validator resolved with `unavailable`; it is dropped.
      expect(emissions, isEmpty);
      expect(field.value.asyncError, isNull);
      expect(field.value.isFailedValidation, isTrue);
    });

    test('a validator throwing after its timeout still reports the timeout',
        () async {
      final (:field, :validated) = makeAsyncField(
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

      final emissions = recordStates(field);
      await Future<void>.delayed(const Duration(milliseconds: 400));

      expect(emissions, isEmpty);
      expect(field.lastFailure?.error, isA<TimeoutException>());
    });

    test('failureToError gives a failed round something to display', () async {
      final (:field, :validated) = makeAsyncField(
        onValidate: (_) => throw StateError('validator exploded'),
        onFailure: (error, stackTrace) async {},
        failureToError: (error, stackTrace) => TestError.unavailable,
      );
      addTearDown(field.dispose);

      expect(await field.validate(), isFalse);

      expect(field.value.isFailedValidation, isTrue);
      expect(field.value.asyncError, TestError.unavailable);
      expect(field.error, TestError.unavailable);
      expect(field.lastFailure?.error, isStateError);
    });

    group('AsyncValidation.onFailure', () {
      TestField fieldWithHandler(AsyncValidationFailureHandler onFailure) {
        final field = AdvancedFieldController<int, TestError>(
          name: 'handled',
          initialValue: initialValue,
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
}
