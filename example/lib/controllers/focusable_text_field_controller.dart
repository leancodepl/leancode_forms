import 'package:flutter/widgets.dart';
import 'package:leancode_forms/leancode_forms.dart';

/// A [AdvancedTextFieldController] that owns a [FocusNode] for scroll-to-error flows.
class FocusableTextFieldController<E extends Object>
    extends AdvancedTextFieldController<E> {
  FocusableTextFieldController({
    super.initialValue,
    super.validator,
    super.asyncValidator,
    super.asyncValidationDebounce,
    super.name,
  });

  /// The focus node of the field.
  late final focusNode = FocusNode(
    debugLabel: 'FocusableTextFieldController${name?.isNotEmpty ?? false ? '($name)' : ''}',
  );

  /// Focuses the field.
  void focus() => focusNode.requestFocus();

  @override
  void dispose() {
    focusNode.dispose();
    super.dispose();
  }
}
