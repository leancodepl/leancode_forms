import 'package:leancode_forms/src/field/advanced_field_controller.dart';

/// A specialization of [AdvancedFieldController] for a [bool] value.
class AdvancedBooleanFieldController<E extends Object>
    extends AdvancedFieldController<bool, E> {
  /// Creates a new [AdvancedBooleanFieldController].
  AdvancedBooleanFieldController({
    super.initialValue = false,
    super.validator,
    super.asyncValidator,
    super.asyncValidationDebounce,
    super.name,
  });
}
