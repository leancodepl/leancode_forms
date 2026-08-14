part of 'advanced_form_controller.dart';

/// The state of an [AdvancedFormController] — which fields and subforms it
/// owns, whether the user has changed anything, and whether validation applies.
///
/// [validating], [hasFailedValidation], [canSubmit] and [validationErrors] are
/// computed from child fields on every read, so they always reflect the live
/// tree. Only the stored fields take part in `==`.
class AdvancedFormState with Equatable {
  /// Creates a new [AdvancedFormState].
  const AdvancedFormState({
    this.wasModified = false,
    this.fields = const [],
    this.subforms = const {},
    this.validationEnabled = true,
    this.validationMode = ValidationMode.disabled,
  });

  /// Whether any field value differs from the last `registerFields`, or any
  /// subform was itself modified.
  final bool wasModified;

  /// List of all registered fields by this form.
  final List<AdvancedFieldController<dynamic, dynamic>> fields;

  /// Set of registered subforms. Reference equality is assumed.
  final Set<AdvancedFormController> subforms;

  /// Whether this subtree participates in validation. When false, nothing
  /// validates, [AdvancedFormController.validate] returns true, and fields
  /// are excluded from [canSubmit] and [validationErrors]. False if any
  /// ancestor disabled validation.
  final bool validationEnabled;

  /// When fields in this tree validate themselves. Ignores [validationEnabled] —
  /// see [AdvancedFieldState.mode] for the effective mode.
  final ValidationMode validationMode;

  /// This form's fields including every subform's fields.
  Iterable<AdvancedFieldController<dynamic, dynamic>> get allFields =>
      fields.followedBy(subforms.expand((e) => e.value.allFields));

  // Fields that count — disabled subtrees excluded, matching what validate()
  // checks, so validate() and canSubmit always agree.
  Iterable<AdvancedFieldController<dynamic, dynamic>> get _countedFields sync* {
    if (!validationEnabled) {
      return;
    }
    yield* fields;
    for (final subform in subforms) {
      yield* subform.value._countedFields;
    }
  }

  /// Whether async validation is pending or running anywhere in the tree.
  bool get validating =>
      _countedFields.any((field) => field.value.isInProgress);

  /// Whether some field's async validation failed. Clears on the next
  /// [AdvancedFormController.validate] call.
  bool get hasFailedValidation =>
      _countedFields.any((field) => field.value.isFailedValidation);

  /// Whether every field in the tree is valid right now.
  ///
  /// True when nothing has been checked yet — only known errors count. False
  /// while validation is pending or running. Use to enable a submit button;
  /// call [AdvancedFormController.validate] before trusting the values.
  bool get canSubmit => _countedFields.every((field) => field.value.isValid);

  /// Every error in the tree, keyed by field.
  Map<AdvancedFieldController<dynamic, dynamic>, dynamic>
      get validationErrors => {
            for (final field in _countedFields)
              if (field.value.error case final error?) field: error,
          };

  AdvancedFormState _copyWith({
    bool? wasModified,
    List<AdvancedFieldController<dynamic, dynamic>>? fields,
    Set<AdvancedFormController>? subforms,
    bool? validationEnabled,
    ValidationMode? validationMode,
  }) =>
      AdvancedFormState(
        wasModified: wasModified ?? this.wasModified,
        fields: fields ?? this.fields,
        subforms: subforms ?? this.subforms,
        validationEnabled: validationEnabled ?? this.validationEnabled,
        validationMode: validationMode ?? this.validationMode,
      );

  @override
  List<Object?> get props => [
        wasModified,
        fields,
        subforms,
        validationEnabled,
        validationMode,
      ];
}
