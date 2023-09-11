import 'package:leancode_forms/src/field/cubit/field_cubit.dart';

/// A specialization of [FieldCubit] for a [bool] value.
class BooleanFieldCubit<E extends Object> extends FieldCubit<bool, E> {
  /// Creates a new [BooleanFieldCubit].
  BooleanFieldCubit({
    super.initialValue = false,
    super.validator,
    this.requiredTrue = false,
  });

  /// Toggles the value of the field.
  void toggle() => setValue(!state.value);

  /// Whether the field is required to be true to be valid.
  final bool requiredTrue;
}
