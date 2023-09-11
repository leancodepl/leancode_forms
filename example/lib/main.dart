import 'package:flutter/material.dart';
import 'package:leancode_forms/leancode_forms.dart';
import 'package:leancode_forms_example/cubits/password_field_cubit.dart';
import 'package:leancode_forms_example/screens/simple_form.dart';

void main() {
  runApp(const MainApp());
}

class Routes {
  static const simple = '/';
}

enum ValidationError {
  //common
  empty,
  toShort,
  toLong,

  //password related
  noNumber,
  noSpecialChar,
  noUpperCase,
  noLowerCase,
  doesNotMatch,

  //email related
  invalidEmail,
  emailTaken,
}

/// Would be replaced by mapping an error to a string in a translation file
String validatorTranslator(ValidationError error) {
  return switch (error) {
    ValidationError.empty => 'This value is required',
    ValidationError.toShort => 'This value is too short',
    ValidationError.toLong => 'This value is too long',
    ValidationError.noNumber => 'This value must contain a number',
    ValidationError.noSpecialChar =>
      'This value must contain a special character',
    ValidationError.noUpperCase =>
      'This value must contain an uppercase letter',
    ValidationError.noLowerCase => 'This value must contain a lowercase letter',
    ValidationError.doesNotMatch => 'Passwords must match',
    ValidationError.invalidEmail => 'Invalid email',
    ValidationError.emailTaken => 'Email already taken',
  };
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      routes: <String, WidgetBuilder>{
        Routes.simple: (_) => const SimpleFormScreen(),
      },
    );
  }
}

class PasswordSubformCubit extends FormGroupCubit {
  PasswordSubformCubit() {
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

class ExampleSubformCubit extends FormGroupCubit {
  ExampleSubformCubit() {
    registerFields([
      email,
      password,
      repeatPassword,
    ]);
  }

  final email = TextFieldCubit<String>(
    validator: filled('Email is required'),
  );

  final password = PasswordFieldCubit(
    numberRequired: true,
    specialCharRequired: true,
    upperCaseRequired: true,
    lowerCaseRequired: true,
  );

  late final repeatPassword = TextFieldCubit<String>(
    validator: (value) {
      if (value != password.state.value) {
        return 'Passwords must match';
      }
      return null;
    },
  );
}

class ExampleFormCubit extends FormGroupCubit {
  ExampleFormCubit() {
    registerFields([
      firstName,
      lastName,
      createAccount,
      accountType,
      languages,
    ]);
  }

  final firstName = TextFieldCubit<String>(
    validator: filled('First name is required'),
  );

  final lastName = TextFieldCubit<String>(
    validator: filled('First name is required'),
  );

  late final createAccount = BooleanFieldCubit<bool>();

  final accountSubform = ExampleSubformCubit();

  final accountType = SingleSelectFieldCubit<DeliveryType?, String>(
    initialValue: null,
    options: DeliveryType.values,
  );

  final languages = MultiSelectFieldCubit<Language, String>(
    initialValue: {},
    options: Language.values,
  );

  void submit() {
    setAutovalidate(true);
    final isValid = validate();
    debugPrint(isValid.toString());
  }
}

enum DeliveryType {
  dpd,
  ups,
  fedex,
}

enum Language {
  english,
  spanish,
  french,
  german,
  chinese,
}

/* home: BlocProvider<ExampleFormCubit>(
        create: (context) => ExampleFormCubit(),
        child: Builder(
          builder: (context) {
            return Scaffold(
              appBar: AppBar(title: const Text('Example Form')),
              body: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      FieldBuilder<String, String>(
                        field: context.read<ExampleFormCubit>().firstName,
                        builder: (context, state) => TextField(
                          onChanged: (value) => context
                              .read<ExampleFormCubit>()
                              .firstName
                              .setValue(value),
                          decoration: InputDecoration(
                            labelText: 'First name',
                            hintText: 'Enter your first name',
                            errorText: state.error,
                          ),
                        ),
                      ),
                      FieldBuilder<String, String>(
                        field: context.read<ExampleFormCubit>().lastName,
                        builder: (context, state) => TextField(
                          onChanged: (value) => context
                              .read<ExampleFormCubit>()
                              .lastName
                              .setValue(value),
                          decoration: InputDecoration(
                            labelText: 'Last name',
                            hintText: 'Enter your last name',
                            errorText: state.error,
                          ),
                        ),
                      ),
                      FieldBuilder<bool, String>(
                        field: context.read<ExampleFormCubit>().createAccount,
                        builder: (context, state) => Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Create account'),
                            Switch(
                              value: state.value,
                              onChanged: (_) => context
                                  .read<ExampleFormCubit>()
                                  .createAccount
                                  .toggle(),
                            ),
                          ],
                        ),
                      ),
                      FieldBuilder(
                        field: context.read<ExampleFormCubit>().accountType,
                        builder: (context, state) =>
                            DropdownButtonFormField<DeliveryType?>(
                          value: state.value,
                          onChanged: (value) => context
                              .read<ExampleFormCubit>()
                              .accountType
                              .setValue(value),
                          items: DeliveryType.values
                              .map(
                                (e) => DropdownMenuItem(
                                  value: e,
                                  child: Text(e.name),
                                ),
                              )
                              .toList(),
                          decoration: InputDecoration(
                            labelText: 'Account Type',
                            hintText: 'Select your account type',
                            errorText: state.error,
                          ),
                        ),
                      ),
                      FieldBuilder(
                        field: context.read<ExampleFormCubit>().languages,
                        builder: (context, state) => ListView.builder(
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: context
                              .read<ExampleFormCubit>()
                              .languages
                              .options
                              .length,
                          shrinkWrap: true,
                          itemBuilder: (context, index) {
                            final item = context
                                .read<ExampleFormCubit>()
                                .languages
                                .options[index];
                            return CheckboxListTile(
                              value: state.value.contains(item),
                              onChanged: (_) => context
                                  .read<ExampleFormCubit>()
                                  .languages
                                  .toggleElement(item),
                              title: Text(item.name),
                            );
                          },
                        ),
                      ),
                      ElevatedButton(
                        onPressed: context.read<ExampleFormCubit>().submit,
                        child: const Text('Submit'),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ), */
      
