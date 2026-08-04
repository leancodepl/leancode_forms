import 'package:leancode_forms/src/field/advanced_field_controller.dart';

/// A specialization of [AdvancedFieldController] for a multiple choice of [V] values.
class AdvancedMultiSelectFieldController<V, E extends Object>
    extends AdvancedFieldController<Set<V>, E> {
  /// Creates a new [AdvancedMultiSelectFieldController].
  AdvancedMultiSelectFieldController({
    required super.initialValue,
    super.validator,
    required this.options,
    super.name,
  });

  /// List of options to select from.
  final List<V> options;

  /// Toggles the given [value].
  void toggleElement(V value) {
    if (fieldValue.contains(value)) {
      removeValue(value);
    } else {
      addValue(value);
    }
  }

  /// Adds the given [value].
  void addValue(V value) {
    setValue({...fieldValue}..add(value));
  }

  /// Removes the given [value].
  void removeValue(V value) {
    setValue({...fieldValue}..remove(value));
  }
}
