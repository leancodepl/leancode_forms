import 'package:advanced_forms/advanced_forms.dart';
import 'package:advanced_forms_example/main.dart';
import 'package:advanced_forms_example/screens/step_form.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

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

  test('next does not advance while the current step is invalid', () async {
    final controller = buildController();

    await expectLater(controller.next(), completion(isFalse));

    expect(controller.currentStep.value, 0);
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
    expect(controller.currentStep.value, 0);
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

    expect(controller.currentStep.value, 1);
  });

  test('submit validates every step and returns to the first invalid one',
      () async {
    final controller = buildController();

    await fillAccountStep(controller);

    await expectLater(controller.submit(), completion(isFalse));

    // The user never reached step 2, but submit checks the whole tree.
    expect(controller.address.country.value.error, ValidationError.empty);
    expect(controller.currentStep.value, 1);
  });

  test('submit succeeds once every step is valid', () async {
    final controller = buildController();

    await fillAccountStep(controller);
    controller.address.country.select(Country.poland);
    controller.address.city.setValue('Wrocław');
    controller.confirm.acceptTerms.setValue(true);

    await expectLater(controller.submit(), completion(isTrue));
  });

  test('changing the country clears the city', () async {
    final controller = buildController();

    controller.address.country.select(Country.poland);
    controller.address.city.setValue('Wrocław');

    controller.address.country.select(Country.spain);

    expect(controller.address.city.value.value, '');
  });

  testWidgets('the screen renders and Next reports the errors it found',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: StepFormScreen()),
    );

    expect(find.text('Account'), findsOneWidget);

    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();

    expect(find.text('This value is required'), findsWidgets);
  });
}
