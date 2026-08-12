import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:leancode_forms/src/field/advanced_field_controller.dart';
import 'package:leancode_forms/src/utils/shared_call.dart';

/// A parent of multiple [AdvancedFieldController]s. Manages group validation,
/// tracks changes, and cleans up the resources it owns.
///
/// A form is a tree: it is the root of its own tree, its direct leaves are
/// fields, and its subtrees are subforms. Most methods broadcast to the whole
/// tree. Cycles are not supported and not checked against.
class AdvancedFormController
    with ChangeNotifier
    implements ValueListenable<AdvancedFormState> {
  /// Creates a new [AdvancedFormController].
  AdvancedFormController({
    this.debugName = '',
    this.validateAll = false,
  });

  /// A label for this form used for logging, or tracing across nested
  /// subforms. Has no effect on form behavior.
  final String debugName;

  /// When true, any field's change re-runs the sync validator on every field in
  /// the tree whose gate is open. See [validateWithAutovalidate].
  final bool validateAll;

  final ChangeNotifier _onValuesChanged = ChangeNotifier();
  final ChangeNotifier _onStatusChanged = ChangeNotifier();
  final Set<AdvancedFieldController<dynamic, dynamic>> _ownedFields = {};
  final List<VoidCallback> _childCleanups = [];
  final SharedCall<bool> _validateCall = SharedCall();

  AdvancedFormState _value = const AdvancedFormState();
  List<dynamic> _initialFieldsState = const <dynamic>[];
  bool _isDisposed = false;

  @override
  AdvancedFormState get value => _value;

  /// Whether this controller has been disposed. Once true it stays true;
  /// disposed controllers are not to be reused.
  bool get isDisposed => _isDisposed;

  /// Fires when any leaf field's value changes (recursively through subforms),
  /// or when fields are registered.
  Listenable get onValuesChanged => _onValuesChanged;

  /// Fires when any leaf field's status changes (recursively through subforms).
  Listenable get onStatusChanged => _onStatusChanged;

  /// Takes ownership of the [fields], disposing them when this form is
  /// disposed. Their current values become the [AdvancedFormState.wasModified]
  /// baseline.
  ///
  /// Replaces any earlier registration: those fields stop validating and
  /// notifying, but are still disposed with this form.
  ///
  /// Throws a [StateError] if this form has already been disposed — disposed
  /// controllers cannot be reused.
  void registerFields(List<AdvancedFieldController<dynamic, dynamic>> fields) {
    if (isDisposed) {
      throw StateError(
        'Cannot register fields on a disposed AdvancedFormController.',
      );
    }

    _runChildCleanups();
    // `value.fields` is replaced while `_ownedFields` accumulates, on purpose:
    // a replaced batch stops participating but is still disposed with the form.
    _setState(value.copyWith(fields: fields));

    _ownedFields.addAll(fields);
    _initialFieldsState = getFieldValues();
    _wireChildren();
    _recomputeWasModified();
    _onValuesChanged.notifyListeners();
  }

  /// Returns this form's own field values, excluding subforms'.
  @visibleForTesting
  List<dynamic> getFieldValues() =>
      value.fields.map<dynamic>((f) => f.value.value).toList();

  /// Recursively validates every field and subform, and reports whether all of
  /// them ended up valid.
  ///
  /// Every field validates, so awaiting this is the guarantee that the
  /// values were checked; [AdvancedFormState.canSubmit] is only a snapshot of
  /// what is already known. Fields and subforms run concurrently and none is
  /// short-circuited.
  ///
  /// [enableAutovalidate] turns autovalidate on across the tree first.
  ///
  /// Calling this again before the first call finishes gives you the same
  /// result; it does not start a second pass, and the first call's
  /// [enableAutovalidate] is the one that applies. Returns `true` when
  /// `state.validationEnabled` is false, and `false` on a disposed form.
  Future<bool> validate({bool enableAutovalidate = true}) {
    // Checked before anything is broadcast: a caller joining the run in flight
    // must not re-run `setAutovalidate`, and a disabled form must not start a
    // run — a later, enabled call would then return this one's trivial `true`.
    if (_validateCall.inFlight case final inFlight?) {
      return inFlight;
    }
    if (isDisposed) {
      return Future.value(false);
    }

    if (enableAutovalidate) {
      setAutovalidate(true);
    }
    if (!value.validationEnabled) {
      return Future.value(true);
    }

    return _validateCall.run(
      () => _runValidate(enableAutovalidate: enableAutovalidate),
    );
  }

  /// Re-runs the **sync** validator on every leaf field whose gate is open.
  ///
  /// Deliberately not [validate]: a sibling's edit does not change a field's own
  /// value, so no network call is owed and a settled async answer still stands.
  /// Read-only fields are included — freezing a value does not stop its rule
  /// from being re-evaluated.
  void validateWithAutovalidate() => _broadcast(
        (field) => field.revalidateSync(),
        (subform) => subform.validateWithAutovalidate(),
      );

  /// Marks all leaf fields as readonly.
  void markReadOnly() => _broadcast(
        (field) => field.markReadOnly(),
        (subform) => subform.markReadOnly(),
      );

  /// Unmarks all leaf fields as readonly.
  void unmarkReadOnly() => _broadcast(
        (field) => field.unmarkReadOnly(),
        (subform) => subform.unmarkReadOnly(),
      );

  /// Sets autovalidate on all leaf fields.
  void setAutovalidate(bool autovalidate) => _broadcast(
        (field) => field.setAutovalidate(autovalidate),
        (subform) => subform.setAutovalidate(autovalidate),
      );

  /// Resets all leaf fields to their initial states.
  void resetAll() => _broadcast(
        (field) => field.reset(),
        (subform) => subform.resetAll(),
      );

  /// Clears all errors on all leaf fields.
  void clearErrors() => _broadcast(
        (field) => field.clearErrors(),
        (subform) => subform.clearErrors(),
      );

  /// Adds an owned subform to the current form. A noop if [form] is already a
  /// subform.
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
    _recomputeWasModified();
  }

  /// Removes an owned subform, disposing it unless [close] is false. A noop if
  /// [form] was not a subform.
  ///
  /// Throws a [StateError] if this form has already been disposed — disposed
  /// controllers cannot be reused.
  void removeSubform(
    AdvancedFormController form, {
    bool close = true,
  }) {
    if (isDisposed) {
      throw StateError(
        'Cannot remove a subform from a disposed AdvancedFormController.',
      );
    }
    if (!value.subforms.contains(form)) {
      return;
    }

    _runChildCleanups();
    _setState(value.copyWith(subforms: {...value.subforms}..remove(form)));
    if (close) {
      form.dispose();
    }
    _wireChildren();
    _recomputeWasModified();
  }

  /// Turns validation of this form on or off. When
  /// [AdvancedFormState.validationEnabled] is set to false, all errors are
  /// cleared.
  ///
  /// Throws a [StateError] if this form has already been disposed — disposed
  /// controllers cannot be reused.
  void setValidationEnabled(bool validationEnabled) {
    if (isDisposed) {
      throw StateError(
        'Cannot change validation on a disposed AdvancedFormController.',
      );
    }
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

  Future<bool> _runValidate({required bool enableAutovalidate}) async {
    // Never short-circuit on the first `false`: a field that is not asked to
    // validate is a field whose async check never runs.
    final results = await Future.wait<bool>([
      for (final field in value.fields) field.validate(),
      for (final subform in value.subforms)
        subform.validate(enableAutovalidate: enableAutovalidate),
    ]);

    return results.every((result) => result);
  }

  // Recurses through the subforms' own methods rather than flattening to
  // `allFields`, so a subclass that overrides one of them still gets called.
  void _broadcast(
    void Function(AdvancedFieldController<dynamic, dynamic> field) onField,
    void Function(AdvancedFormController subform) onSubform,
  ) {
    value.fields.forEach(onField);
    value.subforms.forEach(onSubform);
  }

  void _wireChildren() {
    for (final field in value.fields) {
      var lastValue = field.value.value;
      var lastStatus = field.value.status;
      void listener() {
        final state = field.value;
        if (state.value != lastValue) {
          lastValue = state.value;
          _handleValuesChanged();
        }
        if (state.status != lastStatus) {
          lastStatus = state.status;
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
    if (validateAll) {
      validateWithAutovalidate();
    }
    _recomputeWasModified();
    _onValuesChanged.notifyListeners();
  }

  void _handleStatusChanged() {
    // The aggregates are derived on read, so there is nothing to write — but
    // their readers still have to be told to look again.
    notifyListeners();
    _onStatusChanged.notifyListeners();
  }

  // The one aggregate that cannot be derived on read: it needs the baseline
  // captured at `registerFields`.
  void _recomputeWasModified() {
    final subformsWereModified = value.subforms.any(
      (subform) => subform.value.wasModified,
    );
    final fieldsWereModified = !const DeepCollectionEquality()
        .equals(_initialFieldsState, getFieldValues());

    _setState(
      value.copyWith(wasModified: subformsWereModified || fieldsWereModified),
    );
  }

  void _setState(AdvancedFormState newValue) {
    if (_isDisposed || newValue == _value) {
      return;
    }
    _value = newValue;
    notifyListeners();
  }
}

/// A snapshot of an [AdvancedFormController] — which fields and subforms it
/// owns, whether the user has changed anything, and whether validation applies.
///
/// [validating], [hasFailedValidation], [canSubmit] and [validationErrors] are
/// derived from the child controllers on every read, so they follow the live
/// tree. Only the stored members take part in `==`.
class AdvancedFormState {
  /// Creates a new [AdvancedFormState].
  const AdvancedFormState({
    this.wasModified = false,
    this.fields = const [],
    this.subforms = const {},
    this.validationEnabled = true,
  });

  /// Whether any field value differs from the last `registerFields`, or any
  /// subform was itself modified.
  final bool wasModified;

  /// List of all registered fields by this form.
  final List<AdvancedFieldController<dynamic, dynamic>> fields;

  /// Set of registered subforms. Reference equality is assumed.
  final Set<AdvancedFormController> subforms;

  /// If false, [AdvancedFormController.validate] returns true without
  /// validating. Errors already on the fields still count toward [canSubmit].
  final bool validationEnabled;

  /// This form's fields including every subform's fields.
  Iterable<AdvancedFieldController<dynamic, dynamic>> get allFields =>
      fields.followedBy(subforms.expand((e) => e.value.allFields));

  /// Whether an async round is pending or in flight anywhere in the tree.
  bool get validating => allFields.any((field) => field.value.isInProgress);

  /// Whether some field's async check could not complete. Not sticky: the next
  /// [AdvancedFormController.validate] retries every failed round.
  bool get hasFailedValidation =>
      allFields.any((field) => field.value.isFailedValidation);

  /// Whether every field in the tree is [FieldStatus.valid] right now.
  ///
  /// A snapshot of **known** errors, so it is true on a quiet form where
  /// nothing has been checked yet. It is false while any round is pending or
  /// validating. Use it to enable a submit button;
  /// `await AdvancedFormController.validate()` is the guarantee.
  bool get canSubmit => allFields.every((field) => field.value.isValid);

  /// Every error in the tree, keyed by field.
  ///
  /// The value is [AdvancedFieldState.error], so a field invalid from an async
  /// check appears too. A failed round with no error code does not.
  Map<AdvancedFieldController<dynamic, dynamic>, dynamic>
      get validationErrors => {
            for (final field in allFields)
              if (field.value.error case final error?) field: error,
          };

  /// Returns a copy of this state with the given fields replaced.
  AdvancedFormState copyWith({
    bool? wasModified,
    List<AdvancedFieldController<dynamic, dynamic>>? fields,
    Set<AdvancedFormController>? subforms,
    bool? validationEnabled,
  }) =>
      AdvancedFormState(
        wasModified: wasModified ?? this.wasModified,
        fields: fields ?? this.fields,
        subforms: subforms ?? this.subforms,
        validationEnabled: validationEnabled ?? this.validationEnabled,
      );

  // ⚠️ Maintainer: keep these and `copyWith` in sync with the fields above.
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AdvancedFormState &&
          wasModified == other.wasModified &&
          listEquals(fields, other.fields) &&
          setEquals(subforms, other.subforms) &&
          validationEnabled == other.validationEnabled;

  @override
  int get hashCode => Object.hash(
        wasModified,
        Object.hashAll(fields),
        Object.hashAllUnordered(subforms),
        validationEnabled,
      );
}
