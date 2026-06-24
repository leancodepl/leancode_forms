import 'package:flutter/widgets.dart';
import 'package:leancode_forms/src/form/advanced_form_controller.dart';

/// Rebuilds whenever the validation status of [form] changes.
///
/// Subscribes to [AdvancedFormController.onStatusChanged] and re-evaluates
/// `isValid` as "every leaf field (including subforms recursively) reports
/// `value.isValid == true`". Typical use: enabling/disabling a submit button
class AdvancedValidationStatusBuilder extends StatelessWidget {
  /// Creates a new [AdvancedValidationStatusBuilder].
  const AdvancedValidationStatusBuilder({
    super.key,
    required this.form,
    required this.builder,
    this.child,
  });

  /// The form whose validation status drives rebuilds.
  final AdvancedFormController form;

  /// Called each time [form]'s validation status changes.
  /// `isValid` is true if every registered field reports as valid
  final Widget Function(BuildContext context, bool isValid, Widget? child)
      builder;

  /// Forwarded to [ListenableBuilder.child], to support further optimizations
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
    /// Listen to the form's validation status and rebuild whenever it changes.
      listenable: form.onStatusChanged,
      child: child,
      builder: (context, child) => builder(
        context,
        form.value.allFields.every((field) => field.value.isValid),
        child,
      ),
    );
  }
}
