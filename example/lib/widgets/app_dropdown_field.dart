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
    this.errorText,
    this.onSetToInitial,
    this.onEmpty,
  });

  final List<T> options;
  final T? value;
  final String Function(T) labelBuilder;
  final ValueChanged<T?> onChanged;
  final String? label;
  final String? hint;
  final String? errorText;
  final VoidCallback? onSetToInitial;
  final VoidCallback? onEmpty;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Flexible(
          child: InputDecorator(
            decoration: InputDecoration(
              labelText: label,
              errorText: errorText,
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<T>(
                value: value,
                isExpanded: true,
                hint: switch (hint) {
                  final hint? => Text(hint),
                  null => null,
                },
                onChanged: onChanged,
                items: [
                  for (final option in options)
                    DropdownMenuItem(
                      value: option,
                      child: Text(labelBuilder(option)),
                    ),
                ],
              ),
            ),
          ),
        ),
        if (onEmpty case final onEmpty?) ...[
          const SizedBox(width: 16),
          ElevatedButton(
            onPressed: onEmpty,
            child: const Text('Empty'),
          ),
        ],
        if (onSetToInitial case final onSetToInitial?) ...[
          const SizedBox(width: 16),
          ElevatedButton(
            onPressed: onSetToInitial,
            child: const Text('Set to initial'),
          ),
        ],
      ],
    );
  }
}
