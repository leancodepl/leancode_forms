import 'package:flutter_test/flutter_test.dart';
import 'package:leancode_forms/leancode_forms.dart';

// These tests only ever pass validation, so the error code carries no meaning.
typedef _Error = String;

const _initialValue = 0;

/// Long enough that a round which waits it out cannot pass the elapsed checks
/// below by being merely slow.
const _longDebounce = Duration(seconds: 10);

/// A field whose async validator records every value it ran on, waits
/// [validatorDelay] and then passes. The gate is open, so a value change starts
/// a debounced round.
({AdvancedFieldController<int, _Error> field, List<int> validated})
    _asyncField({
  Duration debounce = _longDebounce,
  Duration validatorDelay = Duration.zero,
}) {
  final validated = <int>[];
  final field = AdvancedFieldController<int, _Error>(
    initialValue: _initialValue,
    asyncValidation: AsyncValidation(
      validator: (value) async {
        validated.add(value);
        await Future<void>.delayed(validatorDelay);
        return null;
      },
      debounce: debounce,
    ),
  )..setValidationMode(ValidationMode.onUserInteraction);

  return (field: field, validated: validated);
}

void main() {
  group('validate timing', () {
    test('a field flushes a debouncing round in the call itself', () async {
      final (:field, :validated) = _asyncField();
      addTearDown(field.dispose);

      field.setValue(10);
      expect(field.value.isPending, isTrue);

      final stopwatch = Stopwatch()..start();
      final result = field.validate();

      // Nothing has been awaited yet: the flush ran the validator on the spot,
      // rather than leaving the debounce to expire.
      expect(validated, const [10]);
      expect(field.value.isValidating, isTrue);

      expect(await result, isTrue);
      expect(stopwatch.elapsed, lessThan(const Duration(seconds: 1)));
    });

    test('a form flushes a debouncing field in the call itself', () async {
      final (:field, :validated) = _asyncField();
      final form = AdvancedFormController()..registerFields([field]);
      addTearDown(form.dispose);

      field.setValue(10);
      expect(field.value.isPending, isTrue);

      final stopwatch = Stopwatch()..start();
      final result = form.validate();

      expect(validated, const [10]);
      expect(field.value.isValidating, isTrue);

      expect(await result, isTrue);
      expect(stopwatch.elapsed, lessThan(const Duration(seconds: 1)));
    });

    test('a form validates fields and subforms concurrently', () async {
      const validatorDelay = Duration(milliseconds: 200);
      final first = _asyncField(validatorDelay: validatorDelay);
      final second = _asyncField(validatorDelay: validatorDelay);
      final nested = _asyncField(validatorDelay: validatorDelay);
      final subform = AdvancedFormController()..registerFields([nested.field]);
      final form = AdvancedFormController()
        ..registerFields([first.field, second.field])
        ..addSubform(subform);
      addTearDown(form.dispose);

      final stopwatch = Stopwatch()..start();
      expect(await form.validate(), isTrue);

      // One round each, run at the same time: validating them one after another
      // would cost three times [validatorDelay].
      expect(first.validated, const [_initialValue]);
      expect(second.validated, const [_initialValue]);
      expect(nested.validated, const [_initialValue]);
      expect(stopwatch.elapsed, lessThan(validatorDelay * 2));
    });
  });
}
