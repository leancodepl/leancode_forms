import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:leancode_forms/leancode_forms.dart';
import 'package:leancode_forms_example/main.dart';
import 'package:leancode_forms_example/screens/form_page.dart';
import 'package:leancode_forms_example/widgets/form_dropdown_field.dart';
import 'package:leancode_forms_example/widgets/form_text_field.dart';
import 'package:rxdart/rxdart.dart';

/// This is an example of a simple form with two fields.
/// The form is validated ONLY when the submit button is pressed.
class ComplexFormScreen extends StatelessWidget {
  const ComplexFormScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<ComplexFormCubit>(
      create: (context) => ComplexFormCubit(),
      child: const ComplexForm(),
    );
  }
}

class ComplexForm extends StatelessWidget {
  const ComplexForm({super.key});

  @override
  Widget build(BuildContext context) {
    return FormPage(
      title: 'Complex Form',
      child: SingleChildScrollView(
        child: Column(
          children: [
            FormDropdownField(
              field: context.read<ComplexFormCubit>().type,
              labelBuilder: (value) => value?.name ?? 'Select subform type',
              translateError: validatorTranslator,
              labelText: 'Subform Type',
              hintText: 'Select subform type',
            ),
            Builder(
              builder: (context) {
                final type = context.select<ComplexFormCubit, SubformType?>(
                  (cubit) => cubit.subformType,
                );
                return switch (type) {
                  SubformType.human => HumanSubform(
                      cubit: context.read<ComplexFormCubit>().humanSubform,
                    ),
                  SubformType.dog => DogSubform(
                      cubit: context.read<ComplexFormCubit>().dogSubform,
                    ),
                  _ => const SizedBox(),
                };
              },
            ),
            ElevatedButton(
              onPressed: context.read<ComplexFormCubit>().submit,
              child: const Text('Submit'),
            ),
          ],
        ),
      ),
    );
  }
}

class HumanSubform extends StatelessWidget {
  const HumanSubform({super.key, required this.cubit});

  final HumanSubformCubit cubit;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        FormDropdownField(
          field: cubit.gender,
          labelBuilder: (value) => value.name,
          translateError: validatorTranslator,
          labelText: 'Gender',
          hintText: 'Select gender',
        ),
        const SizedBox(height: 16),
        FormTextField(
          field: cubit.age,
          translateError: validatorTranslator,
          labelText: 'Age',
          hintText: 'Enter human age',
        ),
      ],
    );
  }
}

class DogSubform extends StatelessWidget {
  const DogSubform({super.key, required this.cubit});

  final DogSubformCubit cubit;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        FormDropdownField(
          field: cubit.breed,
          labelBuilder: (value) => value.name,
          translateError: validatorTranslator,
          labelText: 'Breed',
          hintText: 'Select breed',
        ),
        const SizedBox(height: 16),
        FormTextField(
          field: cubit.age,
          translateError: validatorTranslator,
          labelText: 'Age',
          hintText: 'Enter dog age',
        ),
      ],
    );
  }
}

class ComplexFormCubit extends FormGroupCubit {
  ComplexFormCubit() {
    registerFields([
      type,
    ]);
    addDisposable(
      type.stream
          .map((event) => event.value)
          .distinct()
          .debounceTime(const Duration(milliseconds: 500))
          .listen(_onTypeUpdated)
          .cancel,
    );
  }

  final type = SingleSelectFieldCubit<SubformType?, ValidationError>(
    options: SubformType.values,
    initialValue: null,
  );

  SubformType? subformType;

  final dogSubform = DogSubformCubit();

  final humanSubform = HumanSubformCubit();

  Future<void> _onTypeUpdated(SubformType? type) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    subformType = type;

    if (type == SubformType.human) {
      addSubform(humanSubform);
    } else {
      humanSubform.resetAll();
      await removeSubform(humanSubform, close: false);
    }
    if (type == SubformType.dog) {
      addSubform(dogSubform);
    } else {
      dogSubform.resetAll();
      await removeSubform(dogSubform, close: false);
    }
  }

  void submit() {
    if (validate()) {
      debugPrint('Form is valid!');
    } else {
      debugPrint('Form is invalid!');
    }
  }
}

class HumanSubformCubit extends FormGroupCubit {
  HumanSubformCubit() {
    registerFields([
      gender,
      age,
    ]);
  }

  final gender = SingleSelectFieldCubit<Gender, ValidationError>(
    initialValue: Gender.male,
    options: Gender.values,
  );

  final age = TextFieldCubit(
    validator: filled(ValidationError.empty),
  );
}

class DogSubformCubit extends FormGroupCubit {
  DogSubformCubit() {
    registerFields([
      breed,
      age,
    ]);
  }

  final breed = SingleSelectFieldCubit<Breed, ValidationError>(
    initialValue: null,
    options: Breed.values,
    validator: (value) {
      if (value == null) {
        return ValidationError.empty;
      }
      return null;
    },
  );

  final age = TextFieldCubit(
    validator: filled(ValidationError.empty),
  );
}

enum SubformType {
  dog,
  human,
}

enum Gender {
  male,
  female,
}

enum Breed {
  beagle,
  bulldog,
  chihuahua,
  dachshund,
  dalmatian,
  germanShepherd,
  goldenRetriever,
  greatDane,
  husky,
  labrador,
  poodle,
  pug,
  rottweiler,
  terrier,
}
