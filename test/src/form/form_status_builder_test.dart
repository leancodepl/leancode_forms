import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:leancode_forms/leancode_forms.dart';

enum _Error { invalid }

void main() {
  testWidgets(
      'AdvancedValidationStatusBuilder rebuilds when a field status flips, '
      'and emits true only when every field is valid', (tester) async {
    final field = AdvancedFieldController<String, _Error>(
      initialValue: 'ok',
      validator: (v) => v == 'ok' ? null : _Error.invalid,
    );
    final form = AdvancedFormController()..registerFields([field]);
    addTearDown(form.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AdvancedValidationStatusBuilder(
            form: form,
            builder: (context, isValid, _) =>
                Text(isValid ? 'VALID' : 'INVALID'),
          ),
        ),
      ),
    );

    expect(find.text('VALID'), findsOneWidget);

    // Push the field into an invalid state via autovalidate + bad value.
    field
      ..setAutovalidate(true)
      ..setValue('bad');
    await tester.pump();

    expect(find.text('INVALID'), findsOneWidget);

    // Back to valid.
    field.setValue('ok');
    await tester.pump();

    expect(find.text('VALID'), findsOneWidget);
  });

  testWidgets(
      'AdvancedValidationStatusBuilder treats subform fields as part of the validity check',
      (tester) async {
    final parentField = AdvancedFieldController<String, _Error>(
      initialValue: 'ok',
      validator: (v) => v == 'ok' ? null : _Error.invalid,
    );
    final subformField = AdvancedFieldController<String, _Error>(
      initialValue: 'ok',
      validator: (v) => v == 'ok' ? null : _Error.invalid,
    );
    final subform = AdvancedFormController()..registerFields([subformField]);
    final parent = AdvancedFormController()
      ..registerFields([parentField])
      ..addSubform(subform);
    addTearDown(parent.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AdvancedValidationStatusBuilder(
            form: parent,
            builder: (context, isValid, _) =>
                Text(isValid ? 'VALID' : 'INVALID'),
          ),
        ),
      ),
    );

    expect(find.text('VALID'), findsOneWidget);

    // Invalidate via the subform.
    subformField
      ..setAutovalidate(true)
      ..setValue('bad');
    await tester.pump();

    expect(find.text('INVALID'), findsOneWidget);
  });

  testWidgets(
      'AdvancedValidationStatusBuilder forwards child to the builder for static-subtree reuse',
      (tester) async {
    final field = AdvancedFieldController<String, _Error>(
      initialValue: 'ok',
      validator: (v) => v == 'ok' ? null : _Error.invalid,
    );
    final form = AdvancedFormController()..registerFields([field]);
    addTearDown(form.dispose);

    var builds = 0;
    Widget buildChild() {
      builds++;
      return const Text('STATIC');
    }

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AdvancedValidationStatusBuilder(
            form: form,
            child: buildChild(),
            builder: (context, isValid, child) => Row(
              children: [
                child!,
                Text(isValid ? 'VALID' : 'INVALID'),
              ],
            ),
          ),
        ),
      ),
    );

    expect(builds, 1);
    expect(find.text('STATIC'), findsOneWidget);

    field
      ..setAutovalidate(true)
      ..setValue('bad');
    await tester.pump();

    // The `child` widget was built once outside the builder closure — the
    // rebuild does not re-invoke `buildChild()`.
    expect(builds, 1);
    expect(find.text('STATIC'), findsOneWidget);
    expect(find.text('INVALID'), findsOneWidget);
  });
}
