import 'package:flutter/widgets.dart';
import 'package:leancode_forms/src/field/advanced_field_controller.dart';

/// A specialization of [AdvancedFieldController] for a [String] value.
///
/// Owns a [TextEditingController] kept in two-way sync with the field value,
/// and a [FocusNode] for focus-management flows. Widgets can bind directly to
/// [textController] and [focusNode].
///
/// [textController] never holds a value of its own: after every write to the
/// field, its text is put back in step with [fieldValue] in the same turn,
/// keeping the cursor and the selection on the same characters where possible.
/// Text typed into a read-only field is therefore reverted immediately.
class AdvancedTextFieldController<E extends Object>
    extends AdvancedFieldController<String, E> {
  /// Creates a new [AdvancedTextFieldController].
  AdvancedTextFieldController({
    super.initialValue = '',
    super.validator,
    super.asyncValidation,
    super.name,
  }) : textController = TextEditingController(text: initialValue) {
    textController.addListener(_onTextControllerChanged);
    addListener(_reconcile);
  }

  /// The [TextEditingController] bound to this field. Lifecycle owned by this
  /// controller — do not dispose externally.
  final TextEditingController textController;

  FocusNode? _focusNode;

  /// The [FocusNode] bound to this field, created on first use.
  ///
  /// Throws a [StateError] if controller is disposed.
  FocusNode get focusNode {
    if (isDisposed) {
      throw StateError(
        'Cannot use the focusNode of a disposed AdvancedTextFieldController.',
      );
    }

    return _focusNode ??= FocusNode(
      debugLabel:
          'AdvancedTextFieldController${name?.isNotEmpty ?? false ? '($name)' : ''}',
    );
  }

  /// True while [_reconcile] is writing to [textController], so the write does
  /// not come back through [_onTextControllerChanged] as user input.
  bool _reconciling = false;

  void _onTextControllerChanged() {
    if (_reconciling) {
      return;
    }
    if (textController.text != fieldValue) {
      setValue(textController.text);
      // The field may have refused the write — read-only, or a subclass
      // transformed the value — so reconcile in the same turn.
      _reconcile();
    }
  }

  void _reconcile() {
    final oldText = textController.text;
    final text = fieldValue;
    if (oldText == text) {
      return;
    }

    _reconciling = true;
    textController.value = TextEditingValue(
      text: text,
      selection: _mapSelection(textController.selection, oldText, text),
    );
    _reconciling = false;
  }

  // Moves a selection from `oldText` onto `newText` so that it keeps covering
  // the same characters instead of the same offsets. The unchanged head and
  // tail are the anchors, the way a `TextInputFormatter` works.
  static TextSelection _mapSelection(
    TextSelection selection,
    String oldText,
    String newText,
  ) {
    if (!selection.isValid) {
      return TextSelection.collapsed(offset: newText.length);
    }

    // Neither anchor may reach past the shorter text, so they cannot overlap.
    final shorter =
        oldText.length < newText.length ? oldText.length : newText.length;
    var prefix = 0;
    while (prefix < shorter && oldText[prefix] == newText[prefix]) {
      prefix++;
    }
    // The scan compares UTF-16 code units, so it can stop halfway through a
    // character such as an emoji. One unit back is the character boundary.
    if (_splitsCharacter(newText, prefix)) {
      prefix--;
    }
    var suffix = 0;
    while (suffix < shorter - prefix &&
        oldText[oldText.length - suffix - 1] ==
            newText[newText.length - suffix - 1]) {
      suffix++;
    }

    int map(int offset) {
      // In the unchanged tail: move by however much the length changed. Tested
      // before the head, otherwise text inserted at offset 0 stretches the
      // selection instead of moving it.
      if (offset >= oldText.length - suffix) {
        return offset + newText.length - oldText.length;
      }
      // In the unchanged head: stay put.
      if (offset <= prefix) {
        return offset;
      }
      // In the run that was replaced, so there is nothing left to point at.
      return prefix;
    }

    return TextSelection(
      baseOffset: map(selection.baseOffset).clamp(0, newText.length),
      extentOffset: map(selection.extentOffset).clamp(0, newText.length),
      affinity: selection.affinity,
      isDirectional: selection.isDirectional,
    );
  }

  // Whether `offset` falls between the two halves of one character.
  static bool _splitsCharacter(String text, int offset) =>
      offset > 0 &&
      offset < text.length &&
      (text.codeUnitAt(offset - 1) & 0xFC00) == 0xD800 &&
      (text.codeUnitAt(offset) & 0xFC00) == 0xDC00;

  /// Requests focus for the field via [focusNode]. A no-op once the controller
  /// has been disposed, so `focus()` after a teardown is safe.
  void focus() {
    if (isDisposed) {
      return;
    }

    focusNode.requestFocus();
  }

  @override
  void dispose() {
    removeListener(_reconcile);
    textController
      ..removeListener(_onTextControllerChanged)
      ..dispose();
    _focusNode?.dispose();
    super.dispose();
  }
}
