import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:leancode_forms/src/field/advanced_field_controller.dart';

/// A parent of multiple [AdvancedFieldController]s. Manages group validation and tracks
/// changes as well as cleans up needed resources.
///
/// A form is a tree which can be recursively defined:
///   1. A form is the root of its own form tree
///   2. A form has direct leaves, which are fields
///   3. A form can have subtrees, which are forms (this is called subforms)
///
/// Most methods broadcast to all subforms.
///
/// Introducing cycles in forms is not supported and not checked against (most
/// likely will cause a stack overflow somewhere).
class AdvancedFormController
    with ChangeNotifier
    implements ValueListenable<AdvancedFormState> {
  /// Creates a new [AdvancedFormController].
  AdvancedFormController({
    this.debugName = '',
    this.validateAll = false,
  });

  AdvancedFormState _value = const AdvancedFormState();

  @override
  AdvancedFormState get value => _value;

  void _setState(AdvancedFormState newValue) {
    if (newValue == _value) {
      return;
    }
    _value = newValue;
    notifyListeners();
  }

  /// A label for this form used for logging, or tracing
  /// across nested subforms. Has no effect on form behavior.
  final String debugName;

  /// When true, whenever any field changes, all other fields get
  /// their validator called if they have autovalidate enabled.
  final bool validateAll;

  /// Flag about whether controller has been disposed. Once true it stays true.
  /// Disposed controllers are not to be reused
  bool _isDisposed = false;

  /// Getter for the isDisposed flag
  bool get isDisposed => _isDisposed;

  /// Fires when any leaf field's value changes (recursively through subforms),
  /// or when fields are registered.
  Listenable get onValuesChanged => _onValuesChanged;
  final ChangeNotifier _onValuesChanged = ChangeNotifier();

  /// Fires when any leaf field's status changes (recursively through subforms).
  Listenable get onStatusChanged => _onStatusChanged;
  final ChangeNotifier _onStatusChanged = ChangeNotifier();

  List<dynamic> _initialFieldsState = const <dynamic>[];

  final Set<AdvancedFieldController<dynamic, dynamic>> _ownedFields = {};
  final List<VoidCallback> _childCleanups = [];

  /// Takes ownership of registered fields. Will dispose all controllers when
  /// the form group is disposed.
  /// Fields are expected to be filled with initial states.
  void registerFields(List<AdvancedFieldController<dynamic, dynamic>> fields) {
    _runChildCleanups();

    _setState(value.copyWith(fields: fields));

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
  /// [enableAutovalidate] can enable autovalidate on all leaf fields.
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
  ///
  /// Throws a [StateError] if either controller has already been disposed —
  /// disposed controllers cannot be reused.
  void addSubform(AdvancedFormController form) {
    if (isDisposed) {
      throw StateError(
        'Cannot add a subform to a disposed AdvancedFormController.',
      );
    }
    if (form.isDisposed) {
      throw StateError(
        'Cannot add a disposed AdvancedFormController as a subform.',
      );
    }
    if (value.subforms.contains(form)) {
      return;
    }

    _runChildCleanups();

    _setState(value.copyWith(subforms: {...value.subforms, form}));

    _wireChildren();
  }

  /// Removes an owned subform.
  /// If [close] is true, the subform will be disposed.
  /// If [form] was not a subform this is a noop.
  Future<void> removeSubform(
    AdvancedFormController form, {
    bool close = true,
  }) async {
    if (!value.subforms.contains(form)) {
      return;
    }
    _runChildCleanups();

    _setState(value.copyWith(subforms: {...value.subforms}..remove(form)));

    if (close) {
      form.dispose();
    }

    _wireChildren();
  }

  /// Calls validate on all leaf fields with autovalidate on.
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
    _setState(value.copyWith(validationEnabled: validationEnabled));
    if (validationEnabled) {
      validateWithAutovalidate();
    } else {
      clearErrors();
    }
  }

  /// Wires listeners to each subform
  /// in order to track and handle value/status changes
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

    _setState(
      value.copyWith(wasModified: subformsWereModified || fieldsWereModified),
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

    _setState(
      value.copyWith(validating: fieldsValidating || subformsValidating),
    );
    _onStatusChanged.notifyListeners();
  }

  @override
  void dispose() {
    _isDisposed = true;
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

/// An immutable snapshot of an [AdvancedFormController] — which fields and
/// subforms it owns, whether the user has changed anything, whether validation
/// applies, and whether async validation is still running.
///
/// Obtain it from [AdvancedFormController.value], or listen to the controller
/// to be notified whenever it changes.
class AdvancedFormState {
  /// Creates a new [AdvancedFormState].
  const AdvancedFormState({
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
  final List<AdvancedFieldController<dynamic, dynamic>> fields;

  /// Set of registered subforms. Reference equality is assumed.
  final Set<AdvancedFormController> subforms;

  /// If false, validators are not ran and `validate` always returns true.
  final bool validationEnabled;

  /// Returns true if fields are currently being validated.
  final bool validating;

  /// List of this form's fields including subforms' fields.
  Iterable<AdvancedFieldController<dynamic, dynamic>> get allFields =>
      fields.followedBy(subforms.expand((e) => e.value.allFields));

  /// Map of all validation errors (including subforms') grouped by fields.
  Map<AdvancedFieldController<dynamic, dynamic>, dynamic>
      get validationErrors => {
            for (final field in allFields)
              if (field.value.validationError case final error?) field: error,
          };

  /// Returns a copy of this state with the given fields replaced.
  AdvancedFormState copyWith({
    bool? wasModified,
    List<AdvancedFieldController<dynamic, dynamic>>? fields,
    Set<AdvancedFormController>? subforms,
    bool? validationEnabled,
    bool? validating,
  }) =>
      AdvancedFormState(
        wasModified: wasModified ?? this.wasModified,
        fields: fields ?? this.fields,
        subforms: subforms ?? this.subforms,
        validationEnabled: validationEnabled ?? this.validationEnabled,
        validating: validating ?? this.validating,
      );

  // ⚠️ Maintainer: keep these and `copyWith` in sync with the fields above.
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AdvancedFormState &&
          wasModified == other.wasModified &&
          listEquals(fields, other.fields) &&
          setEquals(subforms, other.subforms) &&
          validationEnabled == other.validationEnabled &&
          validating == other.validating;

  @override
  int get hashCode => Object.hash(
        wasModified,
        Object.hashAll(fields),
        Object.hashAllUnordered(subforms),
        validationEnabled,
        validating,
      );
}
