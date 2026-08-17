import 'package:advanced_forms/advanced_forms.dart';
import 'package:flutter/material.dart';

/// A form text field with a large decorative banner header. The [banner] is
/// the static subtree — it never depends on the field's state, so it's
/// built once when this widget mounts and reused on every rebuild via
/// [AdvancedFieldBuilder]'s `child:` parameter.
///
/// The banner is intentionally the largest "static" content of the three
/// variants in this example — pairing it with an async-validated field
/// (which rebuilds on every keystroke and async-validation tick) makes
/// the optimization most visible here.
class FormTextFieldWithBanner<E extends Object> extends StatelessWidget {
  const FormTextFieldWithBanner({
    super.key,
    required this.field,
    required this.translateError,
    required this.banner,
    this.labelText,
    this.hintText,
  });

  final AdvancedTextFieldController<E> field;
  final ErrorTranslator<E> translateError;

  /// Built once when this widget is mounted and reused on every rebuild via
  /// [AdvancedFieldBuilder]'s `child:` parameter.
  final Widget banner;

  final String? labelText;
  final String? hintText;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      clipBehavior: Clip.antiAlias,
      child: AdvancedFieldBuilder<String, E>(
        field: field,
        child: banner, // <-- built once, reused on every rebuild
        builder: (context, state, child) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            child!, // <-- the same `banner` instance every rebuild
            Padding(
              padding: const EdgeInsets.all(12),
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
      ),
    );
  }
}
