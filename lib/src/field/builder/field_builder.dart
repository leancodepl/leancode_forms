import 'package:flutter/widgets.dart';
import 'package:leancode_forms/src/field/field_controller.dart';

/// A thin wrapper around [ValueListenableBuilder] that rebuilds whenever the
/// given [field] notifies. Saves typing the `<FieldState<T, E>>` type argument
/// at call sites.
///
/// For finer control (e.g. the `child:` optimization on
/// [ValueListenableBuilder]), use [ValueListenableBuilder] directly.
class FieldBuilder<T, E extends Object> extends StatelessWidget {
  /// Creates a new [FieldBuilder].
  const FieldBuilder({
    super.key,
    required this.field,
    required this.builder,
  });

  /// The field to listen to.
  final FieldController<T, E> field;

  /// Called with the latest [FieldState] every time [field] notifies.
  final Widget Function(BuildContext context, FieldState<T, E> state) builder;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<FieldState<T, E>>(
      valueListenable: field,
      builder: (context, state, _) => builder(context, state),
    );
  }
}
