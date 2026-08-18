import 'package:advanced_forms/advanced_forms.dart';
import 'package:advanced_forms_example/main.dart';
import 'package:advanced_forms_example/screens/form_page.dart';
import 'package:advanced_forms_example/widgets/form_dropdown_field.dart';
import 'package:advanced_forms_example/widgets/form_switch_field.dart';
import 'package:advanced_forms_example/widgets/form_text_field.dart';
import 'package:advanced_forms_example/widgets/screen_description.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// A wizard: one subform per step, validated one step at a time.
///
/// The pattern in two lines:
///
/// * **Next** runs `await step.validate()` on the current subform only, so a
///   field on a later step is never flagged before the user gets there.
/// * **Submit** runs `await validate()` on the parent, which reaches every
///   attached subform — a step the user walked back over is checked again.
class StepFormScreen extends StatelessWidget {
  const StepFormScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<StepFormController>(
      create: (context) => StepFormController(),
      child: const StepForm(),
    );
  }
}

class StepForm extends StatelessWidget {
  const StepForm({super.key});

  @override
  Widget build(BuildContext context) {
    // The stepper header shows one badge per step, so it is the rare widget
    // that wants tree-wide state. Every field below subscribes to its own
    // field, as usual.
    final controller = context.watch<StepFormController>();

    return FormPage(
      title: 'Step Form',
      child: Column(
        children: [
          ScreenDescription([
            bold('A wizard validated step by step. '),
            plain('Each step is a '),
            code('AdvancedFormController'),
            plain(' attached with '),
            code('addSubform'),
            plain('. '),
            bold('Next'),
            plain(' validates only the current step — including its async '
                'checks — while later steps stay quiet. A step that fails '
                'once switches to '),
            code('ValidationMode.onUserInteraction'),
            plain(', so it then corrects itself as you type. '),
            bold('Submit'),
            plain(' validates the whole tree and jumps back to the first step '
                'that still has an error. Try '),
            code('john@email.com'),
            plain(' to see Next wait for the async check.'),
          ]),
          Expanded(
            child: ValueListenableBuilder<int>(
              valueListenable: controller.currentStep,
              builder: (context, currentStep, _) => Stepper(
                currentStep: currentStep,
                // Tapping a header walks back only: going forward has to pass
                // through the validation in `next()`.
                onStepTapped: (index) {
                  if (index < currentStep) {
                    controller.goTo(index);
                  }
                },
                controlsBuilder: (context, details) => const _StepControls(),
                steps: [
                  Step(
                    title: const Text('Account'),
                    state: controller.stepStateOf(0),
                    isActive: currentStep == 0,
                    content: _AccountStep(controller: controller.account),
                  ),
                  Step(
                    title: const Text('Address'),
                    state: controller.stepStateOf(1),
                    isActive: currentStep == 1,
                    content: _AddressStep(controller: controller.address),
                  ),
                  Step(
                    title: const Text('Confirm'),
                    state: controller.stepStateOf(2),
                    isActive: currentStep == 2,
                    content: _ConfirmStep(controller: controller.confirm),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Back / Next on every step, Back / Submit on the last one.
class _StepControls extends StatelessWidget {
  const _StepControls();

  @override
  Widget build(BuildContext context) {
    final controller = context.read<StepFormController>();

    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: ValueListenableBuilder<int>(
        valueListenable: controller.currentStep,
        builder: (context, currentStep, _) {
          final isLast = currentStep == controller.steps.length - 1;

          return Row(
            children: [
              if (currentStep > 0)
                TextButton(
                  onPressed: controller.back,
                  child: const Text('Back'),
                ),
              const Spacer(),
              if (isLast)
                const _SubmitButton()
              else
                // `next()` awaits the step's async checks, so the button has
                // to await it too — never pass it as a bare VoidCallback.
                ElevatedButton(
                  onPressed: () async => controller.next(),
                  child: const Text('Next'),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// The submit call in flight is the app's business, not the package's:
/// [AdvancedFormState.validating] covers async validators only. The controller
/// keeps its own flag, set before the first `await`, so a double tap sends one
/// request.
class _SubmitButton extends StatelessWidget {
  const _SubmitButton();

  @override
  Widget build(BuildContext context) {
    final controller = context.read<StepFormController>();

    return ValueListenableBuilder<bool>(
      valueListenable: controller.isSubmitting,
      builder: (context, isSubmitting, _) => ElevatedButton(
        onPressed: isSubmitting
            ? null
            : () async {
                final succeeded = await controller.submit();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        succeeded
                            ? 'Account created'
                            : 'Some steps still need fixing',
                      ),
                    ),
                  );
                }
              },
        child: isSubmitting
            ? const SizedBox.square(
                dimension: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Text('Submit'),
      ),
    );
  }
}

class _AccountStep extends StatelessWidget {
  const _AccountStep({required this.controller});

  final AccountStepController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        FormTextField(
          field: controller.email,
          translateError: validatorTranslator,
          labelText: 'Email',
          hintText: 'Enter your email',
        ),
        FormTextField(
          field: controller.password,
          translateError: validatorTranslator,
          labelText: 'Password',
          hintText: 'At least 8 characters',
        ),
      ],
    );
  }
}

class _AddressStep extends StatelessWidget {
  const _AddressStep({required this.controller});

  final AddressStepController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        FormDropdownField(
          field: controller.country,
          labelBuilder: (value) => value.label,
          translateError: validatorTranslator,
          labelText: 'Country',
          hintText: 'Select a country',
        ),
        FormTextField(
          field: controller.city,
          translateError: validatorTranslator,
          labelText: 'City',
          hintText: 'Enter your city',
        ),
      ],
    );
  }
}

class _ConfirmStep extends StatelessWidget {
  const _ConfirmStep({required this.controller});

  final ConfirmStepController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        FormSwitchField(
          field: controller.newsletter,
          labelText: 'Send me the newsletter',
        ),
        FormSwitchField(
          field: controller.acceptTerms,
          labelText: 'I accept the terms',
        ),
        // A boolean field has no `errorText` slot of its own, so its error is
        // rendered next to it.
        AdvancedFieldBuilder<bool, ValidationError>(
          field: controller.acceptTerms,
          builder: (context, state, _) {
            final error = state.error;
            return error == null
                ? const SizedBox.shrink()
                : Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      validatorTranslator(error),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  );
          },
        ),
      ],
    );
  }
}

/// The wizard. It owns no fields of its own — every field lives on a step.
class StepFormController extends AdvancedFormController {
  StepFormController() {
    steps.forEach(addSubform);
  }

  final account = AccountStepController();
  final address = AddressStepController();
  final confirm = ConfirmStepController();

  late final List<AdvancedFormController> steps = [account, address, confirm];

  /// Which step is on screen. Plain `ValueNotifier`s: the package tracks form
  /// state, never navigation.
  final currentStep = ValueNotifier(0);

  /// Whether the save call is in flight — see [_SubmitButton].
  final isSubmitting = ValueNotifier(false);

  /// Validates the current step and moves on if it passed.
  ///
  /// A subform's `validate()` reaches its own fields only, which is what makes
  /// per-step validation one line.
  Future<bool> next() async {
    final step = steps[currentStep.value];

    if (!await step.validate()) {
      // The step has now shown its errors once, so let it keep itself current
      // as the user fixes them. A step's own mode wins over the parent's, so
      // the steps ahead stay quiet.
      step.setValidationMode(ValidationMode.onUserInteraction);
      return false;
    }

    if (currentStep.value < steps.length - 1) {
      currentStep.value++;
    }
    return true;
  }

  void back() => goTo(currentStep.value - 1);

  void goTo(int index) {
    if (index >= 0 && index < steps.length) {
      currentStep.value = index;
    }
  }

  Future<bool> submit() async {
    // Set before the first `await`, or a double tap sends two requests.
    isSubmitting.value = true;
    try {
      // The parent walks every attached subform, so this covers the steps the
      // user already passed as well as the one on screen.
      if (!await validate()) {
        _goToFirstInvalidStep();
        return false;
      }

      // Stands in for the save call.
      await Future<void>.delayed(const Duration(milliseconds: 500));
      return true;
    } finally {
      isSubmitting.value = false;
    }
  }

  /// The badge Stepper shows for each step header.
  StepState stepStateOf(int index) {
    if (!steps[index].value.canSubmit) {
      return StepState.error;
    }
    return index < currentStep.value ? StepState.complete : StepState.indexed;
  }

  void _goToFirstInvalidStep() {
    // `validate()` has just run, so every error is recorded and `canSubmit` is
    // an accurate snapshot here.
    final index = steps.indexWhere((step) => !step.value.canSubmit);
    if (index == -1) {
      return;
    }
    steps[index].setValidationMode(ValidationMode.onUserInteraction);
    currentStep.value = index;
  }

  @override
  void dispose() {
    // Our own objects first, then the superclass — which disposes the three
    // step subforms and every field on them.
    currentStep.dispose();
    isSubmitting.dispose();
    super.dispose();
  }
}

/// Step 1. The async check runs on Next, not on every keystroke: the step
/// starts in the default `ValidationMode.manual`.
class AccountStepController extends AdvancedFormController {
  AccountStepController() {
    registerFields([email, password]);
  }

  final email = AdvancedTextFieldController(
    // Both sides of `&` must take the same type, so the closure is written
    // over `String?` like the built-in string validators.
    validator: filled(ValidationError.empty) &
        ((String? value) => (value?.contains('@') ?? false)
            ? null
            : ValidationError.invalidEmail),
    asyncValidation: const AsyncValidation(
      validator: _checkEmailTaken,
      timeout: Duration(seconds: 5),
      failureToError: _emailCheckFailed,
    ),
  );

  final password = AdvancedTextFieldController(
    validator: filled(ValidationError.empty) &
        atLeastLength(8, ValidationError.toShort),
  );
}

Future<ValidationError?> _checkEmailTaken(String value) async {
  const taken = ['john@email.com', 'jack@email.com'];
  await Future<void>.delayed(const Duration(milliseconds: 700));
  return taken.contains(value) ? ValidationError.emailTaken : null;
}

ValidationError _emailCheckFailed(Object error, StackTrace stackTrace) =>
    ValidationError.emailCheckUnavailable;

/// Step 2. Picking another country clears the city, through the form's
/// `addRelation` — "when B changes, set A".
class AddressStepController extends AdvancedFormController {
  AddressStepController() {
    registerFields([country, city]);
    addRelation(country, (value) => value, (_) => city.reset());
  }

  final country = AdvancedSingleSelectFieldController<Country, ValidationError>(
    initialValue: null,
    options: Country.values,
    validator: notNull(ValidationError.empty),
  );

  final city = AdvancedTextFieldController(
    validator: filled(ValidationError.empty),
  );
}

/// Step 3. A boolean field has no built-in validator, so the rule is a
/// one-line closure.
class ConfirmStepController extends AdvancedFormController {
  ConfirmStepController() {
    registerFields([newsletter, acceptTerms]);
  }

  final newsletter = AdvancedBooleanFieldController<ValidationError>();

  final acceptTerms = AdvancedBooleanFieldController<ValidationError>(
    validator: (value) => value ? null : ValidationError.mustAccept,
  );
}

enum Country {
  poland('Poland'),
  germany('Germany'),
  spain('Spain');

  const Country(this.label);

  final String label;
}
