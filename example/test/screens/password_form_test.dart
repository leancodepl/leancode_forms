import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:leancode_forms/leancode_forms.dart';
import 'package:leancode_forms_example/main.dart';
import 'package:leancode_forms_example/screens/password_form.dart';

void main() {
  blocTest<PasswordSubformCubit, FormGroupState>(
    'sets error in repeatPassword field when passwords do not match',
    build: PasswordSubformCubit.new,
    act: (cubit) {
      cubit.password.setValue('Password!1');
      cubit.repeatPassword.setValue('1234567');
      cubit.validate();
    },
    verify: (cubit) {
      expect(cubit.password.state.error, null);
      expect(cubit.repeatPassword.state.error, ValidationError.doesNotMatch);
    },
  );
}
