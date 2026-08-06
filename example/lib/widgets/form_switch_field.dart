import 'package:flutter/material.dart';
import 'package:leancode_forms/leancode_forms.dart';

class FormSwitchField<E extends Object> extends StatelessWidget {
  const FormSwitchField({
    super.key,
    required this.field,
    this.labelText,
  });

  final AdvancedBooleanFieldController<E> field;
  final String? labelText;

  @override
  Widget build(BuildContext context) {
    return AdvancedFieldBuilder<bool, E>(
      field: field,
      builder: (context, state, _) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (labelText != null) Flexible(child: Text(labelText!)),
          Switch(
            value: state.value,
            onChanged: field.getValueSetter(),
          ),
        ],
      ),
    );
  }
}
