import 'package:leancode_forms/src/field/advanced_field_controller.dart';

/// A specialization of [AdvancedFieldController] for a multiple choice of [V] values.
class AdvancedMultiSelectFieldController<V, E extends Object>
    extends AdvancedFieldController<Set<V>, E> {
  /// Creates a new [AdvancedMultiSelectFieldController].
  AdvancedMultiSelectFieldController({
    required Set<V> initialValue,
    super.validator,
    super.asyncValidation,
    super.focusNode,
    required List<V> options,
    super.name,
  })  : options = List.of(options),
        super(initialValue: Set.of(initialValue));

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
  ///
  /// The [value] must be one of [options].
  void addValue(V value) {
    assert(
      options.contains(value),
      'Cannot add $value because it is not one of the available options.',
    );
    setValue({...fieldValue}..add(value));
  }

  /// Removes the given [value].
  void removeValue(V value) {
    setValue({...fieldValue}..remove(value));
  }
}
