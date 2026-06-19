import 'package:flutter/material.dart';
import 'package:leancode_forms/leancode_forms.dart';
import 'package:leancode_forms_example/controllers/focusable_text_field_controller.dart';
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

  final TextFieldController<E> field;
  final ErrorTranslator<E> translateError;
  final VoidCallback? onUnfocus;
  final ValueChanged<String>? onFieldSubmitted;
  final bool trimOnUnfocus;
  final String? labelText;
  final String? hintText;
  final bool canSetToInitial;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<FieldState<String, E>>(
      valueListenable: field,
      builder: (context, state, _) => AppTextField(
        controller: field.textController,
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
        onSetToInitial: canSetToInitial ? field.clear : null,
      ),
    );
  }
}

class FocusableFormTextField<E extends Object> extends StatelessWidget {
  const FocusableFormTextField({
    super.key,
    required this.field,
    required this.translateError,
    this.onUnfocus,
    this.onFieldSubmitted,
    this.trimOnUnfocus = false,
    this.labelText,
    this.hintText,
  });

  final FocusableTextFieldController<E> field;
  final ErrorTranslator<E> translateError;
  final VoidCallback? onUnfocus;
  final ValueChanged<String>? onFieldSubmitted;
  final bool trimOnUnfocus;
  final String? labelText;
  final String? hintText;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<FieldState<String, E>>(
      valueListenable: field,
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
      ),
    );
  }
}
