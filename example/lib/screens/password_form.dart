import 'package:flutter/material.dart';
import 'package:leancode_forms/leancode_forms.dart';
import 'package:leancode_forms_example/controllers/password_field_controller.dart';
import 'package:leancode_forms_example/main.dart';
import 'package:leancode_forms_example/screens/form_page.dart';
import 'package:leancode_forms_example/widgets/form_password_field.dart';
import 'package:leancode_forms_example/widgets/form_switch_field.dart';
import 'package:leancode_forms_example/widgets/form_text_field.dart';
import 'package:leancode_forms_example/widgets/screen_description.dart';
import 'package:provider/provider.dart';

/// This is an example of a form with a password/repeat password fields.
/// In this form repeatPassword field is validated according to value in the password field.
class PasswordFormScreen extends StatelessWidget {
  const PasswordFormScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<PasswordFormController>(
      create: (_) => PasswordFormController(),
      child: const PasswordForm(),
    );
  }
}

class PasswordForm extends StatelessWidget {
  const PasswordForm({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<PasswordFormController>();
    return FormPage(
      title: 'Password Form',
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          ScreenDescription([
            bold('Cross-field validation. '),
            plain('The "Repeat Password" field listens to the password '
                'field via '),
            code('subscribeToFields'),
            plain(' and re-validates whenever the password changes. The '
                'username field demonstrates '),
            bold('autovalidation'),
            plain(': it only starts showing errors after losing focus '
                'for the first time.'),
          ]),
          FormTextField(
            field: controller.username,
            onUnfocus: () => controller.username
              ..setAutovalidate(true)
              ..validate(),
            translateError: validatorTranslator,
            labelText: 'Username',
            hintText: 'Enter your username',
          ),
          const SizedBox(height: 16),
          FormSwitchField(
            field: controller.switchField,
            labelText: 'Repeat password should be 10 characters long',
          ),
          const SizedBox(height: 16),
          FormPasswordField(
            field: controller.password,
            translateError: (error) => validatorTranslator(error.first),
            labelText: 'Password',
            hintText: 'Enter your password',
          ),
          const SizedBox(height: 16),
          FormTextField(
            field: controller.repeatPassword,
            translateError: validatorTranslator,
            labelText: 'Repeat Password',
            hintText: 'Repeat your password',
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: controller.submit,
            child: const Text('Submit'),
          ),
        ],
      ),
    );
  }
}

Validator<String, E> passwordMatch<E extends Object>(
  PasswordFieldController passwordController,
  E message,
) =>
    (value) {
      if (value != passwordController.value.value) {
        return message;
      }
      return null;
    };

class PasswordFormController extends AdvancedFormController {
  PasswordFormController() {
    registerFields([
      username,
      switchField,
      password,
      repeatPassword,
    ]);
  }

  final username = AdvancedTextFieldController(
    validator: filled(ValidationError.empty) &
        atLeastLength(5, ValidationError.toShort),
  );

  final switchField = AdvancedBooleanFieldController();

  final password = PasswordFieldController(
    numberRequired: true,
    specialCharRequired: true,
    upperCaseRequired: true,
    lowerCaseRequired: true,
  );

  // `subscribeToFields` + `autovalidate: true`:
  // We expect: no validation fires until one of the subscribed fields' value
  // actually changes (state-only changes, like status updates, are ignored).
  late final repeatPassword = AdvancedTextFieldController<ValidationError>(
    validator: passwordMatch(password, ValidationError.doesNotMatch),
  )
    ..setAutovalidate(true)
    ..subscribeToFields([switchField, password]);

  void submit() {
    if (validate()) {
      debugPrint('Username: ${username.value.value}');
      debugPrint('Switch field: ${switchField.value.value}');
      debugPrint('Password: ${password.value.value}');
      debugPrint('Repeated password: ${repeatPassword.value.value}');
    } else {
      debugPrint('Form is invalid');
      debugPrint('Username: ${username.value.value}');
      debugPrint('Switch field: ${switchField.value.value}');
      debugPrint('Password: ${password.value.value}');
      debugPrint('Repeated password: ${repeatPassword.value.value}');
    }
  }
}
