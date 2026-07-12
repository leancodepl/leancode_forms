import 'package:flutter_test/flutter_test.dart';
import 'package:leancode_forms/leancode_forms.dart';

enum _Error { malformed }

typedef _Value = ({String unit, int? amount});

typedef _Field = AdvancedFieldController<_Value, _Error>;

void main() {
  late _Field field;

  setUp(() {
    field = AdvancedFieldController<_Value, _Error>(
      initialValue: (unit: 'kg', amount: 1),
    );
  });

  tearDown(() {
    field.dispose();
  });

  group('convenience getters', () {
    test('fieldValue is a shortcut for value.value', () {
      expect(field.fieldValue, (unit: 'kg', amount: 1));
      field.setValue((unit: 'kg', amount: 2));
      expect(field.fieldValue, field.value.value);
    });

    test('error is a shortcut for value.error', () {
      expect(field.error, isNull);
      field.setError(_Error.malformed);
      expect(field.error, _Error.malformed);
      expect(field.error, field.value.error);
    });
  });

  group('onValueChange', () {
    test('fires when the selected part changes', () {
      final changes = <int?>[];
      field
        ..onValueChange((value) => value.amount, changes.add)
        ..setValue((unit: 'kg', amount: 2))
        ..setValue((unit: 'kg', amount: 3));

      expect(changes, [2, 3]);
    });

    test('does not fire when a non-selected part changes', () {
      final changes = <int?>[];
      field
        ..onValueChange((value) => value.amount, changes.add)
        ..setValue((unit: 'lb', amount: 1));

      expect(changes, isEmpty);
    });

    test('does not fire for state changes without a value change', () {
      final changes = <int?>[];
      field
        ..onValueChange((value) => value.amount, changes.add)
        ..setAutovalidate(true)
        ..markReadOnly();

      expect(changes, isEmpty);
    });

    test('stops firing after cleanup is called', () {
      final changes = <int?>[];
      final cleanup = field.onValueChange((value) => value.amount, changes.add);

      field.setValue((unit: 'kg', amount: 2));
      cleanup();
      field.setValue((unit: 'kg', amount: 3));

      expect(changes, [2]);
    });
  });

  group('stream', () {
    test('emits states after subscription', () async {
      final emissions = <AdvancedFieldState<_Value, _Error>>[];
      final subscription = field.stream.listen(emissions.add);
      // Broadcast stream attaches its listener on onListen, which is
      // synchronous here, but events are delivered asynchronously.
      field.setValue((unit: 'kg', amount: 2));
      await Future<void>.delayed(Duration.zero);

      expect(emissions, [
        const AdvancedFieldState<_Value, _Error>(
          value: (unit: 'kg', amount: 2),
        ),
      ]);

      await subscription.cancel();
    });

    test('detaches from the controller after the last cancel', () async {
      final subscription = field.stream.listen((_) {});
      await subscription.cancel();

      // If the bridge leaked its listener, this would throw on dispose
      // in debug mode ("used after being disposed") or keep notifying.
      field.setValue((unit: 'kg', amount: 2));
      expect(field.fieldValue.amount, 2);
    });
  });
}
