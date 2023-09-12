import 'package:flutter/material.dart';
import 'package:leancode_forms/leancode_forms.dart';
import 'package:leancode_forms_example/cubits/password_field_cubit.dart';
import 'package:leancode_forms_example/main.dart';
import 'package:leancode_forms_example/widgets/app_text_field.dart';

class FormPasswordField extends FieldBuilder<String, List<ValidationError>> {
  FormPasswordField({
    super.key,
    required PasswordFieldCubit super.field,
    required ErrorTranslator<List<ValidationError>> translateError,
    TextEditingController? controller,
    String? labelText,
    String? hintText,
  }) : super(
          builder: (context, state) => AppTextField(
            onChanged: field.getValueSetter(),
            setValue: field.setValue,
            errorText: (state.error?.isNotEmpty ?? false)
                ? translateError(state.error!)
                : null,
            initialValue: state.value,
            controller: controller,
            labelText: labelText,
            hintText: hintText,
          ),
        );
}
