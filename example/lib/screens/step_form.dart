import 'package:advanced_forms/advanced_forms.dart';
import 'package:advanced_forms_example/main.dart';
import 'package:advanced_forms_example/screens/form_page.dart';
import 'package:advanced_forms_example/widgets/form_dropdown_field.dart';
import 'package:advanced_forms_example/widgets/form_switch_field.dart';
import 'package:advanced_forms_example/widgets/form_text_field.dart';
import 'package:advanced_forms_example/widgets/screen_description.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// A wizard whose steps are separate pages, validated one page at a time.
///
/// The pattern in four lines:
///
/// * **One controller above the pages.** The wizard is provided once, over the
///   `PageView`, and every page reads its own step out of it. No page creates
///   or disposes a controller, so walking back and forth loses nothing. A
///   wizard built from pushed routes works the same way — see the note on
///   [StepFormScreen].
/// * **Next** runs `await step.validate()` on the current page's subform only,
///   so a field on a later page is never flagged before the user gets there.
/// * **Submit** runs `await validate()` on the parent, which reaches every
///   attached subform — a page the user walked back over is checked again.
/// * A **skipped page** stays attached and gets `setValidationEnabled(false)`.
///   One flag then drives both things a skip means: the navigation walks past
///   it, and its fields stop counting towards the parent.
///
/// With pushed routes instead of a `PageView`, only the plumbing changes: the
/// wizard is created above the `Navigator` that hosts the steps (or handed to
/// each route with `ChangeNotifierProvider.value`), never inside a step page —
/// a controller created per page would be disposed on every pop, taking that
/// step's values and errors with it.
class StepFormScreen extends StatelessWidget {
  const StepFormScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // The one owner of the wizard: `provider` disposes it, and that one call
    // disposes every step subform and every field on them.
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
    // The wizard decides which step is current; the PageView follows it. The
    // page can never move on its own — its physics forbid swiping — so this is
    // a one-way sync.
    _form.currentStep.addListener(_showCurrentStep);
  }

  @override
  void dispose() {
    _form.currentStep.removeListener(_showCurrentStep);
    _pageController.dispose();
    super.dispose();
  }

  void _showCurrentStep() {
    if (!_pageController.hasClients) {
      return;
    }
    _pageController.animateToPage(
      _form.currentStepIndex,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
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
            plain(', and the wizard that owns them all is provided above the '),
            code('PageView'),
            plain(' — so no page owns a controller and walking back loses '
                'nothing. '),
            bold('Next'),
            plain(' validates only the current page — including its async '
                'checks — while later pages stay quiet. A page that fails once '
                'switches to '),
            code('ValidationMode.onUserInteraction'),
            plain(', so it then corrects itself as you type. '),
            bold('Submit'),
            plain(' validates the whole tree and returns to the first page '
                'that still has an error. The '),
            bold('Invoice'),
            plain(' page is conditional: leave the switch on Address off and '
                'the wizard walks straight to Confirm, because '),
            code('setValidationEnabled(false)'),
            plain(' takes that page out of the navigation and out of '),
            code('validate()'),
            plain('. Try '),
            code('john@email.com'),
            plain(' to see Next wait for the async check.'),
          ]),
          const _WizardProgress(),
          Expanded(
            child: ValueListenableBuilder<List<WizardStepController>>(
              valueListenable: _form.activeSteps,
              builder: (context, steps, _) => PageView(
                controller: _pageController,
                // Next is the only way forward: it is what validates.
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  for (final step in steps) _StepPage(step: step),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Where the user is in the flow. Reads the same two notifiers the navigation
/// does, so a page joining or leaving the flow is reflected here too.
class _WizardProgress extends StatelessWidget {
  const _WizardProgress();

  @override
  Widget build(BuildContext context) {
    final form = context.read<StepFormController>();

    return ValueListenableBuilder<List<WizardStepController>>(
      valueListenable: form.activeSteps,
      builder: (context, steps, _) => ValueListenableBuilder<int>(
        valueListenable: form.currentStep,
        builder: (context, _, __) {
          final position = form.currentStepIndex;

          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Step ${position + 1} of ${steps.length} — '
                  '${form.currentStepController.title}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: (position + 1) / steps.length,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// One page of the wizard: the step's fields, then its controls.
class _StepPage extends StatelessWidget {
  const _StepPage({required this.step});

  final WizardStepController step;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: [
          _StepContent(step: step),
          const _StepControls(),
        ],
      ),
    );
  }
}

class _StepContent extends StatelessWidget {
  const _StepContent({required this.step});

  final WizardStepController step;

  @override
  Widget build(BuildContext context) {
    return switch (step) {
      final AccountStepController step => _AccountStep(controller: step),
      final AddressStepController step => _AddressStep(controller: step),
      final InvoiceStepController step => _InvoiceStep(controller: step),
      final ConfirmStepController step => _ConfirmStep(controller: step),
      _ => const SizedBox.shrink(),
    };
  }
}

/// Back / Next on every page, Back / Submit on the last one.
class _StepControls extends StatelessWidget {
  const _StepControls();

  @override
  Widget build(BuildContext context) {
    final controller = context.read<StepFormController>();

    return Padding(
      padding: const EdgeInsets.only(top: 16),
      // Whether this is the last page depends on both the position and the
      // page list, so the controls subscribe to the same two notifiers.
      child: ValueListenableBuilder<List<WizardStepController>>(
        valueListenable: controller.activeSteps,
        builder: (context, _, __) => ValueListenableBuilder<int>(
          valueListenable: controller.currentStep,
          builder: (context, _, __) => Row(
            children: [
              if (!controller.isFirstStep)
                TextButton(
                  onPressed: controller.back,
                  child: const Text('Back'),
                ),
              const Spacer(),
              if (controller.isLastStep)
                const _SubmitButton()
              else
                // `next()` awaits the step's async checks, so the button has
                // to await it too — never pass it as a bare VoidCallback.
                ElevatedButton(
                  onPressed: () async => controller.next(),
                  child: const Text('Next'),
                ),
            ],
          ),
        ),
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
        // The decision that adds or drops the Invoice step. It is an ordinary
        // field: the wizard watches it with `addRelation`.
        FormSwitchField(
          field: controller.needsInvoice,
          labelText: 'I need a VAT invoice',
        ),
      ],
    );
  }
}

class _InvoiceStep extends StatelessWidget {
  const _InvoiceStep({required this.controller});

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

/// One step of the wizard. Only the title is common — everything else is an
/// ordinary [AdvancedFormController].
abstract class WizardStepController extends AdvancedFormController {
  String get title;
}

/// The wizard. It owns no fields of its own — every field lives on a step.
class StepFormController extends AdvancedFormController {
  StepFormController() {
    steps.forEach(addSubform);

    // The switch on the Address step decides whether the Invoice step is part
    // of the flow. Keeping that step attached and only switching its validation
    // off is what makes the skip reversible: its values, its registered fields
    // and its disposal all stay with the wizard, and turning it back on
    // re-validates only the fields the user had already edited.
    //
    // `addRelation` fires on a value change only, so the initial state is
    // seeded by hand right after.
    addRelation(
      address.needsInvoice,
      (value) => value,
      _setInvoiceStepEnabled,
    );
    _setInvoiceStepEnabled(address.needsInvoice.fieldValue);
  }

  final account = AccountStepController();
  final address = AddressStepController();
  final invoice = InvoiceStepController();
  final confirm = ConfirmStepController();

  late final List<WizardStepController> steps = [
    account,
    address,
    invoice,
    confirm,
  ];

  /// Which step is on screen, as an index into [steps] — stable across a step
  /// joining or leaving the flow. Navigation is the app's state, never the
  /// package's, so it is a plain notifier — exposed read-only, because only
  /// [next], [back] and [goTo] may move the wizard.
  ValueListenable<int> get currentStep => _currentStep;
  final _currentStep = ValueNotifier(0);

  /// Whether the save call is in flight.
  ///
  /// [AdvancedFormState.validating] is not this flag: it covers async
  /// *validators*, and the package knows nothing about the call in [submit].
  /// Both matter — a spinner on a field while its check runs, this one on the
  /// submit button while the request is out.
  ValueListenable<bool> get isSubmitting => _isSubmitting;
  final _isSubmitting = ValueNotifier(false);

  /// The steps the user actually walks through. A step switched off with
  /// `setValidationEnabled(false)` is out of the flow *and* out of `validate()`,
  /// `canSubmit` and `validating`, so this one flag is the whole condition.
  ValueListenable<List<WizardStepController>> get activeSteps => _activeSteps;
  final _activeSteps = ValueNotifier<List<WizardStepController>>([]);

  WizardStepController get currentStepController => steps[_currentStep.value];

  /// The position of the current step among [activeSteps] — the page the
  /// `PageView` shows.
  int get currentStepIndex => _activeSteps.value.indexOf(currentStepController);

  bool get isFirstStep => currentStepIndex == 0;

  bool get isLastStep => currentStepIndex == _activeSteps.value.length - 1;

  /// Validates the current step and moves on if it passed.
  ///
  /// A subform's `validate()` reaches its own fields only, which is what makes
  /// per-step validation one line.
  Future<bool> next() async {
    final step = currentStepController;

    if (!await step.validate()) {
      // The step has now shown its errors once, so let it keep itself current
      // as the user fixes them. A step's own mode wins over the parent's, so
      // the steps ahead stay quiet.
      step.setValidationMode(ValidationMode.onUserInteraction);
      return false;
    }

    _move(1);
    return true;
  }

  void back() => _move(-1);

  void goTo(WizardStepController step) {
    final index = steps.indexOf(step);
    if (index != -1 && step.value.validationEnabled) {
      _currentStep.value = index;
    }
  }

  Future<bool> submit() async {
    if (_isSubmitting.value) {
      return false;
    }
    // Set before the first `await`, or a double tap sends two requests.
    _isSubmitting.value = true;
    try {
      // The parent walks every attached subform, so this covers the steps the
      // user already passed as well as the one on screen. A skipped step is
      // switched off, so it returns true without running.
      if (!await validate()) {
        _goToFirstInvalidStep();
        return false;
      }

      // Stands in for the save call.
      await Future<void>.delayed(const Duration(milliseconds: 500));
      return true;
    } finally {
      _isSubmitting.value = false;
    }
  }

  /// Walks [delta] steps through [activeSteps], so a skipped step is passed
  /// over in both directions.
  void _move(int delta) {
    final active = _activeSteps.value;
    final target = currentStepIndex + delta;
    if (target >= 0 && target < active.length) {
      goTo(active[target]);
    }
  }

  void _goToFirstInvalidStep() {
    // `validate()` has just run, so every error is recorded and `canSubmit` is
    // an accurate snapshot here.
    final step = _activeSteps.value.firstWhere(
      (step) => !step.value.canSubmit,
      orElse: () => currentStepController,
    )..setValidationMode(ValidationMode.onUserInteraction);
    goTo(step);
  }

  /// Adds the Invoice step to the flow, or drops it out of it.
  ///
  /// The step stays attached either way — only its validation is switched — so
  /// the flow list is recomputed here rather than read from the tree on every
  /// build. That also makes it a [ValueListenable] the UI can subscribe to.
  void _setInvoiceStepEnabled(bool enabled) {
    invoice.setValidationEnabled(enabled);
    _activeSteps.value = [
      for (final step in steps)
        if (step.value.validationEnabled) step,
    ];

    // The user is never standing on a step as it leaves the flow — the switch
    // lives on an earlier one — but a wizard that grows more conditions would
    // land here, so fall back to the nearest step still in the flow.
    if (!currentStepController.value.validationEnabled) {
      goTo(
        _activeSteps.value.lastWhere(
          (step) => steps.indexOf(step) < _currentStep.value,
          orElse: () => _activeSteps.value.first,
        ),
      );
    }
  }

  @override
  void dispose() {
    // Our own objects first, then the superclass — which disposes the four
    // step subforms and every field on them.
    _activeSteps.dispose();
    _currentStep.dispose();
    _isSubmitting.dispose();
    super.dispose();
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
/// `addRelation` — "when B changes, set A". The invoice switch is read the same
/// way, one level up, by the wizard.
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

/// Step 3, conditional. Nothing here knows about the condition: the step is an
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
