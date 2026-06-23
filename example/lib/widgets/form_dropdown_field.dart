import 'package:flutter/material.dart';
import 'package:leancode_forms/leancode_forms.dart';
import 'package:leancode_forms_example/widgets/app_dropdown_field.dart';

class FormDropdownField<T, E extends Object> extends StatelessWidget {
  const FormDropdownField({
    super.key,
    required this.field,
    required this.labelBuilder,
    required this.translateError,
    this.labelText,
    this.hintText,
    this.canSetToInitial = false,
  });

  final AdvancedSingleSelectFieldController<T, E> field;
  final String Function(T) labelBuilder;
  final ErrorTranslator<E> translateError;
  final String? labelText;
  final String? hintText;
  final bool canSetToInitial;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AdvancedFieldState<T?, E>>(
      valueListenable: field,
      builder: (context, state, _) => AppDropdownField<T>(
        value: state.value,
        options: field.options,
        onChanged: field.select,
        labelBuilder: labelBuilder,
        label: labelText,
        hint: hintText,
        errorText: state.error != null ? translateError(state.error!) : null,
        onSetToInitial: canSetToInitial ? field.clear : null,
        onEmpty: () => field.select(null),
      ),
    );
  }
}
