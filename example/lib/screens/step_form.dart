import 'package:advanced_forms/advanced_forms.dart';
import 'package:advanced_forms_example/main.dart';
import 'package:advanced_forms_example/screens/form_page.dart';
import 'package:advanced_forms_example/widgets/form_dropdown_field.dart';
import 'package:advanced_forms_example/widgets/form_switch_field.dart';
import 'package:advanced_forms_example/widgets/form_text_field.dart';
import 'package:advanced_forms_example/widgets/screen_description.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// A wizard whose steps are separate pages, validated one page at a time.
///
/// * **One controller above the pages**, so no page owns anything and walking
///   back loses nothing. Pushed routes work the same way: create the wizard
///   above the `Navigator`, or hand it to each route with
///   `ChangeNotifierProvider.value` — never inside a step page, where a pop
///   would dispose it.
/// * **Next** validates the current page's subform only.
/// * **Submit** validates the parent, which reaches every attached subform.
/// * A **skipped page** stays attached with `setValidationEnabled(false)`: the
///   navigation walks past it and its fields stop counting towards the parent.
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

class StepForm extends StatefulWidget {
  const StepForm({super.key});

  @override
  State<StepForm> createState() => _StepFormState();
}

class _StepFormState extends State<StepForm> {
  final _pageController = PageController();
  late final StepFormController _form = context.read<StepFormController>();

  @override
  void initState() {
    super.initState();
    // The wizard decides which page is current and the PageView follows: its
    // physics forbid swiping, so Next — which validates — is the only way on.
    _form.addListener(_showCurrentStep);
  }

  @override
  void dispose() {
    _form.removeListener(_showCurrentStep);
    _pageController.dispose();
    super.dispose();
  }

  void _showCurrentStep() {
    if (!_pageController.hasClients ||
        _pageController.page?.round() == _form.currentIndex) {
      return;
    }
    _pageController.animateToPage(
      _form.currentIndex,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final form = context.watch<StepFormController>();

    return FormPage(
      title: 'Step Form',
      child: Column(
        children: [
          ScreenDescription([
            bold('A wizard whose steps are separate pages. '),
            plain('Each page is an '),
            code('AdvancedFormController'),
            plain(' attached with '),
            code('addSubform'),
            plain('; the wizard owning them all is provided above the '),
            code('PageView'),
            plain(', so walking back loses nothing. '),
            bold('Next'),
            plain(' validates the current page only, including its async check '
                '— try '),
            code('john@email.com'),
            plain('. The '),
            bold('Invoice'),
            plain(' page is conditional: with the switch on Address off, '),
            code('setValidationEnabled(false)'),
            plain(' takes it out of the flow and out of '),
            code('validate()'),
            plain('.'),
          ]),
          _WizardProgress(form: form),
          Expanded(
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              children: [for (final step in form.activeSteps) _StepPage(step)],
            ),
          ),
        ],
      ),
    );
  }
}

class _WizardProgress extends StatelessWidget {
  const _WizardProgress({required this.form});

  final StepFormController form;

  @override
  Widget build(BuildContext context) {
    final steps = form.activeSteps;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Step ${form.currentIndex + 1} of ${steps.length} — '
            '${form.currentStep.title}',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(value: (form.currentIndex + 1) / steps.length),
        ],
      ),
    );
  }
}

/// One page: the step's fields, then its controls.
class _StepPage extends StatelessWidget {
  const _StepPage(this.step);

  final WizardStepController step;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: [
          switch (step) {
            final AccountStepController step => _AccountStep(step),
            final AddressStepController step => _AddressStep(step),
            final InvoiceStepController step => _InvoiceStep(step),
            final ConfirmStepController step => _ConfirmStep(step),
            _ => const SizedBox.shrink(),
          },
          const _StepControls(),
        ],
      ),
    );
  }
}

class _StepControls extends StatelessWidget {
  const _StepControls();

  @override
  Widget build(BuildContext context) {
    final form = context.watch<StepFormController>();

    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Row(
        children: [
          if (!form.isFirstStep)
            TextButton(onPressed: form.back, child: const Text('Back')),
          const Spacer(),
          if (form.isLastStep)
            const _SubmitButton()
          else
            // `next()` awaits the page's async checks, so the button awaits it
            // too — never a bare VoidCallback.
            ElevatedButton(
              onPressed: () async => form.next(),
              child: const Text('Next'),
            ),
        ],
      ),
    );
  }
}

class _SubmitButton extends StatelessWidget {
  const _SubmitButton();

  @override
  Widget build(BuildContext context) {
    final form = context.watch<StepFormController>();

    return ElevatedButton(
      onPressed: form.isSubmitting
          ? null
          : () async {
              final succeeded = await form.submit();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      succeeded ? 'Account created' : 'Some pages need fixing',
                    ),
                  ),
                );
              }
            },
      child: form.isSubmitting
          ? const SizedBox.square(
              dimension: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Text('Submit'),
    );
  }
}

class _AccountStep extends StatelessWidget {
  const _AccountStep(this.controller);

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
  const _AddressStep(this.controller);

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
        // The decision that adds or drops the Invoice page — an ordinary field
        // the wizard watches with `addRelation`.
        FormSwitchField(
          field: controller.needsInvoice,
          labelText: 'I need a VAT invoice',
        ),
      ],
    );
  }
}

class _InvoiceStep extends StatelessWidget {
  const _InvoiceStep(this.controller);

  final InvoiceStepController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        FormTextField(
          field: controller.companyName,
          translateError: validatorTranslator,
          labelText: 'Company name',
          hintText: 'Enter the company name',
        ),
        FormTextField(
          field: controller.taxId,
          translateError: validatorTranslator,
          labelText: 'Tax ID',
          hintText: 'At least 10 characters',
        ),
      ],
    );
  }
}

class _ConfirmStep extends StatelessWidget {
  const _ConfirmStep(this.controller);

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
        // A boolean field has no `errorText` slot, so its error is rendered
        // next to it.
        AdvancedFieldBuilder<bool, ValidationError>(
          field: controller.acceptTerms,
          builder: (context, state, _) => switch (state.error) {
            final error? => Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  validatorTranslator(error),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            null => const SizedBox.shrink(),
          },
        ),
      ],
    );
  }
}

/// One step of the wizard. Only the title is common — everything else is an
/// ordinary [AdvancedFormController].
abstract class WizardStepController extends AdvancedFormController {
  String get title;
}

/// The wizard. It owns no fields of its own — every field lives on a step.
///
/// Navigation is the app's state, not the package's, so it lives here as plain
/// fields with `notifyListeners()`; only [next], [back] and [submit] move it.
class StepFormController extends AdvancedFormController {
  StepFormController() {
    steps.forEach(addSubform);

    // Keeping the Invoice step attached and only switching its validation off
    // is what makes the skip reversible: its values, its fields and its
    // disposal stay with the wizard. `addRelation` fires on change only, so the
    // initial state is seeded right after.
    addRelation(address.needsInvoice, (value) => value, _setInvoiceEnabled);
    _setInvoiceEnabled(address.needsInvoice.fieldValue);
  }

  final account = AccountStepController();
  final address = AddressStepController();
  final invoice = InvoiceStepController();
  final confirm = ConfirmStepController();

  late final steps = <WizardStepController>[account, address, invoice, confirm];

  /// The steps the user actually walks through. A step switched off is out of
  /// the flow *and* out of `validate()`, `canSubmit` and `validating`, so that
  /// one flag is the whole condition.
  List<WizardStepController> get activeSteps => _activeSteps;
  var _activeSteps = <WizardStepController>[];

  int get currentIndex => _currentIndex;
  var _currentIndex = 0;

  /// Whether the save call is in flight. Not [AdvancedFormState.validating],
  /// which covers async validators — the package knows nothing about [submit].
  bool get isSubmitting => _isSubmitting;
  var _isSubmitting = false;

  WizardStepController get currentStep => _activeSteps[_currentIndex];

  bool get isFirstStep => _currentIndex == 0;

  bool get isLastStep => _currentIndex == _activeSteps.length - 1;

  /// Validates the current step and moves on if it passed. A subform's
  /// `validate()` reaches its own fields only, which is the whole trick.
  Future<bool> next() async {
    final step = currentStep;
    if (!await step.validate()) {
      // Shown its errors once, so let it correct itself as the user types. A
      // step's own mode wins over the parent's, so later steps stay quiet.
      step.setValidationMode(ValidationMode.onUserInteraction);
      return false;
    }

    _goTo(_currentIndex + 1);
    return true;
  }

  void back() => _goTo(_currentIndex - 1);

  Future<bool> submit() async {
    if (_isSubmitting) {
      return false;
    }
    // Set before the first `await`, or a double tap sends two requests.
    _setSubmitting(true);
    try {
      // The parent walks every attached subform, so this covers the pages the
      // user already passed. A skipped one is off, so it returns true unrun.
      if (!await validate()) {
        _goToFirstInvalidStep();
        return false;
      }

      await Future<void>.delayed(const Duration(milliseconds: 500));
      return true;
    } finally {
      _setSubmitting(false);
    }
  }

  void _goTo(int index) {
    if (index >= 0 && index < _activeSteps.length && index != _currentIndex) {
      _currentIndex = index;
      notifyListeners();
    }
  }

  void _goToFirstInvalidStep() {
    // `validate()` has just run, so `canSubmit` is an accurate snapshot here.
    final index = _activeSteps.indexWhere((step) => !step.value.canSubmit);
    if (index != -1) {
      _activeSteps[index].setValidationMode(ValidationMode.onUserInteraction);
      _goTo(index);
    }
  }

  void _setInvoiceEnabled(bool enabled) {
    final current = _activeSteps.isEmpty ? null : currentStep;
    invoice.setValidationEnabled(enabled);
    _activeSteps = [
      for (final step in steps)
        if (step.value.validationEnabled) step,
    ];
    // The user is never standing on a step as it leaves the flow — the switch
    // is on an earlier one — but clamp rather than trust that.
    _currentIndex = _activeSteps
        .indexOf(current ?? _activeSteps.first)
        .clamp(0, _activeSteps.length - 1);
    notifyListeners();
  }

  void _setSubmitting(bool value) {
    _isSubmitting = value;
    notifyListeners();
  }
}

/// Step 1. The async check runs on Next, not on every keystroke: the step
/// starts in the default `ValidationMode.manual`.
class AccountStepController extends WizardStepController {
  AccountStepController() {
    registerFields([email, password]);
  }

  @override
  String get title => 'Account';

  final email = AdvancedTextFieldController(
    // Both sides of `&` must take the same type, so the closure is written
    // over `String?` like the built-in string validators.
    validator: filled(ValidationError.empty) &
        ((String? value) => (value?.contains('@') ?? false)
            ? null
            : ValidationError.invalidEmail),
    asyncValidation: const AsyncValidation(validator: _checkEmailTaken),
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

/// Step 2. Picking another country clears the city, through the form's
/// `addRelation` — "when B changes, set A". The wizard reads the invoice switch
/// the same way, one level up.
class AddressStepController extends WizardStepController {
  AddressStepController() {
    registerFields([country, city, needsInvoice]);
    addRelation(country, (value) => value, (_) => city.reset());
  }

  @override
  String get title => 'Address';

  final country = AdvancedSingleSelectFieldController<Country, ValidationError>(
    initialValue: null,
    options: Country.values,
    validator: notNull(ValidationError.empty),
  );

  final city = AdvancedTextFieldController(
    validator: filled(ValidationError.empty),
  );

  final needsInvoice = AdvancedBooleanFieldController<ValidationError>();
}

/// Step 3, conditional. Nothing here knows about the condition: it is an
/// ordinary subform that the wizard switches off.
class InvoiceStepController extends WizardStepController {
  InvoiceStepController() {
    registerFields([companyName, taxId]);
  }

  @override
  String get title => 'Invoice';

  final companyName = AdvancedTextFieldController(
    validator: filled(ValidationError.empty),
  );

  final taxId = AdvancedTextFieldController(
    validator: filled(ValidationError.empty) &
        atLeastLength(10, ValidationError.toShort),
  );
}

/// Step 4. A boolean field has no built-in validator, so the rule is a one-line
/// closure.
class ConfirmStepController extends WizardStepController {
  ConfirmStepController() {
    registerFields([newsletter, acceptTerms]);
  }

  @override
  String get title => 'Confirm';

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
