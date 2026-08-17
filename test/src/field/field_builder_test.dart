import 'package:advanced_forms/advanced_forms.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('AdvancedFieldBuilder rebuilds when the field changes',
      (tester) async {
    final field = AdvancedTextFieldController<String>(initialValue: 'first');
    addTearDown(field.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AdvancedFieldBuilder<String, String>(
            field: field,
            builder: (context, state, _) => Text(state.value),
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
