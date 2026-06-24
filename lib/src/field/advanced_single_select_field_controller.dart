import 'package:leancode_forms/src/field/advanced_field_controller.dart';

/// A specialization of [AdvancedFieldController] for a single choice of [V] from a
/// list of [options].
class AdvancedSingleSelectFieldController<V, E extends Object>
    extends AdvancedFieldController<V?, E> {
  /// Creates a new [AdvancedSingleSelectFieldController].
  AdvancedSingleSelectFieldController({
    required super.initialValue,
    super.validator,
    required this.options,
    super.name,
  });

  /// List of options to select from.
  final List<V> options;

  /// Sets the value of the field to the [option].
  void select(V? option) => setValue(option);
}
