import 'package:flutter/material.dart';
import 'package:leancode_forms/leancode_forms.dart';
import 'package:leancode_forms_example/main.dart';
import 'package:leancode_forms_example/screens/form_page.dart';
import 'package:leancode_forms_example/widgets/form_text_field.dart';
import 'package:leancode_forms_example/widgets/screen_description.dart';
import 'package:provider/provider.dart';

/// This is an example of [ValidationMode]. The picker sets the mode on the
/// whole form; the last field opted out of the broadcast with its own
/// [AdvancedFieldController.setValidationMode] and keeps `onUnfocus` forever.
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
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          ScreenDescription([
            bold('Validation modes. '),
            plain('The picker broadcasts a '),
            code('ValidationMode'),
            plain(' to the form. Every field needs at least 5 characters. A '
                'field the user never edited stays quiet in every mode, and '),
            code('validate()'),
            plain(' on submit ignores the mode. The last field called '),
            code('setValidationMode'),
            plain(' on itself, so it stays on '),
            code('onUnfocus'),
            plain(' whatever the picker says.'),
          ]),
          SegmentedButton<ValidationMode>(
            segments: const [
              ButtonSegment(
                value: ValidationMode.disabled,
                label: Text('disabled'),
              ),
              ButtonSegment(
                value: ValidationMode.onUserInteraction,
                label: Text('interaction'),
              ),
              ButtonSegment(
                value: ValidationMode.onUnfocus,
                label: Text('unfocus'),
              ),
            ],
            selected: {controller.value.validationMode},
            onSelectionChanged: (selection) =>
                controller.setValidationMode(selection.single),
          ),
          const SizedBox(height: 16),
          FormTextField(
            field: controller.first,
            translateError: validatorTranslator,
            labelText: 'Follows the form',
          ),
          const SizedBox(height: 16),
          FormTextField(
            field: controller.second,
            translateError: validatorTranslator,
            labelText: 'Follows the form too',
          ),
          const SizedBox(height: 16),
          FormTextField(
            field: controller.pinned,
            translateError: validatorTranslator,
            labelText: 'Pinned to onUnfocus',
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () async {
              final isValid = await controller.validate();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content:
                        Text(isValid ? 'Form is valid' : 'Form is invalid'),
                  ),
                );
              }
            },
            child: const Text('Submit'),
          ),
        ],
      ),
    );
  }
}

class ValidationModesFormController extends AdvancedFormController {
  ValidationModesFormController() {
    registerFields([first, second, pinned]);
  }

  final first = AdvancedTextFieldController(
    validator: atLeastLength(5, ValidationError.toShort),
  );

  final second = AdvancedTextFieldController(
    validator: atLeastLength(5, ValidationError.toShort),
  );

  // A per-field opt-out: from here on this field manages its own mode, and the
  // form's broadcast leaves it alone.
  final pinned = AdvancedTextFieldController<ValidationError>(
    validator: atLeastLength(5, ValidationError.toShort),
  )..setValidationMode(ValidationMode.onUnfocus);
}
