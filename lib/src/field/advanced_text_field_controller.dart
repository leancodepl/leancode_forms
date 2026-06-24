import 'package:flutter/widgets.dart';
import 'package:leancode_forms/src/field/advanced_field_controller.dart';

/// A specialization of [AdvancedFieldController] for a [String] value.
///
/// Owns a [TextEditingController] kept in two-way sync with the field value,
/// and a [FocusNode] for focus-management flows. Widgets can bind directly to
/// [textController] and [focusNode]; programmatic changes via [setValue] /
/// [reset] / [clearErrors] propagate to the text controller, and user input on
/// the text controller propagates back to the field state.
class AdvancedTextFieldController<E extends Object> extends AdvancedFieldController<String, E> {
  /// Creates a new [AdvancedTextFieldController].
  AdvancedTextFieldController({
    super.initialValue = '',
    super.validator,
    super.asyncValidator,
    super.asyncValidationDebounce,
    super.name,
  }) : textController = TextEditingController(text: initialValue) {
    textController.addListener(_onTextControllerChanged);
    addListener(_onFieldChanged);
  }

  /// The [TextEditingController] bound to this field. Lifecycle owned by this
  /// controller — do not dispose externally.
  final TextEditingController textController;

  /// The [FocusNode] bound to this field. Lifecycle owned by this controller — do not dispose externally.
  late final FocusNode focusNode = FocusNode(
    debugLabel:
        'AdvancedTextFieldController${name?.isNotEmpty ?? false ? '($name)' : ''}',
  );

  void _onTextControllerChanged() {
    if (textController.text != value.value) {
      setValue(textController.text);
    }
  }

  void _onFieldChanged() {
    if (textController.text != value.value) {
      textController.text = value.value;
    }
  }

  /// Requests focus for the field via [focusNode].
  void focus() => focusNode.requestFocus();

  @override
  void dispose() {
    removeListener(_onFieldChanged);
    textController
      ..removeListener(_onTextControllerChanged)
      ..dispose();
    focusNode.dispose();
    super.dispose();
  }
}
