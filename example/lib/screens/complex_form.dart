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
      create: (_) => ComplexFormController(),
      child: const ComplexForm(),
    );
  }
}

class ComplexForm extends StatelessWidget {
  const ComplexForm({super.key});

  @override
  Widget build(BuildContext context) {
    final controller =
        context.select<ComplexFormController, ComplexFormController>((c) => c);
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
                final type = context.select<ComplexFormController, SubformType?>(
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

class ComplexFormController extends FormController {
  ComplexFormController() {
    registerFields([type]);
    type.addListener(_onTypeListenerFired);
  }

  final type = SingleSelectFieldController<SubformType?, ValidationError>(
    options: SubformType.values,
    initialValue: null,
  );

  SubformType? subformType;

  final dogSubform = DogSubformController();
  final humanSubform = HumanSubformController();

  Timer? _typeDebounce;
  SubformType? _lastSeenType;

  void _onTypeListenerFired() {
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

  @override
  void dispose() {
    _typeDebounce?.cancel();
    type.removeListener(_onTypeListenerFired);
    humanSubform.dispose();
    dogSubform.dispose();
    super.dispose();
  }
}

class HumanSubformController extends FormController {
  HumanSubformController() {
    registerFields([
      gender,
      age,
    ]);
  }

  final gender = SingleSelectFieldController<Gender, ValidationError>(
    initialValue: Gender.male,
    options: Gender.values,
  );

  final age = TextFieldController(
    validator: filled(ValidationError.empty),
  );
}

class DogSubformController extends FormController {
  DogSubformController() {
    registerFields([
      breed,
      age,
    ]);
  }

  final breed = SingleSelectFieldController<Breed, ValidationError>(
    initialValue: null,
    options: Breed.values,
    validator: (value) {
      if (value == null) {
        return ValidationError.empty;
      }
      return null;
    },
  );

  final age = TextFieldController(
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
