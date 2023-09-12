import 'package:leancode_forms/src/field/cubit/field_cubit.dart';

/// A specialization of [FieldCubit] for a single choice of [V] value.
class SingleSelectFieldCubit<V, E extends Object> extends FieldCubit<V?, E> {
  /// Creates a new [SingleSelectFieldCubit].
  SingleSelectFieldCubit({
    required super.initialValue,
    super.validator,
    super.asyncValidator,
    super.asyncValidatorsDebounceTime,
    required this.options,
  });

  /// List of options to select from.
  final List<V> options;

  /// Sets the value of the field to the [option].
  void select(V? option) => setValue(option);

  /// Clears the value of the field.
  void clear() => setValue(null);
}
