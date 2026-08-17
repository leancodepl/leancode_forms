import 'package:advanced_forms/advanced_forms.dart';
import 'package:advanced_forms_example/main.dart';
import 'package:advanced_forms_example/screens/form_page.dart';
import 'package:advanced_forms_example/widgets/form_dropdown_field.dart';
import 'package:advanced_forms_example/widgets/form_text_field.dart';
import 'package:advanced_forms_example/widgets/screen_description.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// This is an example of a form with dynamically added subforms.
class DeliveryListFormScreen extends StatelessWidget {
  const DeliveryListFormScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<DeliveryListFormController>(
      create: (context) => DeliveryListFormController(),
      child: const DeliveryListForm(),
    );
  }
}

class DeliveryListForm extends StatelessWidget {
  const DeliveryListForm({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<DeliveryListFormController>();
    return FormPage(
      title: 'Delivery List Form',
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ScreenDescription([
              bold('Dynamic subforms. '),
              plain('Each consumer is its own '),
              code('AdvancedFormController'),
              plain(" added as a subform to the parent. The parent's "),
              code('validate()'),
              plain(' recursively validates every consumer; disposing the '
                  'parent '),
              bold('cascades'),
              plain(' to every subform.'),
            ]),
            for (final form in controller.deliveryList)
              ConsumerSubform(
                key: ValueKey(form.hashCode),
                form: form,
                onRemove: controller.removeConsumer,
              ),
            ElevatedButton(
              onPressed: controller.addConsumer,
              child: const Text('Add Consumer'),
            ),
            const SizedBox(height: 16),
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

class ConsumerSubform extends StatelessWidget {
  const ConsumerSubform({
    super.key,
    required this.form,
    required this.onRemove,
  });

  final ConsumerSubformController form;
  final ValueChanged<ConsumerSubformController> onRemove;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Consumer'),
            IconButton(
              onPressed: () => onRemove(form),
              icon: const Icon(Icons.delete),
            ),
          ],
        ),
        const SizedBox(height: 16),
        FormTextField(
          field: form.email,
          translateError: validatorTranslator,
          labelText: 'Email',
          hintText: 'Enter consumer email',
        ),
        const SizedBox(height: 16),
        FormDropdownField(
          field: form.country,
          labelBuilder: (country) => country!.name,
          translateError: validatorTranslator,
          labelText: 'Country',
          hintText: 'Select consumer country',
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

class DeliveryListFormController extends AdvancedFormController {
  DeliveryListFormController();

  final deliveryList = <ConsumerSubformController>{};

  void addConsumer() {
    final consumerForm = ConsumerSubformController();
    addSubform(consumerForm);
    deliveryList.add(consumerForm);
    notifyListeners();
  }

  void removeConsumer(ConsumerSubformController form) {
    removeSubform(form);
    deliveryList.remove(form);
    notifyListeners();
  }

  Future<void> submit() async {
    if (await validate()) {
      for (final consumer in deliveryList) {
        debugPrint('Consumer email: ${consumer.email.value.value}');
        debugPrint('Consumer country: ${consumer.country.value.value}');
      }
      debugPrint('Form is valid');
    } else {
      debugPrint('Form is invalid');
    }
  }
}

class ConsumerSubformController extends AdvancedFormController {
  ConsumerSubformController() {
    registerFields([
      email,
      country,
    ]);
  }

  final email = AdvancedTextFieldController(
    validator: filled(ValidationError.empty),
  );

  final country =
      AdvancedSingleSelectFieldController<Country?, ValidationError>(
    initialValue: null,
    options: Country.values,
    validator: (country) {
      if (country == null) {
        return ValidationError.empty;
      }
      return null;
    },
  );
}

enum Country {
  usa,
  canada,
  mexico,
}
