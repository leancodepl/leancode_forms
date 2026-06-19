import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:leancode_forms/src/field/field_controller.dart';

/// A parent of multiple [FieldController]s. Manages group validation and tracks
/// changes as well as cleans up needed resources.
///
/// A form is a tree which can be recursively defined:
///   1. A form is the root of its own form tree
///   2. A form has direct leaves, which are fields
///   3. A form can have subtrees, which are forms (called subforms)
///
/// Most methods broadcast to all subforms.
///
/// Introducing cycles in forms is not supported and not checked against (most
/// likely will cause a stack overflow somewhere).
// ignore_for_file: avoid_positional_boolean_parameters
class FormGroupController extends ValueNotifier<FormGroupState> {
  /// Creates a new [FormGroupController].
  FormGroupController({
    this.debugName = '',
    this.validateAll = false,
  }) : super(const FormGroupState());

  /// A debug label for this form. Not significant to the form.
  final String debugName;

  /// When true, whenever any field changes, all other fields get
  /// their validator called if they have autovalidate enabled.
  final bool validateAll;

  /// The current state. Alias for [value] kept for readability at call sites
  /// that previously read `cubit.state`.
  FormGroupState get state => value;

  /// Fires when any leaf field's value changes (recursively through subforms),
  /// or when fields are registered.
  Listenable get onValuesChanged => _onValuesChanged;
  final ChangeNotifier _onValuesChanged = ChangeNotifier();

  /// Fires when any leaf field's status changes (recursively through subforms).
  Listenable get onStatusChanged => _onStatusChanged;
  final ChangeNotifier _onStatusChanged = ChangeNotifier();

  List<dynamic> _initialFieldsState = const <dynamic>[];

  final Set<FieldController<dynamic, dynamic>> _ownedFields = {};
  final List<VoidCallback> _childCleanups = [];

  /// Takes ownership of registered fields. Will dispose all controllers when
  /// the form group is disposed.
  /// Fields are expected to be filled with initial states.
  void registerFields(List<FieldController<dynamic, dynamic>> fields) {
    _runChildCleanups();

    value = FormGroupState(
      wasModified: value.wasModified,
      fields: fields,
      subforms: value.subforms,
      validationEnabled: value.validationEnabled,
      validating: value.validating,
    );

    _ownedFields.addAll(fields);
    _initialFieldsState = getFieldValues();
    _wireChildren();
    _onValuesChanged.notifyListeners();
  }

  /// Returns a list of all field values.
  @visibleForTesting
  List<dynamic> getFieldValues() {
    return value.fields.map<dynamic>((f) => f.value.value).toList();
  }

  /// Recursively calls validate on all subforms/fields if
  /// `state.validationEnabled` is true.
  /// [enableAutovalidate] can enable autovalidate on this form.
  ///
  /// Returns the result of validate calls, or always `true` if
  /// `state.validationEnabled` is false.
  bool validate({bool enableAutovalidate = true}) {
    if (enableAutovalidate) {
      setAutovalidate(true);
    }
    if (!value.validationEnabled) {
      return true;
    }

    // Eager list to prevent short circuits; all fields/subforms must be called.
    return [
      for (final field in value.fields) field.validate(),
      for (final subform in value.subforms)
        subform.validate(enableAutovalidate: enableAutovalidate),
    ].every((e) => e);
  }

  /// Marks all leaf fields as readonly.
  void markReadOnly() {
    for (final field in value.fields) {
      field.markReadOnly();
    }
    for (final subform in value.subforms) {
      subform.markReadOnly();
    }
  }

  /// Unmarks all leaf fields as readonly.
  void unmarkReadOnly() {
    for (final field in value.fields) {
      field.unmarkReadOnly();
    }
    for (final subform in value.subforms) {
      subform.unmarkReadOnly();
    }
  }

  /// Sets autovalidate on all leaf fields.
  void setAutovalidate(bool autovalidate) {
    for (final field in value.fields) {
      field.setAutovalidate(autovalidate);
    }
    for (final subform in value.subforms) {
      subform.setAutovalidate(autovalidate);
    }
  }

  /// Resets all leaf fields to their initial states.
  void resetAll() {
    for (final field in value.fields) {
      field.reset();
    }
    for (final subform in value.subforms) {
      subform.resetAll();
    }
  }

  /// Clears all errors on all leaf fields.
  void clearErrors() {
    for (final field in value.fields) {
      field.clearErrors();
    }
    for (final subform in value.subforms) {
      subform.clearErrors();
    }
  }

  /// Adds a subform to the current form.
  /// If [form] was already added as a subform this is a noop.
  void addSubform(FormGroupController form) {
    if (value.subforms.contains(form)) {
      return;
    }
    _runChildCleanups();

    value = FormGroupState(
      wasModified: value.wasModified,
      fields: value.fields,
      subforms: {...value.subforms, form},
      validationEnabled: value.validationEnabled,
      validating: value.validating,
    );

    _wireChildren();
  }

  /// Removes and disposes an owned subform.
  /// If [form] was not a subform this is a noop.
  Future<void> removeSubform(
    FormGroupController form, {
    bool close = true,
  }) async {
    if (!value.subforms.contains(form)) {
      return;
    }
    _runChildCleanups();

    value = FormGroupState(
      wasModified: value.wasModified,
      fields: value.fields,
      subforms: {...value.subforms}..remove(form),
      validationEnabled: value.validationEnabled,
      validating: value.validating,
    );

    if (close) {
      form.dispose();
    }

    _wireChildren();
  }

  /// Calls validate on all fields with autovalidate on.
  void validateWithAutovalidate() {
    for (final field in value.fields) {
      if (field.value.autovalidate) {
        field.validate();
      }
    }
    for (final subform in value.subforms) {
      subform.validateWithAutovalidate();
    }
  }

  /// Changes optionality of this form. When `validationEnabled` is set to
  /// false, all errors are cleared.
  void setValidationEnabled(bool validationEnabled) {
    if (validationEnabled == value.validationEnabled) {
      return;
    }
    value = FormGroupState(
      wasModified: value.wasModified,
      fields: value.fields,
      subforms: value.subforms,
      validationEnabled: validationEnabled,
      validating: value.validating,
    );
    if (validationEnabled) {
      validateWithAutovalidate();
    } else {
      clearErrors();
    }
  }

  void _wireChildren() {
    for (final field in value.fields) {
      var lastValue = field.value.value;
      var lastStatus = field.value.status;
      void listener() {
        final s = field.value;
        if (s.value != lastValue) {
          lastValue = s.value;
          _handleValuesChanged();
        }
        if (s.status != lastStatus) {
          lastStatus = s.status;
          _handleStatusChanged();
        }
      }

      field.addListener(listener);
      _childCleanups.add(() => field.removeListener(listener));
    }

    for (final subform in value.subforms) {
      subform.onValuesChanged.addListener(_handleValuesChanged);
      subform.onStatusChanged.addListener(_handleStatusChanged);
      _childCleanups.add(() {
        subform.onValuesChanged.removeListener(_handleValuesChanged);
        subform.onStatusChanged.removeListener(_handleStatusChanged);
      });
    }
  }

  void _runChildCleanups() {
    for (final cleanup in _childCleanups) {
      cleanup();
    }
    _childCleanups.clear();
  }

  void _handleValuesChanged() {
    final subformsWereModified = value.subforms.any(
      (subform) => subform.value.wasModified,
    );
    final fieldsWereModified = !const DeepCollectionEquality()
        .equals(_initialFieldsState, getFieldValues());

    if (validateAll) {
      validateWithAutovalidate();
    }

    value = FormGroupState(
      wasModified: subformsWereModified || fieldsWereModified,
      fields: value.fields,
      subforms: value.subforms,
      validationEnabled: value.validationEnabled,
      validating: value.validating,
    );
    _onValuesChanged.notifyListeners();
  }

  void _handleStatusChanged() {
    final subformsValidating = value.subforms.any(
      (subform) => subform.value.validating,
    );
    final fieldsValidating = value.fields.any(
      (field) => field.value.isInProgress,
    );

    value = FormGroupState(
      wasModified: value.wasModified,
      fields: value.fields,
      subforms: value.subforms,
      validationEnabled: value.validationEnabled,
      validating: fieldsValidating || subformsValidating,
    );
    _onStatusChanged.notifyListeners();
  }

  @override
  void dispose() {
    _runChildCleanups();
    for (final field in _ownedFields) {
      field.dispose();
    }
    _ownedFields.clear();
    for (final subform in value.subforms) {
      subform.dispose();
    }
    _onValuesChanged.dispose();
    _onStatusChanged.dispose();
    super.dispose();
  }
}

/// The state of a [FormGroupController].
///
/// Value-equal: two [FormGroupState]s are equal when every field matches.
/// This is required for [ValueNotifier]'s built-in dedup — without it,
/// every internal state recompute (`_handleValuesChanged`,
/// `_handleStatusChanged`, etc.) would notify listeners even when the
/// recomputed state is identical to the previous one.
///
/// **Maintainer note:** when adding a new field below, you MUST also add it
/// to both [operator ==] and [hashCode] at the bottom of the class, otherwise
/// the new field is silently invisible to dedup and structural comparisons.
class FormGroupState {
  /// Creates a new [FormGroupState].
  const FormGroupState({
    this.wasModified = false,
    this.fields = const [],
    this.subforms = const {},
    this.validationEnabled = true,
    this.validating = false,
  });

  /// wasModified is true when any of the field values differ since the
  /// last `registerFields` or when any of the subforms has wasModified=true.
  final bool wasModified;

  /// List of all registered fields by this form.
  final List<FieldController<dynamic, dynamic>> fields;

  /// Set of registered subforms. Reference equality is assumed.
  final Set<FormGroupController> subforms;

  /// If false, validators are not ran and `validate` always returns true.
  final bool validationEnabled;

  /// Returns true if fields are currently being validated.
  final bool validating;

  /// List of this form's fields including subforms' fields.
  Iterable<FieldController<dynamic, dynamic>> get allFields =>
      fields.followedBy(subforms.expand((e) => e.value.allFields));

  /// Map of all validation errors (including subforms') grouped by fields.
  Map<FieldController<dynamic, dynamic>, dynamic> get validationErrors => {
        for (final field in allFields)
          if (field.value.validationError case final error?) field: error,
      };

  // ⚠️ Maintainer: keep these in sync with the fields declared above. `fields`
  // and `subforms` use ListEquality/SetEquality (with identity-based element
  // comparison, since FieldController/FormGroupController don't override `==`).
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FormGroupState &&
          wasModified == other.wasModified &&
          const ListEquality<FieldController<dynamic, dynamic>>()
              .equals(fields, other.fields) &&
          const SetEquality<FormGroupController>()
              .equals(subforms, other.subforms) &&
          validationEnabled == other.validationEnabled &&
          validating == other.validating;

  @override
  int get hashCode => Object.hash(
        wasModified,
        const ListEquality<FieldController<dynamic, dynamic>>().hash(fields),
        const SetEquality<FormGroupController>().hash(subforms),
        validationEnabled,
        validating,
      );
}
