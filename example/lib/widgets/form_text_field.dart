import 'package:flutter/material.dart';
import 'package:leancode_forms/leancode_forms.dart';
import 'package:leancode_forms_example/widgets/app_text_field.dart';

class FormTextField<E extends Object> extends StatelessWidget {
  const FormTextField({
    super.key,
    required this.field,
    required this.translateError,
    this.onUnfocus,
    this.onFieldSubmitted,
    this.trimOnUnfocus = false,
    this.labelText,
    this.hintText,
    this.canSetToInitial = false,
  });

  final AdvancedTextFieldController<E> field;
  final ErrorTranslator<E> translateError;
  final VoidCallback? onUnfocus;
  final ValueChanged<String>? onFieldSubmitted;
  final bool trimOnUnfocus;
  final String? labelText;
  final String? hintText;
  final bool canSetToInitial;

  @override
  Widget build(BuildContext context) {
    return AdvancedFieldBuilder<String, E>(
      field: field,
      builder: (context, state, _) => AppTextField(
        controller: field.textController,
        focusNode: field.focusNode,
        onUnfocus: onUnfocus,
        onFieldSubmitted: onFieldSubmitted,
        trimOnUnfocus: trimOnUnfocus,
        labelText: labelText,
        hintText: hintText,
        errorText: state.error != null ? translateError(state.error!) : null,
        suffix: state.isValidating
            ? const SizedBox.square(
                dimension: 16,
                child: CircularProgressIndicator(),
              )
            : null,
        onSetToInitial: canSetToInitial ? field.reset : null,
      ),
    );
  }
}
