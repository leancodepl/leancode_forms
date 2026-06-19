import 'package:leancode_forms/src/field/field_controller.dart';

/// A specialization of [FieldController] for a [bool] value.
class BooleanFieldController<E extends Object>
    extends FieldController<bool, E> {
  /// Creates a new [BooleanFieldController].
  BooleanFieldController({
    super.initialValue = false,
    super.validator,
    super.asyncValidator,
    super.asyncValidationDebounce,
    super.name,
  });
}
