import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:leancode_forms/src/field/cubit/field_cubit.dart';

enum _Error {
  malformed,
  valueRequired,
}

class _ValidatorMock {
  _Error? validationResult;

  _Error? call(int? value) => validationResult;
}

const _initialValue = 0;

typedef _FieldCubit = FieldCubit<int, _Error>;
typedef _FieldState = FieldState<int, _Error>;

void main() {
  late FieldCubit<int, _Error> cubit;
  late _ValidatorMock validator;

  setUp(() {
    validator = _ValidatorMock();
    cubit = FieldCubit(initialValue: _initialValue, validator: validator);
  });

  tearDown(() async {
    await cubit.close();
  });

  group('setValue', () {
    blocTest<_FieldCubit, _FieldState>(
      'updates the value',
      build: () => cubit,
      act: (cubit) => cubit.setValue(10),
      expect: () => const [
        _FieldState(value: 10),
      ],
    );

    blocTest<_FieldCubit, _FieldState>(
      'does not update error if autovalidate is off',
      setUp: () {
        validator.validationResult = _Error.malformed;
      },
      build: () => cubit,
      act: (cubit) => cubit.setValue(10),
      expect: () => const [
        _FieldState(value: 10),
      ],
    );

    blocTest<_FieldCubit, _FieldState>(
      'updates error if autovalidate is on',
      setUp: () {
        cubit.setAutovalidate(true);
        validator.validationResult = _Error.malformed;
      },
      build: () => cubit,
      act: (cubit) => cubit.setValue(10),
      expect: () => const [
        _FieldState(
          value: 10,
          validationError: _Error.malformed,
          autovalidate: true,
          status: FieldStatus.invalid,
        ),
      ],
    );

    blocTest<_FieldCubit, _FieldState>(
      'does not update the value when field is readonly',
      build: () => cubit,
      setUp: () {
        cubit.markReadOnly();
      },
      act: (cubit) {
        cubit.setValue(10);
      },
      expect: () => const <dynamic>[],
    );

    blocTest<_FieldCubit, _FieldState>(
      'updates the value when field is readonly and force is true',
      build: () => cubit,
      setUp: () {
        cubit.markReadOnly();
      },
      act: (cubit) {
        cubit.setValue(10, force: true);
      },
      expect: () => const [
        _FieldState(
          value: 10,
          readOnly: true,
        ),
      ],
    );
  });

  group('reset', () {
    blocTest<_FieldCubit, _FieldState>(
      'resets state to initial state',
      build: () => cubit,
      seed: () => const _FieldState(
        value: 10,
        validationError: _Error.malformed,
        asyncError: _Error.malformed,
        autovalidate: true,
        readOnly: true,
        status: FieldStatus.invalid,
      ),
      act: (cubit) => cubit.reset(),
      expect: () => const [
        _FieldState(value: 0),
      ],
    );

    group('clearErrors', () {
      blocTest<_FieldCubit, _FieldState>(
        'clears validationError and asyncError. Sets status to valid',
        build: () => cubit,
        seed: () => const _FieldState(
          value: 1,
          validationError: _Error.valueRequired,
          asyncError: _Error.malformed,
        ),
        act: (cubit) => cubit.clearErrors(),
        expect: () => const [
          _FieldState(value: 1),
        ],
      );

      blocTest<_FieldCubit, _FieldState>(
        'does nothing if errors were not present',
        build: () => cubit,
        seed: () => const _FieldState(value: 1),
        act: (cubit) => cubit.clearErrors(),
        expect: () => const <dynamic>[],
      );
    });

    group('validate', () {
      test('when is valid', () {
        validator.validationResult = null;
        final validationResult = cubit.validate();

        expect(validationResult, true);
        expect(cubit.state, const _FieldState(value: _initialValue));
        expect(cubit.state.isValid, true);
      });

      test('when is not valid', () {
        validator.validationResult = _Error.malformed;
        final validationResult = cubit.validate();

        expect(validationResult, false);
        expect(
          cubit.state,
          const _FieldState(
            value: _initialValue,
            validationError: _Error.malformed,
            status: FieldStatus.invalid,
          ),
        );
        expect(cubit.state.isValid, false);
      });

      blocTest<_FieldCubit, _FieldState>(
        'when validation result is the same as previous, does not emit new state',
        setUp: () {
          validator.validationResult = _Error.malformed;
        },
        build: () => cubit,
        seed: () => const _FieldState(
          value: 1,
          validationError: _Error.malformed,
          status: FieldStatus.invalid,
        ),
        act: (cubit) => cubit.validate(),
        expect: () => const <dynamic>[],
      );
    });

    group('getValueSetter', () {
      test('is null when field is readonly', () {
        cubit.markReadOnly();

        expect(cubit.getValueSetter(), null);
      });

      test('is setValue when field is not readonly', () {
        expect(cubit.getValueSetter(), cubit.setValue);
      });
    });

    group('async validation', () {
      setUp(() {
        cubit = FieldCubit(
          initialValue: _initialValue,
          asyncValidator: (value) async {
            await Future<void>.delayed(const Duration(milliseconds: 100));
            return validator.validationResult;
          },
        );
      });

      blocTest<_FieldCubit, _FieldState>(
        'should emit pending and validating states when async validating the field',
        build: () => cubit,
        act: (cubit) async {
          cubit.setValue(10);
        },
        setUp: () {
          validator.validationResult = _Error.malformed;
        },
        wait: const Duration(milliseconds: 600),
        expect: () => const <dynamic>[
          _FieldState(
            value: 10,
            status: FieldStatus.pending,
          ),
          _FieldState(
            value: 10,
            status: FieldStatus.validating,
          ),
          _FieldState(
            value: 10,
            status: FieldStatus.invalid,
            asyncError: _Error.malformed,
          ),
        ],
      );

      blocTest<_FieldCubit, _FieldState>(
        'should restart async validation when value changes while pending',
        build: () => cubit,
        act: (cubit) async {
          cubit.setValue(10);
          await Future<void>.delayed(const Duration(milliseconds: 150));
          cubit.setValue(20);
        },
        wait: const Duration(milliseconds: 600),
        setUp: () {
          validator.validationResult = _Error.malformed;
        },
        expect: () => const <dynamic>[
          _FieldState(
            value: 10,
            status: FieldStatus.pending,
          ),
          _FieldState(
            value: 20,
            status: FieldStatus.pending,
          ),
          _FieldState(
            value: 20,
            status: FieldStatus.validating,
          ),
          _FieldState(
            value: 20,
            status: FieldStatus.invalid,
            asyncError: _Error.malformed,
          ),
        ],
      );

      blocTest<_FieldCubit, _FieldState>(
        'should restart async validation when value changes while validating',
        build: () => cubit,
        act: (cubit) async {
          cubit.setValue(10);
          await Future<void>.delayed(const Duration(milliseconds: 300));
          cubit.setValue(20);
        },
        wait: const Duration(milliseconds: 600),
        setUp: () {
          validator.validationResult = _Error.malformed;
        },
        expect: () => const <dynamic>[
          _FieldState(
            value: 10,
            status: FieldStatus.pending,
          ),
          _FieldState(
            value: 10,
            status: FieldStatus.validating,
          ),
          _FieldState(
            value: 20,
            status: FieldStatus.pending,
          ),
          _FieldState(
            value: 20,
            status: FieldStatus.validating,
          ),
          _FieldState(
            value: 20,
            status: FieldStatus.invalid,
            asyncError: _Error.malformed,
          ),
        ],
      );
    });

    group('setError', () {
      blocTest<_FieldCubit, _FieldState>(
        'sets error and changes field status to invalid',
        build: () => cubit,
        act: (cubit) => cubit.setError(_Error.malformed),
        expect: () => const [
          _FieldState(
            value: _initialValue,
            validationError: _Error.malformed,
            status: FieldStatus.invalid,
          ),
        ],
      );
    });
  });
}
