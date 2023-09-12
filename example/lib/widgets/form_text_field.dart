import 'package:flutter/material.dart';
import 'package:leancode_forms/leancode_forms.dart';
import 'package:leancode_forms_example/widgets/app_text_field.dart';

class FormTextField<E extends Object> extends FieldBuilder<String, E> {
  FormTextField({
    super.key,
    required TextFieldCubit<E> super.field,
    required ErrorTranslator<E> translateError,
    TextEditingController? controller,
    VoidCallback? onUnfocus,
    bool? trimOnUnfocus,
    String? labelText,
    String? hintText,
  }) : super(
          builder: (context, state) => AppTextField(
            onChanged: field.getValueSetter(),
            onUnfocus: onUnfocus,
            setValue: field.setValue,
            trimOnUnfocus: trimOnUnfocus ?? false,
            errorText:
                state.error != null ? translateError(state.error!) : null,
            initialValue: state.value,
            controller: controller,
            labelText: labelText,
            hintText: hintText,
          ),
        );
}
