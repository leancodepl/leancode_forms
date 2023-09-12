import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:leancode_forms/leancode_forms.dart';
import 'package:leancode_forms_example/main.dart';
import 'package:leancode_forms_example/screens/form_page.dart';
import 'package:leancode_forms_example/widgets/form_text_field.dart';

/// This is an example of a form which is asynchronously validated after pressing the submit button.
/// Errors on the fields are set/cleared manually after the validation is complete.
class QuizFormScreen extends StatelessWidget {
  const QuizFormScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<QuizCubit>(
      create: (context) => QuizCubit(),
      child: const QuizForm(),
    );
  }
}

class QuizForm extends StatelessWidget {
  const QuizForm({super.key});

  @override
  Widget build(BuildContext context) {
    final formStatus = context.select<QuizCubit, ValidationStatus>(
      (cubit) => cubit.state.validationStatus,
    );

    return FormPage(
      title: 'Quiz Form',
      child: Column(
        children: [
          const Text('What is the longest river in the world?'),
          FormTextField(
            field: context.read<QuizCubit>().formCubit.riverQuestion,
            translateError: validatorTranslator,
            hintText: 'Answer here',
          ),
          const SizedBox(height: 16),
          const Text('What is the highest mountain in the world?'),
          FormTextField(
            field: context.read<QuizCubit>().formCubit.mountQuestion,
            translateError: validatorTranslator,
            hintText: 'Answer here',
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: context.read<QuizCubit>().submit,
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

class QuizCubit extends Cubit<QuizState> {
  QuizCubit() : super(QuizState());

  final QuizFormCubit formCubit = QuizFormCubit();

  Future<void> submit() async {
    emit(QuizState(validationStatus: ValidationStatus.inProgress));
    debugPrint('Validation in progress...');
    final result = await quizValidation(
      formCubit.riverQuestion.state.value,
      formCubit.mountQuestion.state.value,
    );
    formCubit.riverQuestion.setError(
      result.$1 ? null : ValidationError.invalidAnswer,
    );
    formCubit.mountQuestion.setError(
      result.$2 ? null : ValidationError.invalidAnswer,
    );
    if (result.$1 && result.$2) {
      emit(QuizState(validationStatus: ValidationStatus.valid));
      debugPrint('Validation successful!');
    } else {
      emit(QuizState(validationStatus: ValidationStatus.invalid));
      debugPrint('Validation failed!');
    }
  }

  Future<(bool, bool)> quizValidation(String answer1, String answer2) async {
    await Future<void>.delayed(const Duration(seconds: 1));
    return (answer1 == 'Nile', answer2 == 'Everest');
  }
}

class QuizState {
  QuizState({this.validationStatus = ValidationStatus.none});

  final ValidationStatus validationStatus;
}

class QuizFormCubit extends FormGroupCubit {
  QuizFormCubit() {
    registerFields([
      riverQuestion,
      mountQuestion,
    ]);
  }

  final riverQuestion = TextFieldCubit<ValidationError>();

  final mountQuestion = TextFieldCubit<ValidationError>();
}
