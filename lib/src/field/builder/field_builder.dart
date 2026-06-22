import 'package:flutter/widgets.dart';
import 'package:leancode_forms/src/field/field_controller.dart';

/// Rebuilds whenever [field] notifies. Thin wrapper around
/// [ValueListenableBuilder] that hides the `<FieldState<T, E>>` type argument.
class FieldBuilder<T, E extends Object> extends StatelessWidget {
  /// Creates a new [FieldBuilder].
  const FieldBuilder({
    super.key,
    required this.field,
    required this.builder,
    this.child,
  });

  /// The field to listen to.
  final FieldController<T, E> field;

  /// Called every time [field] notifies.
  final ValueWidgetBuilder<FieldState<T, E>> builder;

  /// Forwarded to [ValueListenableBuilder.child].
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<FieldState<T, E>>(
      valueListenable: field,
      builder: builder,
      child: child,
    );
  }
}
