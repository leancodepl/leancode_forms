import 'package:flutter/widgets.dart';
import 'package:leancode_forms/src/field/advanced_field_controller.dart';
import 'package:leancode_forms/src/field/advanced_field_state.dart';

/// Rebuilds whenever [field] notifies. Thin wrapper around
/// [ValueListenableBuilder] that hides the `<AdvancedFieldState<T, E>>` type argument.
class AdvancedFieldBuilder<T, E extends Object> extends StatelessWidget {
  /// Creates a new [AdvancedFieldBuilder].
  const AdvancedFieldBuilder({
    super.key,
    required this.field,
    required this.builder,
    this.child,
  });

  /// The field to listen to.
  final AdvancedFieldController<T, E> field;

  /// Called every time [field] notifies.
  final ValueWidgetBuilder<AdvancedFieldState<T, E>> builder;

  /// Forwarded to [ValueListenableBuilder.child].
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AdvancedFieldState<T, E>>(
      valueListenable: field,
      builder: builder,
      child: child,
    );
  }
}
