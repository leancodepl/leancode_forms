import 'package:advanced_forms/advanced_forms.dart';
import 'package:advanced_forms_example/main.dart';
import 'package:advanced_forms_example/screens/step_form.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  StepFormController buildController() {
    final controller = StepFormController();
    addTearDown(controller.dispose);
    return controller;
  }

  Future<void> fillAccountStep(StepFormController controller) async {
    controller.account.email.setValue('jane@email.com');
    controller.account.password.setValue('supersecret');
    await controller.next();
  }

  Future<void> fillAddressStep(
    StepFormController controller, {
    bool needsInvoice = false,
  }) async {
    controller.address.country.select(Country.poland);
    controller.address.city.setValue('Wrocław');
    controller.address.needsInvoice.setValue(needsInvoice);
    await controller.next();
  }

  void fillInvoiceStep(StepFormController controller) {
    controller.invoice.companyName.setValue('LeanCode');
    controller.invoice.taxId.setValue('PL1234567890');
  }

  test('next does not advance while the current step is invalid', () async {
    final controller = buildController();

    await expectLater(controller.next(), completion(isFalse));

    expect(controller.currentStepController, controller.account);
    expect(controller.account.email.value.error, ValidationError.empty);
  });

  test('next validates the current step only', () async {
    final controller = buildController();

    await controller.next();

    // Step 2 and 3 are attached subforms, but a subform's validate() reaches
    // its own fields only — so nothing on them was touched.
    expect(controller.address.country.value.error, null);
    expect(controller.address.city.value.error, null);
    expect(controller.confirm.acceptTerms.value.error, null);
  });

  test('next awaits the async email check and blocks on a taken email',
      () async {
    final controller = buildController();

    controller.account.email.setValue('john@email.com');
    controller.account.password.setValue('supersecret');

    await expectLater(controller.next(), completion(isFalse));

    expect(controller.account.email.value.error, ValidationError.emailTaken);
    expect(controller.currentStepController, controller.account);
  });

  test('a step that failed once switches to live feedback', () async {
    final controller = buildController();

    await controller.next();
    expect(
      controller.account.value.validationMode,
      ValidationMode.onUserInteraction,
    );

    // Later steps keep the wizard's own mode, so they stay quiet.
    expect(controller.confirm.value.validationMode, ValidationMode.manual);
  });

  test('next advances once the step passes', () async {
    final controller = buildController();

    await fillAccountStep(controller);

    expect(controller.currentStepController, controller.address);
  });

  test('submit validates every step and returns to the first invalid one',
      () async {
    final controller = buildController();

    await fillAccountStep(controller);

    await expectLater(controller.submit(), completion(isFalse));

    // The user never reached step 2, but submit checks the whole tree.
    expect(controller.address.country.value.error, ValidationError.empty);
    expect(controller.currentStepController, controller.address);
  });

  test('submit succeeds once every step is valid', () async {
    final controller = buildController();

    await fillAccountStep(controller);
    await fillAddressStep(controller);
    controller.confirm.acceptTerms.setValue(true);

    await expectLater(controller.submit(), completion(isTrue));
  });

  test('the invoice step is out of the flow while the switch is off', () async {
    final controller = buildController();

    expect(controller.activeSteps.value, isNot(contains(controller.invoice)));

    await fillAccountStep(controller);
    await fillAddressStep(controller);

    // Next walked from Address straight past Invoice.
    expect(controller.currentStepController, controller.confirm);
  });

  test('a skipped step cannot block submit', () async {
    final controller = buildController();

    await fillAccountStep(controller);
    await fillAddressStep(controller);
    controller.confirm.acceptTerms.setValue(true);

    // The invoice fields are empty and never validated: the subtree is
    // switched off, so validate() skips it and canSubmit ignores it.
    await expectLater(controller.submit(), completion(isTrue));
    expect(controller.invoice.companyName.value.error, null);
  });

  test('the invoice step joins the flow when the switch goes on', () async {
    final controller = buildController();

    await fillAccountStep(controller);
    await fillAddressStep(controller, needsInvoice: true);

    expect(controller.activeSteps.value, contains(controller.invoice));
    expect(controller.currentStepController, controller.invoice);

    await expectLater(controller.next(), completion(isFalse));
    expect(controller.invoice.companyName.value.error, ValidationError.empty);
  });

  test('turning the switch back off clears the invoice errors', () async {
    final controller = buildController();

    await fillAccountStep(controller);
    await fillAddressStep(controller, needsInvoice: true);
    await controller.next();
    expect(controller.invoice.companyName.value.error, ValidationError.empty);

    controller.address.needsInvoice.setValue(false);

    expect(controller.invoice.companyName.value.error, null);
    expect(controller.activeSteps.value, isNot(contains(controller.invoice)));
  });

  test('the filled invoice step is submitted with the rest', () async {
    final controller = buildController();

    await fillAccountStep(controller);
    await fillAddressStep(controller, needsInvoice: true);
    fillInvoiceStep(controller);
    await controller.next();
    controller.confirm.acceptTerms.setValue(true);

    await expectLater(controller.submit(), completion(isTrue));
  });

  test('back walks past a skipped step too', () async {
    final controller = buildController();

    await fillAccountStep(controller);
    await fillAddressStep(controller);
    expect(controller.currentStepController, controller.confirm);

    controller.back();

    expect(controller.currentStepController, controller.address);
  });

  test('changing the country clears the city', () async {
    final controller = buildController();

    controller.address.country.select(Country.poland);
    controller.address.city.setValue('Wrocław');

    controller.address.country.select(Country.spain);

    expect(controller.address.city.value.value, '');
  });

  Future<StepFormController> pumpWizard(WidgetTester tester) async {
    final controller = StepFormController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: ChangeNotifierProvider<StepFormController>.value(
          value: controller,
          child: const StepForm(),
        ),
      ),
    );

    return controller;
  }

  // Never `await controller.next()` in a widget test: its async validator waits
  // on the fake clock, which only a pump advances. Tap and pump instead.
  Future<void> tapNext(WidgetTester tester) async {
    await tester.ensureVisible(find.text('Next'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Next'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
  }

  testWidgets('the first page renders and Next reports the errors it found',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: StepFormScreen()));

    expect(find.text('Step 1 of 3 — Account'), findsOneWidget);

    await tapNext(tester);

    expect(find.text('This value is required'), findsWidgets);
  });

  testWidgets('the conditional page joins the flow and is navigated to',
      (tester) async {
    final controller = await pumpWizard(tester);

    controller.address.needsInvoice.setValue(true);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Step 1 of 4 — Account'), findsOneWidget);

    controller.account.email.setValue('jane@email.com');
    controller.account.password.setValue('supersecret');
    await tapNext(tester);

    controller.address.country.select(Country.poland);
    controller.address.city.setValue('Wrocław');
    await tapNext(tester);

    // The PageView followed the wizard onto the page that just joined.
    expect(find.text('Step 3 of 4 — Invoice'), findsOneWidget);
    expect(find.text('Company name'), findsOneWidget);
  });

  testWidgets('a page keeps what the user typed while the flow changes',
      (tester) async {
    final controller = await pumpWizard(tester);

    controller.account.email.setValue('jane@email.com');
    controller.account.password.setValue('supersecret');
    await tapNext(tester);

    controller.address.country.select(Country.poland);
    controller.address.city.setValue('Wrocław');
    await tester.pumpAndSettle();

    // Adding a page rebuilds the PageView's children, so every field widget is
    // rebuilt from its controller — nothing lives in the widgets.
    controller.address.needsInvoice.setValue(true);
    await tester.pumpAndSettle();

    expect(controller.address.country.value.value, Country.poland);
    expect(find.text('Poland'), findsOneWidget);
    expect(find.text('Wrocław'), findsOneWidget);
  });

  testWidgets('walking back keeps the earlier page filled in', (tester) async {
    final controller = await pumpWizard(tester);

    controller.account.email.setValue('jane@email.com');
    controller.account.password.setValue('supersecret');
    await tapNext(tester);
    expect(find.text('Step 2 of 3 — Address'), findsOneWidget);

    await tester.ensureVisible(find.text('Back'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Back'));
    await tester.pumpAndSettle();

    // The page was rebuilt, not recreated: the wizard owns the controllers.
    expect(find.text('Step 1 of 3 — Account'), findsOneWidget);
    expect(find.text('jane@email.com'), findsOneWidget);
  });
}
