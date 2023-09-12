import 'package:flutter/material.dart';

class AppDropdownField<T> extends StatelessWidget {
  const AppDropdownField({
    super.key,
    required this.options,
    this.value,
    required this.labelBuilder,
    required this.onChanged,
    this.label,
    this.hint,
    this.onClear,
    this.errorText,
  });

  final List<T> options;
  final T? value;
  final String Function(T) labelBuilder;
  final ValueChanged<T?> onChanged;
  final String? label;
  final String? hint;
  final VoidCallback? onClear;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Flexible(
          child: DropdownButtonFormField<T>(
            value: value,
            onChanged: onChanged,
            items: options
                .map(
                  (e) => DropdownMenuItem(
                    value: e,
                    child: Text(labelBuilder(e)),
                  ),
                )
                .toList(),
            decoration: InputDecoration(
              labelText: label,
              hintText: hint,
              errorText: errorText,
            ),
          ),
        ),
        ElevatedButton(
          onPressed: onClear,
          child: const Text('Clear choice'),
        ),
      ],
    );
  }
}
