import 'package:flutter/material.dart';
import 'package:leancode_forms/leancode_forms.dart';
import 'package:leancode_forms_example/main.dart';
import 'package:leancode_forms_example/screens/form_page.dart';
import 'package:leancode_forms_example/widgets/form_text_field_avatar_card.dart';
import 'package:leancode_forms_example/widgets/form_text_field_with_banner.dart';
import 'package:leancode_forms_example/widgets/form_text_field_with_icon.dart';
import 'package:leancode_forms_example/widgets/screen_description.dart';
import 'package:provider/provider.dart';

/// Demonstrates `ValueListenableBuilder`'s `child:` optimization across
/// three layouts of increasing visual weight: a small leading icon, a
/// profile-card with avatar, and a large decorative banner.
///
/// In each case the "static" piece never depends on field state, so it's
/// built once and reused via the `child:` parameter — instead of being
/// reconstructed on every keystroke or async-validation tick.
class OptimizedRenderingFormScreen extends StatelessWidget {
  const OptimizedRenderingFormScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<OptimizedRenderingFormController>(
      create: (_) => OptimizedRenderingFormController(),
      child: const _OptimizedRenderingForm(),
    );
  }
}

class _OptimizedRenderingForm extends StatelessWidget {
  const _OptimizedRenderingForm();

  @override
  Widget build(BuildContext context) {
    final controller = context.select<OptimizedRenderingFormController,
        OptimizedRenderingFormController>((c) => c);
    return FormPage(
      title: 'Optimized Rendering',
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          ScreenDescription([
            bold('Optimized rebuilds. '),
            plain('Demonstrates '),
            code('ValueListenableBuilder.child'),
            plain(' across three layouts of increasing visual weight — '),
            bold('leading icon'),
            plain(', '),
            bold('avatar card'),
            plain(', and '),
            bold('banner header'),
            plain('. Each keeps a '),
            bold('static subtree'),
            plain(' that never depends on field state out of the rebuild '
                'cycle. The email field has '),
            bold('async validation'),
            plain(', so its text field rebuilds often — but the banner '
                'above it does not.'),
          ]),
          FormTextFieldWithIcon(
            field: controller.firstName,
            translateError: validatorTranslator,
            icon: const _FancyLeadingIcon(
              icon: Icons.person,
              color: Color(0xFF7C4DFF),
            ),
            labelText: 'First Name',
            hintText: 'Enter your first name',
          ),
          const SizedBox(height: 16),
          FormTextFieldAvatarCard(
            field: controller.nickname,
            translateError: validatorTranslator,
            avatarCaption: 'Profile',
            avatarIcon: Icons.face_retouching_natural,
            avatarColor: const Color(0xFFFF7043),
            labelText: 'Nickname',
            hintText: 'Pick a display name',
          ),
          const SizedBox(height: 8),
          FormTextFieldWithBanner(
            field: controller.email,
            translateError: validatorTranslator,
            banner: const _FancyBanner(
              title: 'Stay in touch',
              subtitle: 'We only email about important account updates.',
              colors: [Color(0xFF00BFA5), Color(0xFF1DE9B6)],
              icon: Icons.mail_outline,
            ),
            labelText: 'Email',
            hintText: 'Enter your email',
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: controller.submit,
            child: const Text('Submit'),
          ),
        ],
      ),
    );
  }
}

/// A visually heavy leading icon: gradient background, drop shadow, padding,
/// and a tinted icon on top. The kind of thing you'd want to build once and
/// reuse — exactly what the `child:` parameter is for.
class _FancyLeadingIcon extends StatelessWidget {
  const _FancyLeadingIcon({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color, color.withValues(alpha: 0.7)],
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.4),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Icon(icon, color: Colors.white, size: 26),
    );
  }
}

/// A decorative banner header: gradient fill, a couple of soft circles, and
/// a title + subtitle layered on top. Stands in for the kind of marketing
/// hero / image header a real form might have — and the kind of thing you
/// definitely don't want to rebuild on every keystroke.
class _FancyBanner extends StatelessWidget {
  const _FancyBanner({
    required this.title,
    required this.subtitle,
    required this.colors,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final List<Color> colors;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 120,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -24,
            right: -24,
            child: Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.18),
              ),
            ),
          ),
          Positioned(
            bottom: -16,
            left: 40,
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.12),
              ),
            ),
          ),
          Positioned(
            top: 16,
            right: 16,
            child: Icon(icon, color: Colors.white, size: 28),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class OptimizedRenderingFormController extends FormGroupController {
  OptimizedRenderingFormController() {
    registerFields([firstName, nickname, email]);
  }

  final firstName = TextFieldController(
    validator: filled(ValidationError.empty),
  );

  final nickname = TextFieldController(
    validator: filled(ValidationError.empty),
  );

  late final email = TextFieldController(
    validator: filled(ValidationError.empty),
    asyncValidator: _onEmailChanged,
    asyncValidationDebounce: const Duration(milliseconds: 500),
  );

  Future<ValidationError?> _onEmailChanged(String value) async {
    final takenEmail = ['john@email.com', 'jack@email.com'];
    await Future<void>.delayed(const Duration(milliseconds: 700));
    return takenEmail.contains(value) ? ValidationError.emailTaken : null;
  }

  void submit() {
    if (validate()) {
      debugPrint('First name: ${firstName.value.value}');
      debugPrint('Nickname: ${nickname.value.value}');
      debugPrint('Email: ${email.value.value}');
    } else {
      debugPrint('Form is invalid');
    }
  }
}
