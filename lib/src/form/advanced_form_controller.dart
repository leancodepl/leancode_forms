import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:leancode_forms/src/field/advanced_field_controller.dart';
import 'package:leancode_forms/src/utils/coalescing_call.dart';

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

  /// When true, a change to any field re-runs the change path on every other
  /// field whose gate is open. See [validateWithAutovalidate].
  final bool validateAll;

  final ChangeNotifier _onValuesChanged = ChangeNotifier();
  final ChangeNotifier _onStatusChanged = ChangeNotifier();
  final Set<AdvancedFieldController<dynamic, dynamic>> _ownedFields = {};
  final List<VoidCallback> _childCleanups = [];
  final CoalescingCall<bool> _validateCall = CoalescingCall();

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
  /// disposed. They are expected to be filled with their initial states.
  void registerFields(List<AdvancedFieldController<dynamic, dynamic>> fields) {
    _runChildCleanups();
    _setState(value.copyWith(fields: fields));

    _ownedFields.addAll(fields);
    _initialFieldsState = getFieldValues();
    _wireChildren();
    _recomputeWasModified();
    _onValuesChanged.notifyListeners();
  }

  /// Returns a list of all field values.
  @visibleForTesting
  List<dynamic> getFieldValues() =>
      value.fields.map<dynamic>((f) => f.value.value).toList();

  /// Recursively validates every field and subform, and reports whether all of
  /// them ended up valid.
  ///
  /// Every field runs a full round, so awaiting this is the guarantee that the
  /// values were checked; [AdvancedFormState.canSubmit] is only a snapshot of
  /// what is already known. Fields and subforms run concurrently and none is
  /// short-circuited.
  ///
  /// [enableAutovalidate] turns autovalidate on across the tree first.
  /// Concurrent calls coalesce, and the in-flight call's [enableAutovalidate]
  /// wins. Returns `true` when `state.validationEnabled` is false.
  Future<bool> validate({bool enableAutovalidate = true}) {
    // Checked before anything is broadcast: a coalesced call must not re-run
    // `setAutovalidate`, and a disabled form must not claim the coalescing slot
    // — a later, enabled call would then return this one's trivial `true`.
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

  /// Re-runs the change path on every leaf field whose gate is open: the sync
  /// validator now, the async validator after its debounce.
  ///
  /// Deliberately not [validate] — one keystroke must not fire an immediate
  /// network call for every other field in the tree. Read-only fields are left
  /// alone.
  void validateWithAutovalidate() => _broadcast(
        (field) {
          if (field.value.autovalidate) {
            field.setValue(field.value.value);
          }
        },
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

  /// Adds a subform to the current form. A noop if [form] is already a subform.
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
    _recomputeWasModified();
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
    // Eager list to prevent short circuits; all fields/subforms must be called.
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
    if (newValue == _value) {
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

  /// If false, validators are not ran and `validate` always returns true.
  final bool validationEnabled;

  /// This form's fields including every subform's fields.
  Iterable<AdvancedFieldController<dynamic, dynamic>> get allFields =>
      fields.followedBy(subforms.expand((e) => e.value.allFields));

  /// Whether an async check is in flight anywhere in the tree.
  bool get validating => allFields.any((field) => field.value.isInProgress);

  /// Whether some field's async check could not complete. Not sticky: the next
  /// [AdvancedFormController.validate] retries every failed round.
  bool get hasFailedValidation =>
      allFields.any((field) => field.value.isFailedValidation);

  /// Whether every field in the tree is [FieldStatus.valid] right now.
  ///
  /// A snapshot of **known** errors, so it is true on a quiet form where
  /// nothing has been checked yet. Use it to enable a submit button;
  /// `await AdvancedFormController.validate()` is the guarantee.
  bool get canSubmit => allFields.every((field) => field.value.isValid);

  /// Every error in the tree, keyed by field.
  ///
  /// Keyed on [AdvancedFieldState.error], so a field invalid from an async
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
