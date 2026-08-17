import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:leancode_forms/leancode_forms.dart';

enum _Error { valueRequired, taken }

const _options = ['a', 'b', 'c'];

/// Counts how many times [field] notifies.
int Function() _countCalls(Listenable field) {
  var count = 0;
  field.addListener(() => count++);
  return () => count;
}

void main() {
  group('AdvancedSingleSelectFieldController', () {
    late AdvancedSingleSelectFieldController<String, _Error> field;

    setUp(() {
      field = AdvancedSingleSelectFieldController<String, _Error>(
        initialValue: null,
        options: _options,
      );
    });

    tearDown(() => field.dispose());

    test('select stores an option', () {
      field.select('b');

      expect(field.fieldValue, 'b');
    });

    test('select(null) clears the selection', () {
      field
        ..select('b')
        ..select(null);

      expect(field.fieldValue, null);
    });

    test('select asserts a value that is not one of the options', () {
      expect(() => field.select('zzz'), throwsAssertionError);
      expect(field.fieldValue, null);
    });

    test('re-selecting the same option does not notify', () {
      field.select('b');
      final notifications = _countCalls(field);

      field.select('b');

      expect(notifications(), 0);
    });

    test('select runs the sync validator when the gate is open', () {
      final validated = <String?>[];
      final validatingField =
          AdvancedSingleSelectFieldController<String, _Error>(
        initialValue: null,
        options: _options,
        validator: (value) {
          validated.add(value);
          return value == null ? _Error.valueRequired : null;
        },
      )..setValidationMode(ValidationMode.onUserInteraction);
      addTearDown(validatingField.dispose);

      validatingField.select('a');

      expect(validated, ['a']);
      expect(validatingField.error, null);

      validatingField.select(null);

      expect(validatingField.error, _Error.valueRequired);
    });

    test('forwards asyncValidation to the base controller', () async {
      final checked = <String?>[];
      final asyncField = AdvancedSingleSelectFieldController<String, _Error>(
        initialValue: 'a',
        options: _options,
        asyncValidation: AsyncValidation(
          validator: (value) async {
            checked.add(value);
            return value == 'b' ? _Error.taken : null;
          },
          debounce: Duration.zero,
        ),
      );
      addTearDown(asyncField.dispose);

      expect(await asyncField.validate(), true);
      expect(checked, ['a']);

      asyncField.select('b');

      expect(await asyncField.validate(), false);
      expect(checked, ['a', 'b']);
      expect(asyncField.error, _Error.taken);
    });
  });

  group('AdvancedMultiSelectFieldController', () {
    late AdvancedMultiSelectFieldController<String, _Error> field;

    setUp(() {
      field = AdvancedMultiSelectFieldController<String, _Error>(
        initialValue: const <String>{},
        options: _options,
      );
    });

    tearDown(() => field.dispose());

    test('addValue and removeValue change the selection', () {
      field
        ..addValue('a')
        ..addValue('b');

      expect(field.fieldValue, {'a', 'b'});

      field.removeValue('a');

      expect(field.fieldValue, {'b'});
    });

    test('toggleElement adds a missing value and removes a present one', () {
      field.toggleElement('c');

      expect(field.fieldValue, {'c'});

      field.toggleElement('c');

      expect(field.fieldValue, isEmpty);
    });

    test('addValue asserts a value that is not one of the options', () {
      expect(() => field.addValue('zzz'), throwsAssertionError);
      expect(field.fieldValue, isEmpty);
    });

    test('toggleElement asserts when it would add an unknown value', () {
      expect(() => field.toggleElement('zzz'), throwsAssertionError);
    });

    test('removeValue does not assert — it never adds', () {
      expect(() => field.removeValue('zzz'), returnsNormally);
    });

    test('a write that leaves the set equal does not notify', () {
      field.addValue('a');
      final notifications = _countCalls(field);

      field
        ..addValue('a')
        ..removeValue('zzz');

      expect(notifications(), 0);
    });

    test('a read-only field ignores addValue, removeValue and toggleElement',
        () {
      field
        ..addValue('a')
        ..markReadOnly()
        ..addValue('b')
        ..removeValue('a')
        ..toggleElement('c');

      expect(field.fieldValue, {'a'});
    });

    test('forwards asyncValidation to the base controller', () async {
      final checked = <Set<String>>[];
      final asyncField = AdvancedMultiSelectFieldController<String, _Error>(
        initialValue: const <String>{'a'},
        options: _options,
        asyncValidation: AsyncValidation(
          validator: (value) async {
            checked.add(value);
            return value.contains('b') ? _Error.taken : null;
          },
          debounce: Duration.zero,
        ),
      );
      addTearDown(asyncField.dispose);

      expect(await asyncField.validate(), true);
      expect(checked, [
        {'a'},
      ]);

      asyncField.addValue('b');

      expect(await asyncField.validate(), false);
      expect(asyncField.error, _Error.taken);
    });
  });
}
