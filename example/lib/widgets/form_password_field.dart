import 'package:flutter/material.dart';
import 'package:leancode_forms/leancode_forms.dart';
import 'package:leancode_forms_example/controllers/password_field_controller.dart';
import 'package:leancode_forms_example/main.dart';
import 'package:leancode_forms_example/widgets/app_text_field.dart';

class FormPasswordField extends StatelessWidget {
  const FormPasswordField({
    super.key,
    required this.field,
    required this.translateError,
    this.labelText,
    this.hintText,
  });

  final PasswordFieldController field;
  final ErrorTranslator<List<ValidationError>> translateError;
  final String? labelText;
  final String? hintText;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<FieldState<String, List<ValidationError>>>(
      valueListenable: field,
      builder: (context, state, _) => AppTextField(
        controller: field.textController,
        labelText: labelText,
        hintText: hintText,
        errorText: (state.error?.isNotEmpty ?? false)
            ? translateError(state.error!)
            : null,
      ),
    );
  }
}
