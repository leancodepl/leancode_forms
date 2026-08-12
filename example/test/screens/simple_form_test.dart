import 'package:flutter_test/flutter_test.dart';
import 'package:leancode_forms_example/main.dart';
import 'package:leancode_forms_example/screens/simple_form.dart';

void main() {
  test('sets email when setValue is called', () {
    final controller = SimpleFormController();
    addTearDown(controller.dispose);

    controller.email.setValue('john@email.com');

    expect(controller.email.value.value, 'john@email.com');
  });

  test('sets ValidationError.emailTaken when email is taken', () async {
    final controller = SimpleFormController();
    addTearDown(controller.dispose);

    controller.email.setValue('john@email.com');

    // The gate is closed on a fresh controller, so setValue stores the value
    // and runs nothing. `validate()` is what reaches the async check — and
    // awaiting it beats sleeping for a fixed duration.
    await expectLater(controller.email.validate(), completion(isFalse));

    expect(controller.email.value.error, ValidationError.emailTaken);
  });

  test('has no errors before submit is invoked', () {
    final controller = SimpleFormController();
    addTearDown(controller.dispose);

    expect(controller.email.value.error, null);
    expect(controller.firstName.value.error, null);
    expect(controller.lastName.value.error, null);
  });

  test('validate flags only empty fields as invalid', () {
    final controller = SimpleFormController();
    addTearDown(controller.dispose);

    controller.validate();

    // email defaults to '' so it fails `filled`; firstName/lastName have
    // non-empty initial values so they pass.
    expect(controller.email.value.error, ValidationError.empty);
    expect(controller.firstName.value.error, null);
    expect(controller.lastName.value.error, null);
  });
}
