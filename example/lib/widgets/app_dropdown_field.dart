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
          // `DropdownButton` in an `InputDecorator`, not
          // `DropdownButtonFormField`: the selected value is rendered from
          // [value], so the field controller stays the single source of truth
          // and a rebuild cannot lose the selection. (It also compiles on every
          // Flutter version — the form-field variant renamed `value:` to
          // `initialValue:` in 3.35.)
          child: InputDecorator(
            decoration: InputDecoration(
              labelText: label,
              errorText: errorText,
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<T>(
                value: value,
                isExpanded: true,
                hint: hint == null ? null : Text(hint!),
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
