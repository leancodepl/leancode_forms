import 'package:flutter/widgets.dart';
import 'package:leancode_forms/src/field/advanced_field_controller.dart';

/// Builder signature for [AdvancedFieldBuilder]. Receives the field controller
/// itself (with its concrete subtype preserved) so subclass-specific API like
/// `textController` or `focusNode` is reachable without a cast or context lookup.
typedef AdvancedFieldWidgetBuilder<
        C extends AdvancedFieldController<Object?, Object>>
    = Widget Function(BuildContext context, C field, Widget? child);

/// Rebuilds whenever [field] notifies. Hands the controller back to [builder]
/// with its exact subclass type, so subclass-specific methods are available at
/// the call site without a closure capture or cast.
class AdvancedFieldBuilder<C extends AdvancedFieldController<Object?, Object>>
    extends StatelessWidget {
  /// Creates a new [AdvancedFieldBuilder].
  const AdvancedFieldBuilder({
    super.key,
    required this.field,
    required this.builder,
    this.child,
  });

  /// The field to listen to.
  final C field;

  /// Called every time [field] notifies.
  final AdvancedFieldWidgetBuilder<C> builder;

  /// Forwarded to [ListenableBuilder.child].
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: field,
      child: child,
      builder: (context, child) => builder(context, field, child),
    );
  }
}
