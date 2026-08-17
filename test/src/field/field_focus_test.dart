import 'package:advanced_forms/advanced_forms.dart';
import 'package:flutter/material.dart';
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

  group('onUnfocus', () {
    test('an unfocus flushes a round still waiting out its debounce', () async {
      final (:field, :validated) = makeAsyncField(
        debounce: const Duration(seconds: 30),
      );
      addTearDown(field.dispose);

      field.setValue(10);
      expect(field.value.isPending, isTrue);

      await field.handleUnfocus();
      await pumpEventQueue();

      expect(validated, [10]);
    });

    test('an unfocus reuses a verdict that still describes the value',
        () async {
      final (:field, :validated) = makeAsyncField(
        mode: ValidationMode.onUnfocus,
      );
      addTearDown(field.dispose);

      field.setValue(10);
      await field.handleUnfocus();
      await pumpEventQueue();
      expect(validated, [10]);

      // A second focus cycle over an unchanged value owes nothing.
      await field.handleUnfocus();
      await pumpEventQueue();

      expect(validated, [10]);
    });

    test('an unfocus retries a round that failed', () async {
      var attempts = 0;
      final (:field, :validated) = makeAsyncField(
        mode: ValidationMode.onUnfocus,
        result: () => throw StateError('validator exploded'),
        onFailure: (_, __) async => attempts++,
      );
      addTearDown(field.dispose);

      field.setValue(10);
      await field.handleUnfocus();
      await pumpEventQueue();
      expect(field.value.isFailedValidation, isTrue);

      await field.handleUnfocus();
      await pumpEventQueue();

      expect(validated, [10, 10]);
      expect(attempts, 2);
    });

    test('an unfocus validates a read-only field', () async {
      validator.validationResult = TestError.malformed;
      field
        ..setValidationMode(ValidationMode.onUnfocus)
        ..setValue(10)
        ..markReadOnly();
      await field.handleUnfocus();
      await pumpEventQueue();

      expect(field.value.error, TestError.malformed);
    });

    test('a throwing validator is reported instead of escaping the zone',
        () async {
      final reported = <FlutterErrorDetails>[];
      final previous = FlutterError.onError;
      FlutterError.onError = reported.add;
      addTearDown(() => FlutterError.onError = previous);

      final subject = AdvancedFieldController<int, TestError>(
        initialValue: 0,
        validator: (_) => throw StateError('validator exploded'),
      )
        ..setValidationMode(ValidationMode.onUnfocus)
        ..setValue(10);
      addTearDown(subject.dispose);

      await subject.handleUnfocus();
      await pumpEventQueue();

      expect(reported.single.exception, isStateError);
      expect(reported.single.library, 'advanced_forms');
    });

    testWidgets('losing focus on the bound node validates the field',
        (tester) async {
      validator.validationResult = TestError.malformed;
      field
        ..setValidationMode(ValidationMode.onUnfocus)
        ..setValue(10);
      final other = FocusNode();
      addTearDown(other.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Column(
            children: [
              Focus(
                focusNode: field.focusNode,
                child: const SizedBox.square(dimension: 10),
              ),
              Focus(
                focusNode: other,
                child: const SizedBox.square(dimension: 10),
              ),
            ],
          ),
        ),
      );

      field.focusNode.requestFocus();
      await tester.pump();
      expect(field.value.error, isNull);

      other.requestFocus();
      await tester.pump();

      expect(field.value.error, TestError.malformed);
    });

    testWidgets('tabbing through a field without editing it costs nothing',
        (tester) async {
      validator.validationResult = TestError.malformed;
      field.setValidationMode(ValidationMode.onUnfocus);
      final other = FocusNode();
      addTearDown(other.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Column(
            children: [
              Focus(
                focusNode: field.focusNode,
                child: const SizedBox.square(dimension: 10),
              ),
              Focus(
                focusNode: other,
                child: const SizedBox.square(dimension: 10),
              ),
            ],
          ),
        ),
      );

      field.focusNode.requestFocus();
      await tester.pump();
      other.requestFocus();
      await tester.pump();

      expect(field.value.error, isNull);
    });
  });

  group('a supplied focusNode', () {
    test('is the node the field binds to', () {
      final node = FocusNode();
      addTearDown(node.dispose);
      final subject = AdvancedFieldController<int, TestError>(
        initialValue: initialValue,
        focusNode: node,
      );
      addTearDown(subject.dispose);

      expect(subject.focusNode, same(node));
    });

    testWidgets('validates on a blur even if focusNode was never read',
        (tester) async {
      final node = FocusNode();
      addTearDown(node.dispose);
      final subject = AdvancedFieldController<int, TestError>(
        initialValue: initialValue,
        validator: (_) => TestError.malformed,
        focusNode: node,
      )..setValidationMode(ValidationMode.onUnfocus);
      addTearDown(subject.dispose);

      final other = FocusNode();
      addTearDown(other.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Column(
            children: [
              Focus(
                focusNode: node,
                child: const SizedBox.square(dimension: 10),
              ),
              Focus(
                focusNode: other,
                child: const SizedBox.square(dimension: 10),
              ),
            ],
          ),
        ),
      );

      subject.setValue(10);
      node.requestFocus();
      await tester.pump();
      other.requestFocus();
      await tester.pump();

      expect(subject.value.error, TestError.malformed);
    });

    test('outlives the field it was given to', () {
      final node = FocusNode();
      addTearDown(node.dispose);
      AdvancedFieldController<int, TestError>(
        initialValue: initialValue,
        focusNode: node,
      ).dispose();

      // A disposed node throws here instead.
      expect(() => node.addListener(() {}), returnsNormally);
    });
  });
}
