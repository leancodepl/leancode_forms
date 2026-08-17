import 'dart:async';

import 'package:flutter/material.dart';
import 'package:leancode_forms/leancode_forms.dart';
import 'package:leancode_forms_example/main.dart';
import 'package:leancode_forms_example/screens/form_page.dart';
import 'package:leancode_forms_example/widgets/form_dropdown_field.dart';
import 'package:leancode_forms_example/widgets/form_text_field.dart';
import 'package:leancode_forms_example/widgets/screen_description.dart';
import 'package:provider/provider.dart';

/// This is an example of a simple form with two fields.
/// The form is validated ONLY when the submit button is pressed.
class ComplexFormScreen extends StatelessWidget {
  const ComplexFormScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<ComplexFormController>(
      create: (context) => ComplexFormController(),
      child: const ComplexForm(),
    );
  }
}

class ComplexForm extends StatelessWidget {
  const ComplexForm({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ComplexFormController>();
    return FormPage(
      title: 'Complex Form',
      child: SingleChildScrollView(
        child: Column(
          children: [
            ScreenDescription([
              bold('Subform switching. '),
              plain('Choosing a type swaps the active subform (human / dog). '
                  'The parent uses a '),
              bold('debounced listener'),
              plain(' on the dropdown field to call '),
              code('addSubform'),
              plain(' or '),
              code('removeSubform'),
              plain('. Only the '),
              bold('active'),
              plain(' subform participates in validation.'),
            ]),
            FormDropdownField(
              field: controller.type,
              labelBuilder: (value) => value?.name ?? 'Select subform type',
              translateError: validatorTranslator,
              labelText: 'Subform Type',
              hintText: 'Select subform type',
            ),
            Builder(
              builder: (context) {
                final type =
                    context.select<ComplexFormController, SubformType?>(
                  (c) => c.subformType,
                );
                return switch (type) {
                  SubformType.human => HumanSubform(
                      controller: controller.humanSubform,
                    ),
                  SubformType.dog => DogSubform(
                      controller: controller.dogSubform,
                    ),
                  _ => const SizedBox(),
                };
              },
            ),
            ElevatedButton(
              onPressed: controller.submit,
              child: const Text('Submit'),
            ),
          ],
        ),
      ),
    );
  }
}

class HumanSubform extends StatelessWidget {
  const HumanSubform({super.key, required this.controller});

  final HumanSubformController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        FormDropdownField(
          field: controller.gender,
          labelBuilder: (value) => value.name,
          translateError: validatorTranslator,
          labelText: 'Gender',
          hintText: 'Select gender',
          canSetToInitial: true,
        ),
        const SizedBox(height: 16),
        FormTextField(
          field: controller.age,
          translateError: validatorTranslator,
          labelText: 'Age',
          hintText: 'Enter human age',
        ),
      ],
    );
  }
}

class DogSubform extends StatelessWidget {
  const DogSubform({super.key, required this.controller});

  final DogSubformController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        FormDropdownField(
          field: controller.breed,
          labelBuilder: (value) => value.name,
          translateError: validatorTranslator,
          labelText: 'Breed',
          hintText: 'Select breed',
        ),
        const SizedBox(height: 16),
        FormTextField(
          field: controller.age,
          translateError: validatorTranslator,
          labelText: 'Age',
          hintText: 'Enter dog age',
        ),
      ],
    );
  }
}

class ComplexFormController extends AdvancedFormController {
  ComplexFormController() {
    registerFields([type]);
    type.addListener(_onTypeChanged);
  }

  final type =
      AdvancedSingleSelectFieldController<SubformType?, ValidationError>(
    options: SubformType.values,
    initialValue: null,
  );

  SubformType? subformType;

  final dogSubform = DogSubformController();
  final humanSubform = HumanSubformController();

  Timer? _typeDebounce;
  SubformType? _lastSeenType;

  void _onTypeChanged() {
    final current = type.value.value;
    if (current == _lastSeenType) {
      return;
    }
    _lastSeenType = current;
    _typeDebounce?.cancel();
    _typeDebounce = Timer(const Duration(milliseconds: 500), () {
      _onTypeUpdated(current);
    });
  }

  Future<void> _onTypeUpdated(SubformType? type) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    subformType = type;
    notifyListeners();

    if (type == SubformType.human) {
      addSubform(humanSubform);
    } else {
      humanSubform.resetAll();
      removeSubform(humanSubform);
    }
    if (type == SubformType.dog) {
      addSubform(dogSubform);
    } else {
      dogSubform.resetAll();
      removeSubform(dogSubform);
    }
  }

  Future<void> submit() async {
    if (await validate()) {
      debugPrint('Form is valid!');
    } else {
      debugPrint('Form is invalid!');
    }
  }

  @override
  void dispose() {
    _typeDebounce?.cancel();
    type.removeListener(_onTypeChanged);
    // Both subforms are owned by this form, so super.dispose() disposes them.
    super.dispose();
  }
}

class HumanSubformController extends AdvancedFormController {
  HumanSubformController() {
    registerFields([
      gender,
      age,
    ]);
  }

  final gender = AdvancedSingleSelectFieldController<Gender, ValidationError>(
    initialValue: Gender.male,
    options: Gender.values,
  );

  final age = AdvancedTextFieldController(
    validator: filled(ValidationError.empty),
  );
}

class DogSubformController extends AdvancedFormController {
  DogSubformController() {
    registerFields([
      breed,
      age,
    ]);
  }

  final breed = AdvancedSingleSelectFieldController<Breed, ValidationError>(
    initialValue: null,
    options: Breed.values,
    validator: (value) {
      if (value == null) {
        return ValidationError.empty;
      }
      return null;
    },
  );

  final age = AdvancedTextFieldController(
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
