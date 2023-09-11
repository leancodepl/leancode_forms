import 'package:leancode_forms/src/field/cubit/field_cubit.dart';

/// A specialization of [FieldCubit] for a [String] value.
class TextFieldCubit<E extends Object> extends FieldCubit<String, E> {
  /// Creates a new [TextFieldCubit].
  TextFieldCubit({
    super.initialValue = '',
    super.validator,
    super.asyncValidator,
    super.asyncValidatorsDebounceTime,
  });

  /// Clears the value of the field.
  void clear() => setValue('');
}
