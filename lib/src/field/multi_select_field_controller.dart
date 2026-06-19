import 'package:leancode_forms/src/field/field_controller.dart';

/// A specialization of [FieldController] for a multiple choice of [V] values.
class MultiSelectFieldController<V, E extends Object>
    extends FieldController<Set<V>, E> {
  /// Creates a new [MultiSelectFieldController].
  MultiSelectFieldController({
    required super.initialValue,
    super.validator,
    required this.options,
    super.name,
  });

  /// List of options to select from.
  final List<V> options;

  /// Toggles the given [value].
  void toggleElement(V value) {
    if (this.value.value.contains(value)) {
      removeValue(value);
    } else {
      addValue(value);
    }
  }

  /// Adds the given [value].
  void addValue(V value) {
    setValue(Set<V>.from(this.value.value)..add(value));
  }

  /// Removes the given [value].
  void removeValue(V value) {
    setValue(Set<V>.from(this.value.value)..remove(value));
  }

  /// Resets selected values to the initial value.
  void clear() => reset();
}
