import 'package:flutter/widgets.dart';
import 'package:leancode_forms/src/field/field_controller.dart';

/// A specialization of [FieldController] for a [String] value.
///
/// Owns a [TextEditingController] kept in two-way sync with the field value.
/// Widgets can bind directly to [textController]; programmatic changes via
/// [setValue] / [reset] / [clearErrors] propagate to the text controller, and
/// user input on the text controller propagates back to the field state.
class TextFieldController<E extends Object> extends FieldController<String, E> {
  /// Creates a new [TextFieldController].
  TextFieldController({
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

  /// Clears the value of the field, resetting it to its initial value.
  void clear() => reset();

  @override
  void dispose() {
    removeListener(_onFieldChanged);
    textController
      ..removeListener(_onTextControllerChanged)
      ..dispose();
    super.dispose();
  }
}
