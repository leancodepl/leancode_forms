import 'package:flutter/material.dart';
import 'package:leancode_forms_example/screens/delivery_form.dart';
import 'package:leancode_forms_example/screens/home_page.dart';
import 'package:leancode_forms_example/screens/password_form.dart';
import 'package:leancode_forms_example/screens/quiz_form.dart';
import 'package:leancode_forms_example/screens/simple_form.dart';

void main() {
  runApp(const MainApp());
}

class Routes {
  static const home = '/';
  static const simple = '/simple';
  static const password = '/password';
  static const delivery = '/delivery';
  static const quiz = '/quiz';
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

  //quiz related
  invalidAnswer,
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
    ValidationError.invalidAnswer => 'Invalid answer',
  };
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      routes: <String, WidgetBuilder>{
        Routes.home: (_) => const HomePage(),
        Routes.simple: (_) => const SimpleFormScreen(),
        Routes.password: (_) => const PasswordFormScreen(),
        Routes.delivery: (_) => const DeliveryListFormScreen(),
        Routes.quiz: (_) => const QuizFormScreen(),
      },
    );
  }
}

/* FieldBuilder(
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
                      */
