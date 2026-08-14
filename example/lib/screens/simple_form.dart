import 'package:flutter/material.dart';
import 'package:leancode_forms/leancode_forms.dart';
import 'package:leancode_forms_example/main.dart';
import 'package:leancode_forms_example/screens/form_page.dart';
import 'package:leancode_forms_example/widgets/form_text_field.dart';
import 'package:leancode_forms_example/widgets/screen_description.dart';
import 'package:provider/provider.dart';

/// This is an example of a simple form with two basic fields and one field with async validation.
/// The form keeps the default [ValidationMode.disabled], so it is validated
/// ONLY when the submit button is pressed.
class SimpleFormScreen extends StatelessWidget {
  const SimpleFormScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<SimpleFormController>(
      create: (context) => SimpleFormController(),
      child: const SimpleForm(),
    );
  }
}

class SimpleForm extends StatelessWidget {
  const SimpleForm({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<SimpleFormController>();
    return FormPage(
      title: 'Simple Form',
      child: SingleChildScrollView(
        child: Column(
          children: [
            ScreenDescription([
              plain('A basic form with two text fields and one with '),
              bold('async validation'),
              plain(' (email). Validation only runs on '),
              bold('submit'),
              plain(', which '),
              code('await'),
              plain('s the async check — type anything and press Submit to '
                  'see errors appear. Try '),
              code('john@email.com'),
              plain(' or '),
              code('jack@email.com'),
              plain(' to trigger the async "email taken" error, or '),
              code('boom@email.com'),
              plain(' to make the check throw: the form then reports '),
              code('hasFailedValidation'),
              plain(' and '),
              code('failureToError'),
              plain(' turns the exception into something readable.'),
            ]),
            if (controller.value.hasFailedValidation)
              const _CheckFailedBanner(),
            FormTextField(
              field: controller.firstName,
              translateError: validatorTranslator,
              labelText: 'First Name',
              hintText: 'Enter your first name',
              canSetToInitial: true,
            ),
            FormTextField(
              field: controller.lastName,
              translateError: validatorTranslator,
              labelText: 'Last Name',
              hintText: 'Enter your last name',
              canSetToInitial: true,
            ),
            FormTextField(
              field: controller.email,
              translateError: validatorTranslator,
              labelText: 'Email',
              hintText: 'Enter your email',
            ),
            ElevatedButton(
              // `canSubmit` is what a submit button binds to: it is false while
              // any check is in flight and while any error is known, and true on
              // a fresh form nobody has validated yet. `submit` still awaits
              // `validate()` — this only greys out what is already known to fail.
              onPressed: controller.value.canSubmit ? controller.submit : null,
              child: const Text('Submit'),
            ),
          ],
        ),
      ),
    );
  }
}

/// One banner for the whole form, driven by
/// [AdvancedFormState.hasFailedValidation]. Not sticky — the next submit
/// retries every failed round.
class _CheckFailedBanner extends StatelessWidget {
  const _CheckFailedBanner();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(12),
      color: theme.colorScheme.errorContainer,
      child: Text(
        'Some checks could not be completed. Press Submit to try again.',
        style: TextStyle(color: theme.colorScheme.onErrorContainer),
      ),
    );
  }
}

class SimpleFormController extends AdvancedFormController {
  SimpleFormController() {
    registerFields([
      firstName,
      lastName,
      email,
    ]);
  }

  final firstName = AdvancedTextFieldController(
    initialValue: 'John',
    validator: filled(ValidationError.empty),
  );

  final lastName = AdvancedTextFieldController(
    initialValue: 'Foo',
    validator: filled(ValidationError.empty),
  );

  late final email = AdvancedTextFieldController(
    validator: filled(ValidationError.empty),
    asyncValidation: AsyncValidation(
      validator: _checkEmail,
      debounce: const Duration(milliseconds: 500),
      timeout: const Duration(seconds: 5),
      // Opt in to showing something when the check itself falls over. Without
      // it the field carries no code and only the form-level banner speaks.
      failureToError: (error, stackTrace) =>
          ValidationError.emailCheckUnavailable,
    ),
  );

  Future<ValidationError?> _checkEmail(String value) async {
    final takenEmail = ['john@email.com', 'jack@email.com'];
    await Future<void>.delayed(const Duration(milliseconds: 700));
    if (value == 'boom@email.com') {
      throw Exception('the email service is down');
    }
    return takenEmail.contains(value) ? ValidationError.emailTaken : null;
  }

  Future<void> submit() async {
    // `await` is what makes this a guarantee: it runs the async validators too.
    if (await validate()) {
      debugPrint('First name: ${firstName.value.value}');
      debugPrint('Last name: ${lastName.value.value}');
      debugPrint('Email: ${email.value.value}');
    } else {
      debugPrint('Form is invalid');
    }
  }
}
