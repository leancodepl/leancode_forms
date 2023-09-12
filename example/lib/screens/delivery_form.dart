import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:leancode_forms/leancode_forms.dart';
import 'package:leancode_forms_example/main.dart';
import 'package:leancode_forms_example/screens/form_page.dart';
import 'package:leancode_forms_example/widgets/form_text_field.dart';

/// This is an example of a form with dynamically added subforms.
class DeliveryListFormScreen extends StatelessWidget {
  const DeliveryListFormScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<DeliveryListFormCubit>(
      create: (context) => DeliveryListFormCubit(),
      child: const DeliveryListForm(),
    );
  }
}

class DeliveryListForm extends StatelessWidget {
  const DeliveryListForm({super.key});

  @override
  Widget build(BuildContext context) {
    return FormPage(
      title: 'Delivery List Form',
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ...context.watch<DeliveryListFormCubit>().deliveryList.entries.map(
                  (e) => ConsumerSubform(
                    form: e.value,
                    index: e.key,
                    onRemove:
                        context.watch<DeliveryListFormCubit>().removeConsumer,
                  ),
                ),
            ElevatedButton(
              onPressed: context.read<DeliveryListFormCubit>().addConsumer,
              child: const Text('Add Consumer'),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: context.read<DeliveryListFormCubit>().submit,
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
    required this.index,
    required this.onRemove,
  });

  final ConsumerSubformCubit form;
  final int index;
  final ValueChanged<int> onRemove;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Consumer $index'),
            IconButton(
              onPressed: () => onRemove(index),
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
        FieldBuilder(
          field: form.country,
          builder: (context, state) => DropdownButtonFormField<Country?>(
            value: state.value,
            onChanged: form.country.selectValue,
            items: Country.values
                .map(
                  (e) => DropdownMenuItem(
                    value: e,
                    child: Text(e.name),
                  ),
                )
                .toList(),
            decoration: InputDecoration(
              labelText: 'Country',
              hintText: 'Select your country',
              errorText: state.error != null
                  ? validatorTranslator(state.error!)
                  : null,
            ),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

class DeliveryListFormCubit extends FormGroupCubit {
  DeliveryListFormCubit();

  final deliveryList = <int, ConsumerSubformCubit>{};

  void addConsumer() {
    final consumerForm = ConsumerSubformCubit();
    addSubform(consumerForm);
    deliveryList[deliveryList.length] = consumerForm;
  }

  void removeConsumer(int index) {
    removeSubform(deliveryList[index]!);
    deliveryList.remove(index);
  }

  void submit() {
    if (validate()) {
      debugPrint('Form is valid');
    } else {
      debugPrint('Form is invalid');
    }
  }
}

class ConsumerSubformCubit extends FormGroupCubit {
  ConsumerSubformCubit() {
    registerFields([
      email,
      country,
    ]);
  }

  final email = TextFieldCubit(
    validator: filled(ValidationError.empty),
  );

  final country = SingleSelectFieldCubit<Country?, ValidationError>(
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
