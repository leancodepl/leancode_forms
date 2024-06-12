import 'package:flutter/material.dart';
import 'package:leancode_forms/leancode_forms.dart';
import 'package:leancode_forms_example/cubits/focusable_text_field_cubit.dart';
import 'package:leancode_forms_example/widgets/app_text_field.dart';

class FormTextField<E extends Object> extends FieldBuilder<String, E> {
  FormTextField({
    super.key,
    required TextFieldCubit<E> super.field,
    required ErrorTranslator<E> translateError,
    TextEditingController? controller,
    VoidCallback? onUnfocus,
    ValueChanged<String>? onFieldSubmitted,
    bool? trimOnUnfocus,
    String? labelText,
    String? hintText,
    bool canSetToInitial = false,
  }) : super(
          builder: (context, state) => AppTextField(
            key: key,
            onChanged: field.getValueSetter(),
            onUnfocus: onUnfocus,
            onFieldSubmitted: onFieldSubmitted,
            setValue: field.setValue,
            trimOnUnfocus: trimOnUnfocus ?? false,
            errorText:
                state.error != null ? translateError(state.error!) : null,
            initialValue: state.value,
            controller: controller,
            labelText: labelText,
            hintText: hintText,
            suffix: state.isValidating
                ? const SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(),
                  )
                : null,
            onSetToInitial: canSetToInitial
                ? () {
                    field.clear();
                    return field.state.value;
                  }
                : null,
          ),
        );
}

class FocusableFormTextField<E extends Object> extends FieldBuilder<String, E> {
  FocusableFormTextField({
    super.key,
    required FocusableTextFieldCubit<E> super.field,
    required ErrorTranslator<E> translateError,
    TextEditingController? controller,
    VoidCallback? onUnfocus,
    ValueChanged<String>? onFieldSubmitted,
    bool? trimOnUnfocus,
    String? labelText,
    String? hintText,
  }) : super(
          builder: (context, state) => AppTextField(
            key: key,
            onChanged: field.getValueSetter(),
            onUnfocus: onUnfocus,
            onFieldSubmitted: onFieldSubmitted,
            setValue: field.setValue,
            trimOnUnfocus: trimOnUnfocus ?? false,
            errorText:
                state.error != null ? translateError(state.error!) : null,
            initialValue: state.value,
            controller: controller,
            focusNode: field.focusNode,
            labelText: labelText,
            hintText: hintText,
            suffix: state.isValidating
                ? const SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(),
                  )
                : null,
          ),
        );
}
