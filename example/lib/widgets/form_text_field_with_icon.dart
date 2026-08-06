import 'package:flutter/material.dart';
import 'package:leancode_forms/leancode_forms.dart';

/// A form text field with a leading icon. Demonstrates
/// [AdvancedFieldBuilder]'s `child:` optimization — the [icon] widget is built
/// once when this widget is mounted, and reused on every subsequent rebuild
/// instead of being constructed fresh on every keystroke.
///
/// Reach for `child:` only when part of the subtree (here, the leading icon)
/// is genuinely expensive AND doesn't depend on the field state. Otherwise a
/// plain [AdvancedFieldBuilder] without it is shorter and equally correct.
class FormTextFieldWithIcon<E extends Object> extends StatelessWidget {
  const FormTextFieldWithIcon({
    super.key,
    required this.field,
    required this.translateError,
    required this.icon,
    this.labelText,
    this.hintText,
  });

  final AdvancedTextFieldController<E> field;
  final ErrorTranslator<E> translateError;

  /// Built once and reused on every rebuild via [AdvancedFieldBuilder]'s
  /// `child:` parameter.
  final Widget icon;

  final String? labelText;
  final String? hintText;

  @override
  Widget build(BuildContext context) {
    return AdvancedFieldBuilder<String, E>(
      field: field,
      child: icon, // <-- built once, reused on every rebuild
      builder: (context, state, child) => Row(
        children: [
          child!, // <-- the same `icon` instance every rebuild
          const SizedBox(width: 8),
          Expanded(
            child: TextFormField(
              controller: field.textController,
              decoration: InputDecoration(
                labelText: labelText,
                hintText: hintText,
                errorText:
                    state.error != null ? translateError(state.error!) : null,
                suffix: state.isValidating
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(),
                      )
                    : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
