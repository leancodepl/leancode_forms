import 'package:flutter/material.dart';
import 'package:leancode_forms/leancode_forms.dart';
import 'package:leancode_forms_example/main.dart';
import 'package:leancode_forms_example/screens/form_page.dart';
import 'package:leancode_forms_example/widgets/form_text_field.dart';
import 'package:leancode_forms_example/widgets/screen_description.dart';
import 'package:provider/provider.dart';

/// Demonstrates the three [ValidationMode]s on one form, and one field that
/// manages its own mode whatever the form is set to.
class ValidationModesFormScreen extends StatelessWidget {
  const ValidationModesFormScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<ValidationModesFormController>(
      create: (context) => ValidationModesFormController(),
      child: const ValidationModesForm(),
    );
  }
}

class ValidationModesForm extends StatelessWidget {
  const ValidationModesForm({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ValidationModesFormController>();
    return FormPage(
      title: 'Validation Modes',
      child: SingleChildScrollView(
        child: Column(
          children: [
            ScreenDescription([
              plain('The mode is one value on the form. Switch it below and '
                  'type in the fields to feel the difference. '),
              code('disabled'),
              plain(' waits for Submit, '),
              code('onUserInteraction'),
              plain(' validates every keystroke, and '),
              code('onUnfocus'),
              plain(' validates when you leave a field you edited. In every '
                  'mode a field you never touched stays quiet — press Submit '
                  'to check those.'),
            ]),
            SegmentedButton<ValidationMode>(
              segments: const [
                ButtonSegment(
                  value: ValidationMode.disabled,
                  label: Text('disabled'),
                ),
                ButtonSegment(
                  value: ValidationMode.onUserInteraction,
                  label: Text('typing'),
                ),
                ButtonSegment(
                  value: ValidationMode.onUnfocus,
                  label: Text('unfocus'),
                ),
              ],
              selected: {controller.value.validationMode},
              onSelectionChanged: (selection) =>
                  controller.setValidationMode(selection.first),
            ),
            const SizedBox(height: 16),
            FormTextField(
              field: controller.firstName,
              translateError: validatorTranslator,
              labelText: 'First Name',
              hintText: 'Follows the form',
            ),
            FormTextField(
              field: controller.lastName,
              translateError: validatorTranslator,
              labelText: 'Last Name',
              hintText: 'Follows the form',
            ),
            FormTextField(
              field: controller.nickname,
              translateError: validatorTranslator,
              labelText: 'Nickname',
              hintText: 'Always validates on unfocus',
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

class ValidationModesFormController extends AdvancedFormController {
  ValidationModesFormController() {
    registerFields([firstName, lastName, nickname]);
  }

  final firstName = AdvancedTextFieldController(
    validator: filled(ValidationError.empty),
  );

  final lastName = AdvancedTextFieldController(
    validator: filled(ValidationError.empty),
  );

  /// Claims its own mode, so the form's mode never replaces it. The widget
  /// binds `field.focusNode`, which is what makes the mode work.
  final nickname = AdvancedTextFieldController(
    validator: atLeastLength(3, ValidationError.toShort),
  )..setValidationMode(ValidationMode.onUnfocus);

  Future<void> submit() async {
    // Submit ignores the mode and checks everything, including the fields
    // nobody has touched.
    debugPrint(await validate() ? 'Form is valid' : 'Form is invalid');
  }
}
