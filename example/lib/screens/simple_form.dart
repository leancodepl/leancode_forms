import 'package:flutter/material.dart';
import 'package:leancode_forms/leancode_forms.dart';
import 'package:leancode_forms_example/main.dart';
import 'package:leancode_forms_example/screens/form_page.dart';
import 'package:leancode_forms_example/widgets/form_text_field.dart';
import 'package:leancode_forms_example/widgets/screen_description.dart';
import 'package:provider/provider.dart';

/// This is an example of a simple form with two basic fields and one field with async validation.
/// The form is validated ONLY when the submit button is pressed.
class SimpleFormScreen extends StatelessWidget {
  const SimpleFormScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<SimpleFormController>(
      create: (_) => SimpleFormController(),
      child: const SimpleForm(),
    );
  }
}

class SimpleForm extends StatelessWidget {
  const SimpleForm({super.key});

  @override
  Widget build(BuildContext context) {
    final controller =
        context.select<SimpleFormController, SimpleFormController>((c) => c);
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
              plain(' — type anything and press Submit to see errors appear. '
                  'Try '),
              code('john@email.com'),
              plain(' or '),
              code('jack@email.com'),
              plain(' to trigger the async "email taken" error.'),
            ]),
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
              onPressed: controller.submit,
              child: const Text('Submit'),
            ),
          ],
        ),
      ),
    );
  }
}

class SimpleFormController extends FormController {
  SimpleFormController() {
    registerFields([
      firstName,
      lastName,
      email,
    ]);
  }

  final firstName = TextFieldController(
    initialValue: 'John',
    validator: filled(ValidationError.empty),
  );

  final lastName = TextFieldController(
    initialValue: 'Foo',
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
    if (validate(enableAutovalidate: false)) {
      debugPrint('First name: ${firstName.value.value}');
      debugPrint('Last name: ${lastName.value.value}');
      debugPrint('Email: ${email.value.value}');
    } else {
      debugPrint('Form is invalid');
    }
  }
}
