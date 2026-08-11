import 'package:flutter/widgets.dart';
import 'package:leancode_forms/src/field/advanced_field_controller.dart';

/// A specialization of [AdvancedFieldController] for a [String] value.
///
/// Owns a [TextEditingController] kept in two-way sync with the field value,
/// and a [FocusNode] for focus-management flows. Widgets can bind directly to
/// [textController] and [focusNode].
///
/// [textController] is a projection of the field state, never an independent
/// source of truth: after every inbound mutation the text is reconciled with
/// [fieldValue] in the same turn, preserving the selection where possible. Text
/// typed into a read-only field is therefore reverted immediately.
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

  /// The [FocusNode] bound to this field. Lifecycle owned by this controller —
  /// do not dispose externally.
  late final FocusNode focusNode = FocusNode(
    debugLabel:
        'AdvancedTextFieldController${name?.isNotEmpty ?? false ? '($name)' : ''}',
  );

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
    final text = fieldValue;
    if (textController.text == text) {
      return;
    }

    final selection = textController.selection;
    final newSelection = selection.isValid &&
            selection.start <= text.length &&
            selection.end <= text.length
        ? selection
        : TextSelection.collapsed(offset: text.length);

    _reconciling = true;
    textController.value =
        TextEditingValue(text: text, selection: newSelection);
    _reconciling = false;
  }

  /// Requests focus for the field via [focusNode].
  void focus() => focusNode.requestFocus();

  @override
  void dispose() {
    removeListener(_reconcile);
    textController
      ..removeListener(_onTextControllerChanged)
      ..dispose();
    focusNode.dispose();
    super.dispose();
  }
}
