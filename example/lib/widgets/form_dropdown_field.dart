import 'package:leancode_forms/leancode_forms.dart';
import 'package:leancode_forms_example/widgets/app_dropdown_field.dart';

class FormDropdownField<T, E extends Object> extends FieldBuilder<T?, E> {
  FormDropdownField({
    super.key,
    required SingleSelectFieldCubit<T, E> super.field,
    required String Function(T) labelBuilder,
    required ErrorTranslator<E> translateError,
    String? labelText,
    String? hintText,
    bool canSetToInitial = false,
  }) : super(
          builder: (context, state) => AppDropdownField(
            value: state.value,
            options: field.options,
            onChanged: field.select,
            labelBuilder: labelBuilder,
            label: labelText,
            hint: hintText,
            errorText:
                state.error != null ? translateError(state.error!) : null,
            onSetToInitial: canSetToInitial ? field.clear : null,
            onEmpty: () => field.select(null),
          ),
        );
}
