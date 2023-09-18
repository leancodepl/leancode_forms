import 'package:leancode_forms/src/field/cubit/field_cubit.dart';

/// A specialization of [FieldCubit] for a multiple choice of [V] values.
class MultiSelectFieldCubit<V, E extends Object> extends FieldCubit<Set<V>, E> {
  /// Creates a new [MultiSelectFieldCubit].
  MultiSelectFieldCubit({
    required super.initialValue,
    super.validator,
    required this.options,
  });

  /// List of options to select from.
  final List<V> options;

  /// Toggles the given [value].
  void toggleElement(V value) {
    if (state.value.contains(value)) {
      removeValue(value);
    } else {
      addValue(value);
    }
  }

  /// Adds the given [value].
  void addValue(V value) {
    setValue(Set<V>.from(state.value)..add(value));
  }

  /// Removes the given [value].
  void removeValue(V value) {
    setValue(Set<V>.from(state.value)..remove(value));
  }

  /// Deselects all values.
  void clear() => reset();
}
