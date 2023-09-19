import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:leancode_forms/leancode_forms.dart';
import 'package:leancode_forms_example/cubits/password_field_cubit.dart';
import 'package:leancode_forms_example/main.dart';
import 'package:leancode_forms_example/screens/form_page.dart';
import 'package:leancode_forms_example/widgets/form_password_field.dart';
import 'package:leancode_forms_example/widgets/form_switch_field.dart';
import 'package:leancode_forms_example/widgets/form_text_field.dart';

/// This is an example of a form with a password/repeat password fields.
/// In this form repeatPassword field is validated according to value in the password field.
class PasswordFormScreen extends StatelessWidget {
  const PasswordFormScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<PasswordFormCubit>(
      create: (context) => PasswordFormCubit(),
      child: const PasswordForm(),
    );
  }
}

class PasswordForm extends StatelessWidget {
  const PasswordForm({super.key});

  @override
  Widget build(BuildContext context) {
    return FormPage(
      title: 'Password Form',
      child: Column(
        children: [
          //This field starts to be validated as soon as it loses focus for the first time
          FormTextField(
            field: context.read<PasswordFormCubit>().username,
            onUnfocus: () => context.read<PasswordFormCubit>().username
              ..setAutovalidate(true)
              ..validate(),
            translateError: validatorTranslator,
            labelText: 'Username',
            hintText: 'Enter your username',
          ),
          const SizedBox(height: 16),
          FormSwitchField(
            field: context.read<PasswordFormCubit>().switchField,
            labelText: 'Repeat password should be 10 characters long',
          ),
          const SizedBox(height: 16),
          FormPasswordField(
            field: context.read<PasswordFormCubit>().password,
            translateError: (error) => validatorTranslator(error.first),
            labelText: 'Password',
            hintText: 'Enter your password',
          ),
          const SizedBox(height: 16),
          FormTextField(
            field: context.read<PasswordFormCubit>().repeatPassword,
            translateError: validatorTranslator,
            labelText: 'Repeat Password',
            hintText: 'Repeat your password',
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: context.read<PasswordFormCubit>().submit,
            child: const Text('Submit'),
          ),
        ],
      ),
    );
  }
}

class PasswordFormCubit extends FormGroupCubit {
  PasswordFormCubit() {
    registerFields([
      username,
      switchField,
      password,
      repeatPassword,
    ]);
  }

  final username = TextFieldCubit(
    validator: filled(ValidationError.empty) &
        atLeastLength(5, ValidationError.toShort),
  );

  final switchField = BooleanFieldCubit();

  late final password = PasswordFieldCubit(
    numberRequired: true,
    specialCharRequired: true,
    upperCaseRequired: true,
    lowerCaseRequired: true,
  );

  late final repeatPassword = TextFieldCubit<ValidationError>(
    validator: conditionalValidator(
      (value) {
        if (switchField.state.value == true && value.length < 10) {
          return ValidationError.toShort;
        }
        if (value != password.state.value) {
          return ValidationError.doesNotMatch;
        }
        return null;
      },
      () => password.state.value.isNotEmpty,
    ),
  )..subscribeToFields([switchField, password]);

  void submit() {
    if (validate()) {
      debugPrint('Username: ${username.state.value}');
      debugPrint('Switch field: ${switchField.state.value}');
      debugPrint('Password: ${password.state.value}');
      debugPrint('Repeated password: ${repeatPassword.state.value}');
    } else {
      debugPrint('Form is invalid');
    }
  }
}
