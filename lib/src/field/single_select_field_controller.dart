import 'package:leancode_forms/src/field/field_controller.dart';

/// A specialization of [FieldController] for a single choice of [V] from a
/// list of [options].
class SingleSelectFieldController<V, E extends Object>
    extends FieldController<V?, E> {
  /// Creates a new [SingleSelectFieldController].
  SingleSelectFieldController({
    required super.initialValue,
    super.validator,
    required this.options,
    super.name,
  });

  /// List of options to select from.
  final List<V> options;

  /// Sets the value of the field to the [option].
  void select(V? option) => setValue(option);

  /// Resets selected value to the initial one.
  void clear() => reset();
}
