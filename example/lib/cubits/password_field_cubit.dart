import 'package:leancode_forms/leancode_forms.dart';
import 'package:leancode_forms_example/main.dart';

/// A specialization of [FieldCubit] for a password field.
class PasswordFieldCubit extends FieldCubit<String, List<ValidationError>> {
  /// Creates a new [PasswordFieldCubit].
  PasswordFieldCubit({
    super.initialValue = '',
    this.minLength = 8,
    this.numberRequired = false,
    this.specialCharRequired = false,
    this.upperCaseRequired = false,
    this.lowerCaseRequired = false,
    super.asyncValidator,
    super.asyncValidatorsDebounceTime,
  }) : super(
          validator: (value) {
            final errors = <ValidationError>[];

            if (value.isEmpty) {
              errors.add(ValidationError.empty);
            }

            if (value.length < minLength) {
              errors.add(ValidationError.toShort);
            }

            if (numberRequired && !value.contains(RegExp('[0-9]'))) {
              errors.add(ValidationError.noNumber);
            }

            if (specialCharRequired &&
                !value.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) {
              errors.add(ValidationError.noSpecialChar);
            }

            if (upperCaseRequired && !value.contains(RegExp('[A-Z]'))) {
              errors.add(ValidationError.noUpperCase);
            }

            if (lowerCaseRequired && !value.contains(RegExp('[a-z]'))) {
              errors.add(ValidationError.noLowerCase);
            }

            return errors.isEmpty ? null : errors;
          },
        );

  /// The minimum length of the password. Defaults to 8.
  final int minLength;

  /// Whether or not a number is required. Defaults to false.
  final bool numberRequired;

  /// Whether or not a special character is required. Defaults to false.
  final bool specialCharRequired;

  /// Whether or not a lower case character is required. Defaults to false.
  final bool upperCaseRequired;

  /// Whether or not an upper case character is required. Defaults to false.
  final bool lowerCaseRequired;
}
