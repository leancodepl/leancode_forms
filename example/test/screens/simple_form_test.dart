import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:leancode_forms/leancode_forms.dart';
import 'package:leancode_forms_example/main.dart';
import 'package:leancode_forms_example/screens/simple_form.dart';

void main() {
  blocTest<SimpleFormCubit, FormGroupState>(
    'sets email when setValue is called',
    build: SimpleFormCubit.new,
    act: (bloc) => bloc.email.setValue('john@email.com'),
    verify: (bloc) {
      expect(bloc.email.state.value, 'john@email.com');
    },
  );

  blocTest<SimpleFormCubit, FormGroupState>(
    'sets 1',
    build: SimpleFormCubit.new,
    act: (bloc) => bloc.email.setValue('john@email.com'),
    verify: (bloc) async {
      await Future<void>.delayed(const Duration(milliseconds: 500));
      expect(bloc.email.state.error, ValidationError.invalidEmail);
    },
  );
}
