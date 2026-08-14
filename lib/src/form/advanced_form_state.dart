part of 'advanced_form_controller.dart';

/// The state of an [AdvancedFormController] — which fields and subforms it
/// owns, whether the user has changed anything, and whether validation applies.
///
/// [validating], [hasFailedValidation], [canSubmit] and [validationErrors] are
/// derived from the child controllers on every read, so they follow the live
/// tree. Only the stored members take part in `==`.
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

  /// Whether this subtree counts at all. While false nothing in it validates,
  /// [AdvancedFormController.validate] returns true for it, and its fields
  /// count toward neither [canSubmit] nor [validationErrors]. Effective: false
  /// while any ancestor's is.
  final bool validationEnabled;

  /// When this tree's fields validate themselves. The **configured** mode, not
  /// reduced by [validationEnabled] — [AdvancedFieldState.mode] is the reduced
  /// one.
  final ValidationMode validationMode;

  /// This form's fields including every subform's fields.
  Iterable<AdvancedFieldController<dynamic, dynamic>> get allFields =>
      fields.followedBy(subforms.expand((e) => e.value.allFields));

  // Every field in the tree minus the switched-off subtrees — exactly the ones
  // [AdvancedFormController.validate] skips, so the two agree by construction.
  Iterable<AdvancedFieldController<dynamic, dynamic>> get _countedFields sync* {
    if (!validationEnabled) {
      return;
    }
    yield* fields;
    for (final subform in subforms) {
      yield* subform.value._countedFields;
    }
  }

  /// Whether an async round is pending or in flight anywhere in the tree.
  bool get validating =>
      _countedFields.any((field) => field.value.isInProgress);

  /// Whether some field's async check could not complete. Not sticky: the next
  /// [AdvancedFormController.validate] retries every failed round.
  bool get hasFailedValidation =>
      _countedFields.any((field) => field.value.isFailedValidation);

  /// Whether every field in the tree is [FieldStatus.valid] right now.
  ///
  /// Only known errors count, so it is true on a form where nothing has been
  /// checked yet. It is false while any round is pending or validating. Use it
  /// to enable a submit button, and run [AdvancedFormController.validate]
  /// before you trust the values.
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
