import 'package:leancode_forms/src/field/cubit/field_cubit.dart';

/// A specialization of [FieldCubit] for a single choice of [V] value.
class SingleSelectFieldCubit<V, E extends Object> extends FieldCubit<V, E> {
  /// Creates a new [SingleSelectFieldCubit].
  SingleSelectFieldCubit({
    required super.initialValue,
    super.validator,
    required this.options,
  });

  /// List of options to select from.
  final List<V> options;

  /// Selects the given [value].
  void selectValue(V value) => setValue(value);
}
