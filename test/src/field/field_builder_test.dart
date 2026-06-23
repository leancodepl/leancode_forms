import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:leancode_forms/leancode_forms.dart';

void main() {
  testWidgets('AdvancedFieldBuilder rebuilds when the field changes', (tester) async {
    final field = AdvancedTextFieldController<String>(initialValue: 'first');
    addTearDown(field.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AdvancedFieldBuilder<AdvancedTextFieldController<String>>(
            field: field,
            builder: (context, field, _) => Text(field.value.value),
          ),
        ),
      ),
    );

    expect(find.text('first'), findsOneWidget);

    field.setValue('second');
    await tester.pump();

    expect(find.text('first'), findsNothing);
    expect(find.text('second'), findsOneWidget);
  });
}
