import 'package:flutter/material.dart';
import 'package:leancode_forms/leancode_forms.dart';

/// This is an example of custom text field created for an app.
/// It's created in order to show how to use [FieldBuilder] with custom fields.
class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    this.controller,
    this.initialValue,
    this.onChanged,
    this.labelText,
    this.hintText,
    this.errorText,
  });

  final TextEditingController? controller;
  final String? initialValue;
  final ValueChanged<String>? onChanged;
  final String? labelText;
  final String? hintText;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      initialValue: initialValue,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: labelText,
        hintText: hintText,
        errorText: errorText,
      ),
    );
  }
}
