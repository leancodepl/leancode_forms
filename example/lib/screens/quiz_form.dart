import 'package:flutter/material.dart';
import 'package:leancode_forms/leancode_forms.dart';
import 'package:leancode_forms_example/main.dart';
import 'package:leancode_forms_example/screens/form_page.dart';
import 'package:leancode_forms_example/widgets/form_text_field.dart';
import 'package:leancode_forms_example/widgets/screen_description.dart';
import 'package:provider/provider.dart';

/// This is an example of a form which is asynchronously validated after pressing the submit button.
/// Errors on the fields are set/cleared manually after the validation is complete.
class QuizFormScreen extends StatelessWidget {
  const QuizFormScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<QuizController>(
      create: (_) => QuizController(),
      child: const QuizForm(),
    );
  }
}

class QuizForm extends StatelessWidget {
  const QuizForm({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<QuizController>();
    final formStatus = context.select<QuizController, ValidationStatus>(
      (c) => c.validationStatus,
    );

    return FormPage(
      title: 'Quiz Form',
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          ScreenDescription([
            bold('Manual error setting. '),
            plain('Validation happens '),
            bold('after'),
            plain(' the user presses Submit — the controller calls '),
            code('setError'),
            plain(' directly on each field once the async check returns. '
                "The status text at the bottom reflects the controller's "
                'own '),
            code('ValueNotifier'),
            plain('-backed state.'),
          ]),
          const Text('What is the longest river in the world?'),
          FormTextField(
            field: controller.formController.riverQuestion,
            trimOnUnfocus: true,
            translateError: validatorTranslator,
            hintText: 'Answer here',
          ),
          const SizedBox(height: 16),
          const Text('What is the highest mountain in the world?'),
          FormTextField(
            field: controller.formController.mountQuestion,
            trimOnUnfocus: true,
            translateError: validatorTranslator,
            hintText: 'Answer here',
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: controller.submit,
            child: const Text('Send answers'),
          ),
          const SizedBox(height: 16),
          Text(formStatus.name),
        ],
      ),
    );
  }
}

enum ValidationStatus {
  inProgress,
  valid,
  invalid,
  none,
}

class QuizController extends ChangeNotifier {
  QuizController();

  final QuizFormController formController = QuizFormController();

  ValidationStatus _validationStatus = ValidationStatus.none;
  ValidationStatus get validationStatus => _validationStatus;

  void _setStatus(ValidationStatus status) {
    _validationStatus = status;
    notifyListeners();
  }

  Future<void> submit() async {
    _setStatus(ValidationStatus.inProgress);
    debugPrint('Validation in progress...');
    final result = await quizValidation(
      formController.riverQuestion.value.value,
      formController.mountQuestion.value.value,
    );
    formController.riverQuestion.setError(
      result.$1 ? null : ValidationError.invalidAnswer,
    );
    formController.mountQuestion.setError(
      result.$2 ? null : ValidationError.invalidAnswer,
    );
    if (result.$1 && result.$2) {
      _setStatus(ValidationStatus.valid);
      debugPrint('Validation successful!');
    } else {
      _setStatus(ValidationStatus.invalid);
      debugPrint('Validation failed!');
    }
  }

  Future<(bool, bool)> quizValidation(String answer1, String answer2) async {
    await Future<void>.delayed(const Duration(seconds: 1));
    return (answer1 == 'Nile', answer2 == 'Everest');
  }

  @override
  void dispose() {
    formController.dispose();
    super.dispose();
  }
}

class QuizFormController extends AdvancedFormController {
  QuizFormController() {
    registerFields([
      riverQuestion,
      mountQuestion,
    ]);
  }

  final riverQuestion = AdvancedTextFieldController<ValidationError>();
  final mountQuestion = AdvancedTextFieldController<ValidationError>();
}
