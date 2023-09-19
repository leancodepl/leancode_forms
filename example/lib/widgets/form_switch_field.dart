import 'package:flutter/material.dart';
import 'package:leancode_forms/leancode_forms.dart';

class FormSwitchField<E extends Object> extends FieldBuilder<bool, E> {
  FormSwitchField({
    super.key,
    required super.field,
    String? labelText,
  }) : super(
          builder: (context, state) => Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (labelText != null) Flexible(child: Text(labelText)),
              Switch(
                value: state.value,
                onChanged: field.getValueSetter(),
              ),
            ],
          ),
        );
}
