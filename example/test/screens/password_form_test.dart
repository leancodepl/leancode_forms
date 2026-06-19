import 'package:flutter_test/flutter_test.dart';
import 'package:leancode_forms_example/main.dart';
import 'package:leancode_forms_example/screens/password_form.dart';

void main() {
  test('sets error in repeatPassword when passwords do not match', () {
    final controller = PasswordFormController();
    addTearDown(controller.dispose);

    controller.password.setValue('Password!1');
    controller.repeatPassword.setValue('1234567');
    controller.validate();

    expect(controller.password.value.error, null);
    expect(controller.repeatPassword.value.error, ValidationError.doesNotMatch);
  });
}
