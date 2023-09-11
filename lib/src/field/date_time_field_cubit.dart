import 'package:leancode_forms/src/field/cubit/field_cubit.dart';

/// A specialization of [FieldCubit] for a [DateTime] value.
class DateTimeFieldCubit<E extends Object> extends FieldCubit<DateTime?, E> {
  /// Creates a new [DateTimeFieldCubit].
  DateTimeFieldCubit({
    super.initialValue,
    super.validator,
    this.firstDate,
    this.lastDate,
  }) : assert(
          firstDate == null || lastDate == null || firstDate.isBefore(lastDate),
          'firstDate must be before lastDate',
        );

  /// The first date that can be selected.
  final DateTime? firstDate;

  /// The last date that can be selected.
  final DateTime? lastDate;
}
