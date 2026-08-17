import 'package:advanced_forms/src/field/advanced_field_controller.dart';

/// A specialization of [AdvancedFieldController] for a single choice of [V] from a
/// list of [options].
class AdvancedSingleSelectFieldController<V, E extends Object>
    extends AdvancedFieldController<V?, E> {
  /// Creates a new [AdvancedSingleSelectFieldController].
  AdvancedSingleSelectFieldController({
    required super.initialValue,
    super.validator,
    super.asyncValidation,
    super.focusNode,
    required this.options,
    super.name,
  });

  /// List of options to select from.
  final List<V> options;

  /// Sets the value of the field to the [option].
  ///
  /// The [option] must be `null` (to clear the selection) or one of [options].
  void select(V? option) {
    assert(
      option == null || options.contains(option),
      'Cannot select $option because it is not one of the available options.',
    );
    setValue(option);
  }
}
