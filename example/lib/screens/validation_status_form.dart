import 'package:flutter/material.dart';
import 'package:leancode_forms/leancode_forms.dart';
import 'package:leancode_forms_example/main.dart';
import 'package:leancode_forms_example/screens/form_page.dart';
import 'package:leancode_forms_example/widgets/form_text_field.dart';
import 'package:leancode_forms_example/widgets/screen_description.dart';
import 'package:provider/provider.dart';

/// Demonstrates [AdvancedValidationStatusBuilder]: the Submit button is
/// enabled only while every field reports `isValid == true`.
///
/// Each field is autovalidating from creation so the user gets immediate
/// feedback, and the button's enabled state reflects validity live.
class ValidationStatusFormScreen extends StatelessWidget {
  const ValidationStatusFormScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<ValidationStatusFormController>(
      create: (_) => ValidationStatusFormController(),
      child: const ValidationStatusForm(),
    );
  }
}

class ValidationStatusForm extends StatelessWidget {
  const ValidationStatusForm({super.key});

  @override
  Widget build(BuildContext context) {
    /// Here is the form controller that keeps all fields and their states
    final controller = context.select<ValidationStatusFormController,
        ValidationStatusFormController>((c) => c);
    return FormPage(
      title: 'Validation Status',
      child: SingleChildScrollView(
        child: Column(
          children: [
            ScreenDescription([
              bold('Submit button enabling/disabling is based on form validity. '),
              plain('Each field start autovalidating on unFocus. The Submit button is wrapped in '),
              code('AdvancedValidationStatusBuilder'),
              plain(', which subscribes to form validation status'),
              plain(' and rebuilds whenever any field flips between '),
              code('valid/invalid'),
              plain('. Submit button is only tappable when the whole form is valid.'),
            ]),
            FormTextField(
              field: controller.firstName,
              onUnfocus: () {
                controller.firstName..setAutovalidate(true)..validate();
              },
              translateError: validatorTranslator,
              labelText: 'First Name',
              hintText: 'At least 2 characters',
            ),
            const SizedBox(height: 16),
            FormTextField(
              onUnfocus: () {
                controller.lastName..setAutovalidate(true)..validate();
              },
              field: controller.lastName,
              translateError: validatorTranslator,
              labelText: 'Last Name',
              hintText: 'At least 2 characters',
            ),
            const SizedBox(height: 24),
            AdvancedValidationStatusBuilder(
              form: controller,
              builder: (context, isValid, _) => ElevatedButton(
                onPressed: isValid ? controller.submit : null,
                child: Text(isValid ? 'Submit' : 'Fix errors to submit'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Here the form and field controllers are defined, as well as the submit action.
class ValidationStatusFormController extends AdvancedFormController {
  ValidationStatusFormController() {
    registerFields([firstName, lastName]);
  }

  final firstName = AdvancedTextFieldController<ValidationError>(
    validator: filled(ValidationError.empty) &
        atLeastLength(2, ValidationError.toShort),
  );

  final lastName = AdvancedTextFieldController<ValidationError>(
    validator: filled(ValidationError.empty) &
        atLeastLength(2, ValidationError.toShort),
  );

  void submit() {
    if (validate()) {
      debugPrint('First name: ${firstName.value.value}');
      debugPrint('Last name: ${lastName.value.value}');
    }
  }
}
