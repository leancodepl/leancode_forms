import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:leancode_forms/leancode_forms.dart';
import 'package:leancode_forms_example/main.dart';
import 'package:leancode_forms_example/screens/form_page.dart';
import 'package:leancode_forms_example/widgets/form_text_field.dart';

/// This is an example of a simple form with two fields.
/// The form is validated ONLY when the submit button is pressed.
class SimpleFormScreen extends StatelessWidget {
  const SimpleFormScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<SimpleFormCubit>(
      create: (context) => SimpleFormCubit(),
      child: const SimpleForm(),
    );
  }
}

class SimpleForm extends StatelessWidget {
  const SimpleForm({super.key});

  @override
  Widget build(BuildContext context) {
    return FormPage(
      title: 'Simple Form',
      child: Column(
        children: [
          FormTextField(
            field: context.read<SimpleFormCubit>().firstName,
            translateError: validatorTranslator,
            labelText: 'First Name',
            hintText: 'Enter your first name',
          ),
          FormTextField(
            field: context.read<SimpleFormCubit>().lastName,
            translateError: validatorTranslator,
            labelText: 'Last Name',
            hintText: 'Enter your last name',
          ),
          ElevatedButton(
            onPressed: context.read<SimpleFormCubit>().submit,
            child: const Text('Submit'),
          ),
        ],
      ),
    );
  }
}

class SimpleFormCubit extends FormGroupCubit {
  SimpleFormCubit() {
    registerFields([
      firstName,
      lastName,
    ]);
  }

  final firstName = TextFieldCubit(
    validator: filled(ValidationError.empty),
  );

  final lastName = TextFieldCubit(
    validator: filled(ValidationError.empty),
  );

  void submit() {
    //Change to true to enable autovalidation of each field after pressing submit.
    if (validate(enableAutovalidate: false)) {
      debugPrint('First name: ${firstName.state.value}');
      debugPrint('Last name: ${lastName.state.value}');
    } else {
      debugPrint('Form is invalid');
    }
  }
}
