import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:leancode_forms/leancode_forms.dart';

void main() {
  group('AdvancedTextFieldController text controller sync', () {
    test('typing into textController updates field value', () {
      final tf = AdvancedTextFieldController<String>(initialValue: 'a')
        ..textController.text = 'abc';
      expect(tf.value.value, 'abc');
      tf.dispose();
    });

    test('setValue mirrors to textController', () {
      final tf = AdvancedTextFieldController<String>(initialValue: 'a')
        ..setValue('hello');
      expect(tf.textController.text, 'hello');
      tf.dispose();
    });

    test('reset clears both field and textController', () {
      final tf = AdvancedTextFieldController<String>()
        ..setValue('typed')
        ..reset();
      expect(tf.value.value, '');
      expect(tf.textController.text, '');
      tf.dispose();
    });

    test('input into a read-only field is reconciled in the same turn', () {
      final tf = AdvancedTextFieldController<String>(initialValue: 'locked')
        ..markReadOnly();
      addTearDown(tf.dispose);

      tf.textController.text = 'typed over';

      expect(tf.fieldValue, 'locked');
      expect(tf.textController.text, 'locked');
    });

    test('reconciling keeps the selection when it still fits', () {
      final tf = AdvancedTextFieldController<String>(initialValue: 'abcdef');
      addTearDown(tf.dispose);
      tf.textController.selection = const TextSelection.collapsed(offset: 3);

      tf.setValue('abcxyz');

      expect(tf.textController.text, 'abcxyz');
      expect(tf.textController.selection.baseOffset, 3);
    });
  });

  group('AdvancedTextFieldController selection mapping', () {
    /// Sets [initialValue] on a field, selects [selection], writes [newValue]
    /// and returns the reconciled text controller.
    TextEditingController reconciled(
      String initialValue,
      TextSelection selection,
      String newValue,
    ) {
      final tf = AdvancedTextFieldController<String>(
        initialValue: initialValue,
      );
      addTearDown(tf.dispose);
      tf.textController.selection = selection;

      tf.setValue(newValue);

      expect(tf.textController.text, newValue);
      return tf.textController;
    }

    test('a selection keeps covering the same characters after a cut', () {
      final c = reconciled(
        'lorem ipsum, dolor sit amet',
        const TextSelection(baseOffset: 13, extentOffset: 21),
        'lorem ip, dolor sit amet',
      );

      expect(
        c.selection,
        const TextSelection(baseOffset: 10, extentOffset: 18),
      );
      expect(c.text.substring(10, 18), 'dolor si');
    });

    test('a backwards selection stays backwards', () {
      final c = reconciled(
        'lorem ipsum, dolor sit amet',
        const TextSelection(baseOffset: 21, extentOffset: 13),
        'lorem ip, dolor sit amet',
      );

      expect(
        c.selection,
        const TextSelection(baseOffset: 18, extentOffset: 10),
      );
    });

    test(
        'text inserted at the front moves the selection instead of '
        'stretching it', () {
      final c = reconciled(
        'bcd',
        const TextSelection(baseOffset: 0, extentOffset: 1),
        'abcd',
      );

      expect(c.selection, const TextSelection(baseOffset: 1, extentOffset: 2));
      expect(c.text.substring(1, 2), 'b');
    });

    test('a caret at the end follows a prefix added by formatting', () {
      final c = reconciled(
        '1234',
        const TextSelection.collapsed(offset: 4),
        '+48 1234',
      );

      expect(c.selection.baseOffset, 8);
    });

    test('a caret inside a run that was replaced lands at its start', () {
      final c = reconciled(
        'lorem ipsum, dolor sit amet',
        const TextSelection(baseOffset: 13, extentOffset: 21),
        'lorem',
      );

      expect(c.selection, const TextSelection.collapsed(offset: 5));
    });

    test('an emptied field collapses the caret to zero', () {
      final c = reconciled('abc', const TextSelection.collapsed(offset: 3), '');

      expect(c.selection, const TextSelection.collapsed(offset: 0));
    });

    test('a caret in text that grew from empty lands at the end', () {
      final c = reconciled('', const TextSelection.collapsed(offset: 0), 'abc');

      expect(c.selection.baseOffset, 3);
    });

    test('overlapping head and tail anchors keep the caret in range', () {
      expect(
        reconciled('aa', const TextSelection.collapsed(offset: 2), 'aaa')
            .selection,
        const TextSelection.collapsed(offset: 3),
      );
      expect(
        reconciled('aa', const TextSelection.collapsed(offset: 0), 'aaa')
            .selection,
        const TextSelection.collapsed(offset: 0),
      );
      expect(
        reconciled('aaa', const TextSelection.collapsed(offset: 3), 'aa')
            .selection,
        const TextSelection.collapsed(offset: 2),
      );
    });

    test('a transformed value settles in one pass, without looping', () {
      final tf = _UpperCaseField();
      addTearDown(tf.dispose);
      final states = <String>[];
      tf.addListener(() => states.add(tf.fieldValue));

      // A keystroke, as the engine reports it.
      tf.textController.value = const TextEditingValue(
        text: 'ab',
        selection: TextSelection.collapsed(offset: 2),
      );

      // Writing the transformed text back re-enters the text listener. It has to
      // stop there: one accepted value, one notification, no recursion.
      expect(tf.fieldValue, 'AB');
      expect(tf.textController.text, 'AB');
      expect(states, ['AB']);
    });

    test('a caret between two identical characters stays where it was', () {
      // "a|a" -> "aaa" is ambiguous: the new character could have gone in on
      // either side of the caret. Leaving the caret put is the answer that does
      // not move it under the user.
      expect(
        reconciled('aa', const TextSelection.collapsed(offset: 1), 'aaa')
            .selection,
        const TextSelection.collapsed(offset: 1),
      );
    });

    test('two texts sharing no characters keep the offsets in range', () {
      final c = reconciled(
        'abc',
        const TextSelection(baseOffset: 0, extentOffset: 3),
        'xyz',
      );

      expect(c.selection, const TextSelection(baseOffset: 0, extentOffset: 3));
    });

    test('an invalid selection collapses to the end', () {
      final tf = AdvancedTextFieldController<String>(initialValue: 'abc');
      addTearDown(tf.dispose);
      // Assigning `text` is what leaves the selection at -1.
      tf.textController.text = 'abc';

      tf.setValue('abcdef');

      expect(tf.textController.selection.baseOffset, 6);
    });

    test('affinity and isDirectional survive the mapping', () {
      final c = reconciled(
        'abcdef',
        const TextSelection(
          baseOffset: 1,
          extentOffset: 3,
          affinity: TextAffinity.upstream,
          isDirectional: true,
        ),
        'abcxyz',
      );

      expect(c.selection.affinity, TextAffinity.upstream);
      expect(c.selection.isDirectional, isTrue);
    });

    test('a refused keystroke puts the caret back where it was', () {
      final tf = AdvancedTextFieldController<String>(initialValue: 'locked')
        ..markReadOnly();
      addTearDown(tf.dispose);

      // A character typed at offset 4, as the engine would report it.
      tf.textController.value = const TextEditingValue(
        text: 'lockXed',
        selection: TextSelection.collapsed(offset: 5),
      );

      expect(tf.textController.text, 'locked');
      expect(tf.textController.selection.baseOffset, 4);
    });

    test('offsets never land inside a character', () {
      // The two texts differ in the second half of the emoji, so a raw
      // code-unit anchor would sit between its halves.
      final c = reconciled(
        '\u{1F600}b',
        const TextSelection(baseOffset: 2, extentOffset: 3),
        '\u{1F601}c',
      );

      expect(c.selection.start, isNot(1));
      expect(c.selection.end, isNot(1));
      expect(c.selection, const TextSelection(baseOffset: 0, extentOffset: 3));
    });

    test('the tail anchor cannot split a character either', () {
      // U+1D400 and U+1D000 share their second code unit and differ in the
      // first, so the tail scan stops between the halves of both characters.
      // Every offset a valid selection can hold must still map onto a boundary.
      for (final offset in [0, 2, 3]) {
        final c = reconciled(
          '\u{1D400}x',
          TextSelection.collapsed(offset: offset),
          '\u{1D000}x',
        );

        expect(c.selection.baseOffset, isNot(1), reason: 'from offset $offset');
      }
    });
  });

  group('AdvancedTextFieldController focus node', () {
    test('focusNode is created and not focused initially', () {
      final tf = AdvancedTextFieldController<String>();
      expect(tf.focusNode.hasFocus, false);
      tf.dispose();
    });

    testWidgets('focus() requests focus on the focusNode', (tester) async {
      final tf = AdvancedTextFieldController<String>();
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
      final tf = AdvancedTextFieldController<String>();
      final node = tf.focusNode;
      tf.dispose();
      expect(node.dispose, throwsAssertionError);
    });
  });
}

/// A field that upper-cases whatever is written to it, so a write to
/// `textController` never lands unchanged.
class _UpperCaseField extends AdvancedTextFieldController<String> {
  @override
  void setValue(String newValue, {bool force = false}) =>
      super.setValue(newValue.toUpperCase(), force: force);
}
