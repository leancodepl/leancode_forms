import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:leancode_forms/leancode_forms.dart';

/// This is an example of custom text field created for an app.
/// It's created in order to show how to use [FieldBuilder] with custom fields.
class AppTextField extends HookWidget {
  const AppTextField({
    super.key,
    this.controller,
    this.initialValue,
    this.onChanged,
    this.onUnfocus,
    this.labelText,
    this.hintText,
    this.errorText,
  });

  final TextEditingController? controller;
  final String? initialValue;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onUnfocus;
  final String? labelText;
  final String? hintText;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    final focusNode = useFocusNode();

    useEffect(
      () {
        void listener() {
          if (!focusNode.hasFocus) {
            onUnfocus?.call();
          }
        }

        focusNode.addListener(listener);
        return () => focusNode.removeListener(listener);
      },
      [],
    );

    return TextFormField(
      focusNode: focusNode,
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
