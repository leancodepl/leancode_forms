import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:leancode_forms/leancode_forms.dart';
import 'package:leancode_forms_example/main.dart';
import 'package:leancode_forms_example/screens/form_page.dart';
import 'package:leancode_forms_example/widgets/form_text_field.dart';

/// This is an example of a simple form with two basic fields and one field with async validation.
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
      child: SingleChildScrollView(
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
            FormTextField(
              field: context.read<SimpleFormCubit>().email,
              translateError: validatorTranslator,
              labelText: 'Email',
              hintText: 'Enter your email',
            ),
            ElevatedButton(
              onPressed: context.read<SimpleFormCubit>().submit,
              child: const Text('Submit'),
            ),
          ],
        ),
      ),
    );
  }
}

class SimpleFormCubit extends FormGroupCubit {
  SimpleFormCubit() {
    registerFields([
      firstName,
      lastName,
      email,
    ]);
  }

  final firstName = TextFieldCubit(
    initialValue: 'Example first name',
    validator: filled(ValidationError.empty),
  );

  final lastName = TextFieldCubit(
    initialValue: 'Example last name',
    validator: filled(ValidationError.empty),
  );

  //A field with async validation
  late final email = TextFieldCubit(
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
    //Change to true to enable autovalidation of each field after pressing submit.
    if (validate(enableAutovalidate: false)) {
      debugPrint('First name: ${firstName.state.value}');
      debugPrint('Last name: ${lastName.state.value}');
      debugPrint('Email: ${email.state.value}');
    } else {
      debugPrint('Form is invalid');
    }
  }
}
