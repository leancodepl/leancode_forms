import 'package:leancode_forms/src/field/cubit/field_cubit.dart';

/// A specialization of [FieldCubit] for a single choice of [V] value from List of [options].
class SingleSelectFieldCubit<V, E extends Object> extends FieldCubit<V?, E> {
  /// Creates a new [SingleSelectFieldCubit].
  SingleSelectFieldCubit({
    required super.initialValue,
    super.validator,
    required this.options,
  });

  /// List of options to select from.
  final List<V> options;

  /// Sets the value of the field to the [option].
  void select(V? option) => setValue(option);

  /// Resets selected value to the initial one.
  void clear() => reset();
}
