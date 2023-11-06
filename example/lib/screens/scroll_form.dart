import 'package:bloc_presentation/bloc_presentation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:leancode_forms/leancode_forms.dart';
import 'package:leancode_forms_example/cubits/focusable_text_field_cubit.dart';
import 'package:leancode_forms_example/main.dart';
import 'package:leancode_forms_example/screens/form_page.dart';
import 'package:leancode_forms_example/utils/extensions/iterable_extensions.dart';
import 'package:leancode_forms_example/widgets/form_text_field.dart';

class ScrollFormScreen extends StatelessWidget {
  const ScrollFormScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<ScrollFormCubit>(
      create: (context) => ScrollFormCubit(),
      child: const ScrollForm(),
    );
  }
}

class ScrollForm extends StatelessWidget {
  const ScrollForm({super.key});

  @override
  Widget build(BuildContext context) {
    void scrollToFistError() {
      final scrollFormCubit = context.read<ScrollFormCubit>();
      final fields = [
        scrollFormCubit.firstField,
        scrollFormCubit.secondField,
        scrollFormCubit.thirdField,
      ];
      fields.firstWhereOrNull((field) => field.state.isInvalid)?.focus();
    }

    return FormPage(
      title: 'Scroll Form',
      child: BlocPresentationListener<ScrollFormCubit, ScrollFormCubitEvent>(
        listener: (context, event) {
          if (event is SubmitFailedWithErrors) {
            scrollToFistError();
          }
        },
        child: SingleChildScrollView(
          child: Column(
            children: [
              FocusableFormTextField(
                field: context.read<ScrollFormCubit>().firstField,
                translateError: validatorTranslator,
                labelText: 'First field',
                hintText: 'Write here...',
                onFieldSubmitted: (_) =>
                    context.read<ScrollFormCubit>().secondField.focus(),
              ),
              const SizedBox(height: 260),
              FocusableFormTextField(
                field: context.read<ScrollFormCubit>().secondField,
                translateError: validatorTranslator,
                labelText: 'Second field',
                hintText: 'Write here...',
                onFieldSubmitted: (_) =>
                    context.read<ScrollFormCubit>().thirdField.focus(),
              ),
              const SizedBox(height: 260),
              FocusableFormTextField(
                field: context.read<ScrollFormCubit>().thirdField,
                translateError: validatorTranslator,
                labelText: 'Third field',
                hintText: 'Write here...',
              ),
              const SizedBox(height: 260),
              ElevatedButton(
                onPressed: context.read<ScrollFormCubit>().submit,
                child: const Text('Submit'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ScrollFormCubit extends FormGroupCubit
    with BlocPresentationMixin<FormGroupState, ScrollFormCubitEvent> {
  ScrollFormCubit() {
    registerFields([
      firstField,
      secondField,
      thirdField,
    ]);
  }

  final firstField = FocusableTextFieldCubit<ValidationError>(
    validator: filled(ValidationError.empty),
  );
  final secondField = FocusableTextFieldCubit<ValidationError>(
    validator: filled(ValidationError.empty),
  );
  final thirdField = FocusableTextFieldCubit<ValidationError>(
    validator: filled(ValidationError.empty),
  );

  void submit() {
    if (validate()) {
      debugPrint('Submit successful');
    } else {
      emitPresentation(const SubmitFailedWithErrors());
    }
  }
}

sealed class ScrollFormCubitEvent {}

class SubmitFailedWithErrors implements ScrollFormCubitEvent {
  const SubmitFailedWithErrors();
}
