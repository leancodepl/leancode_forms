import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:leancode_forms/leancode_forms.dart';
import 'package:leancode_forms_example/cubits/password_field_cubit.dart';
import 'package:leancode_forms_example/main.dart';
import 'package:leancode_forms_example/screens/form_page.dart';
import 'package:leancode_forms_example/widgets/form_password_field.dart';
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
          FormTextField(
            field: context.read<PasswordFormCubit>().username,
            translateError: validatorTranslator,
            labelText: 'Username',
            hintText: 'Enter your username',
          ),
          const SizedBox(height: 16),
          FormPasswordField(
            field: context.read<PasswordFormCubit>().passwordSubform.password,
            translateError: (error) => validatorTranslator(error.first),
            labelText: 'Password',
            hintText: 'Enter your password',
          ),
          const SizedBox(height: 16),
          FormTextField(
            field: context
                .read<PasswordFormCubit>()
                .passwordSubform
                .repeatPassword,
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
  PasswordFormCubit() : passwordSubform = PasswordSubformCubit() {
    registerFields([username]);
    addSubform(passwordSubform);
  }

  final username = TextFieldCubit(
    validator: filled(ValidationError.empty) &
        atLeastLength(5, ValidationError.toShort),
  );

  final PasswordSubformCubit passwordSubform;

  void submit() {
    if (validate()) {
      debugPrint('Username: ${username.state.value}');
      debugPrint('Password: ${passwordSubform.password.state.value}');
      debugPrint(
        'Repeated password: ${passwordSubform.repeatPassword.state.value}',
      );
    } else {
      debugPrint('Form is invalid');
    }
  }
}

class PasswordSubformCubit extends FormGroupCubit {
  PasswordSubformCubit() : super(validateAll: true) {
    registerFields([
      password,
      repeatPassword,
    ]);
  }

  final password = PasswordFieldCubit(
    numberRequired: true,
    specialCharRequired: true,
    upperCaseRequired: true,
    lowerCaseRequired: true,
  );

  late final repeatPassword = TextFieldCubit<ValidationError>(
    validator: (value) {
      if (value != password.state.value) {
        return ValidationError.doesNotMatch;
      }
      return null;
    },
  );
}
