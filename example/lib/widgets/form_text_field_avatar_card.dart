import 'package:flutter/material.dart';
import 'package:leancode_forms/leancode_forms.dart';

/// A profile-card form field: a static [CircleAvatar] with a caption sits
/// on the left, the text field sits on the right. The whole left-hand
/// presentation block is the "static subtree" — it doesn't depend on the
/// field state, so it's built once and reused via [AdvancedFieldBuilder]'s
/// `child:` parameter.
class FormTextFieldAvatarCard<E extends Object> extends StatelessWidget {
  const FormTextFieldAvatarCard({
    super.key,
    required this.field,
    required this.translateError,
    required this.avatarCaption,
    required this.avatarIcon,
    required this.avatarColor,
    this.labelText,
    this.hintText,
  });

  final AdvancedTextFieldController<E> field;
  final ErrorTranslator<E> translateError;
  final String avatarCaption;
  final IconData avatarIcon;
  final Color avatarColor;

  final String? labelText;
  final String? hintText;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: AdvancedFieldBuilder<String, E>(
          field: field,
          child: _AvatarBlock(
            caption: avatarCaption,
            icon: avatarIcon,
            color: avatarColor,
          ), // <-- built once, reused on every rebuild
          builder: (context, state, child) => Row(
            children: [
              child!, // <-- the same `_AvatarBlock` instance every rebuild
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: field.textController,
                  decoration: InputDecoration(
                    labelText: labelText,
                    hintText: hintText,
                    errorText: state.error != null
                        ? translateError(state.error!)
                        : null,
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
      ),
    );
  }
}

class _AvatarBlock extends StatelessWidget {
  const _AvatarBlock({
    required this.caption,
    required this.icon,
    required this.color,
  });

  final String caption;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        CircleAvatar(
          radius: 28,
          backgroundColor: color,
          child: Icon(icon, color: Colors.white, size: 28),
        ),
        const SizedBox(height: 6),
        Text(
          caption,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}
