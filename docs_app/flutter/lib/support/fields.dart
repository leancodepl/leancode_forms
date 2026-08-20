/*
 * AI-Provenance:
 *   model: Claude Opus 5
 *   harness: Cursor
 */
import 'package:advanced_forms/advanced_forms.dart';
import 'package:flutter/material.dart';

/// Compact field widgets for docs examples whose lesson is not widget wiring.
///
/// An example about validation should not have to re-teach
/// [AdvancedFieldBuilder] before it gets to the point. Examples that *are*
/// about binding widgets to fields should define their own field widget in the
/// snippet instead — that is what a reader has to write, so that is what the
/// page should show.
class DocsTextField<E extends Object> extends StatelessWidget {
  const DocsTextField({
    super.key,
    required this.field,
    required this.label,
    this.translateError,
    this.obscureText = false,
    this.keyboardType,
  });

  final AdvancedTextFieldController<E> field;
  final String label;

  /// Maps the field's error to a message. Defaults to `toString()`, which is
  /// right for the common case of `AdvancedTextFieldController<String>`.
  final ErrorTranslator<E>? translateError;

  final bool obscureText;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return AdvancedFieldBuilder<String, E>(
      field: field,
      builder: (context, state, _) {
        final error = state.error;

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: TextFormField(
            controller: field.textController,
            focusNode: field.focusNode,
            obscureText: obscureText,
            keyboardType: keyboardType,
            readOnly: state.readOnly,
            decoration: InputDecoration(
              labelText: label,
              isDense: true,
              border: const OutlineInputBorder(),
              errorText: error == null
                  ? null
                  : translateError?.call(error) ?? error.toString(),
              suffixIcon: state.isInProgress
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : null,
            ),
          ),
        );
      },
    );
  }
}

/// A switch bound to an [AdvancedBooleanFieldController].
class DocsSwitchField<E extends Object> extends StatelessWidget {
  const DocsSwitchField({
    super.key,
    required this.field,
    required this.label,
    this.translateError,
  });

  final AdvancedBooleanFieldController<E> field;
  final String label;
  final ErrorTranslator<E>? translateError;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AdvancedFieldBuilder<bool, E>(
      field: field,
      builder: (context, state, _) {
        final error = state.error;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SwitchListTile(
              value: state.value,
              onChanged: state.readOnly ? null : field.setValue,
              title: Text(label),
              dense: true,
              contentPadding: EdgeInsets.zero,
            ),
            if (error != null)
              Text(
                translateError?.call(error) ?? error.toString(),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
          ],
        );
      },
    );
  }
}

/// A dropdown bound to an [AdvancedSingleSelectFieldController].
class DocsDropdownField<V, E extends Object> extends StatelessWidget {
  const DocsDropdownField({
    super.key,
    required this.field,
    required this.label,
    this.optionLabel,
    this.translateError,
  });

  final AdvancedSingleSelectFieldController<V, E> field;
  final String label;
  final String Function(V option)? optionLabel;
  final ErrorTranslator<E>? translateError;

  @override
  Widget build(BuildContext context) {
    return AdvancedFieldBuilder<V?, E>(
      field: field,
      builder: (context, state, _) {
        final error = state.error;

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: DropdownButtonFormField<V>(
            initialValue: state.value,
            focusNode: field.focusNode,
            decoration: InputDecoration(
              labelText: label,
              isDense: true,
              border: const OutlineInputBorder(),
              errorText: error == null
                  ? null
                  : translateError?.call(error) ?? error.toString(),
            ),
            items: [
              for (final option in field.options)
                DropdownMenuItem(
                  value: option,
                  child: Text(optionLabel?.call(option) ?? '$option'),
                ),
            ],
            onChanged: state.readOnly ? null : field.select,
          ),
        );
      },
    );
  }
}
