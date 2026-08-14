import 'dart:async';

import 'package:collection/collection.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:leancode_forms/src/field/advanced_field_controller.dart';
import 'package:leancode_forms/src/field/validation_mode.dart';
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
  ///
  /// A [validationMode] given here is this form's own: a parent form's mode
  /// does not replace it. Leave it out to follow the parent, or to stay
  /// [ValidationMode.disabled] when there is no parent.
  AdvancedFormController({
    this.debugName = '',
    this.validateAll = false,
    ValidationMode? validationMode,
  })  : _hasOwnMode = validationMode != null,
        _mode = validationMode ?? ValidationMode.disabled,
        _value = AdvancedFormState(
          validationMode: validationMode ?? ValidationMode.disabled,
        );

  /// A label you can log to tell nested subforms apart. The package never reads
  /// it.
  final String debugName;

  /// When true, any field's change re-runs the sync validator on every field in
  /// the tree that validates on a dependency's change. See [revalidateSync].
  final bool validateAll;

  AdvancedFormState _value;

  // This subtree's mode. A parent's broadcast replaces it unless this form
  // claimed one of its own.
  ValidationMode _mode;

  // One-way: once this form manages its own mode, a parent never replaces it.
  bool _hasOwnMode;

  // The two halves of `validationEnabled`: this form's own switch, and what its
  // parent last sent. They are AND-ed, so an opted-out section stays out when
  // its parent switches back on.
  bool _ownEnabled = true;
  bool _parentEnabled = true;

  @override
  AdvancedFormState get value => _value;

  bool _isDisposed = false;

  /// Whether this controller has been disposed. Once true it stays true;
  /// disposed controllers are not to be reused.
  bool get isDisposed => _isDisposed;

  final _onValuesChanged = ChangeNotifier();

  /// Fires when any leaf field's value changes (recursively through subforms),
  /// or when fields are registered.
  Listenable get onValuesChanged => _onValuesChanged;

  final _onStatusChanged = ChangeNotifier();

  /// Fires when any leaf field's status or error changes (recursively through
  /// subforms).
  Listenable get onStatusChanged => _onStatusChanged;

  // Internals with no public surface.
  // Explicit type — inference would widen the error type from dynamic to Object.
  final Set<AdvancedFieldController<dynamic, dynamic>> _ownedFields = {};
  final _childCleanups = <VoidCallback>[];
  final _relationCleanups = <VoidCallback>[];
  final _validateCall = SharedCall<bool>();
  var _initialFieldsState = const <dynamic>[];

  /// Registers [fields] as this form's own fields and takes ownership of them,
  /// disposing them when this form is disposed. Their current values become the
  /// [AdvancedFormState.wasModified] baseline.
  ///
  /// Replaces any earlier registration: those fields stop validating and
  /// notifying, but are still disposed with this form.
  ///
  /// Throws a [StateError] if this form or any of the [fields] has already been
  /// disposed — disposed controllers cannot be reused.
  void registerFields(List<AdvancedFieldController<dynamic, dynamic>> fields) {
    if (isDisposed) {
      throw StateError(
        'Cannot register fields on a disposed AdvancedFormController.',
      );
    }
    if (fields.any((field) => field.isDisposed)) {
      throw StateError(
        'Cannot register a disposed AdvancedFieldController.',
      );
    }

    _runChildCleanups();
    // A field dropped from the form stops hearing from it. One that claimed its
    // own mode keeps it — it manages its own, parent or no parent.
    for (final field in value.fields) {
      if (!fields.contains(field)) {
        field.applyValidationSettings(defaultValidationSettings);
      }
    }
    // `value.fields` is replaced while `_ownedFields` accumulates, on purpose:
    // a replaced batch stops participating but is still disposed with the form.
    _setState(value._copyWith(fields: fields));
    _publishSettings();

    _ownedFields.addAll(fields);
    _initialFieldsState = getFieldValues();
    _wireChildren();
    _recomputeWasModified();
    _onValuesChanged.notifyListeners();
  }

  /// Calls [onChange] whenever the part of [source]'s value selected by
  /// [select] changes. Parts are compared with `==`, so a status-only change
  /// on [source] never fires.
  ///
  /// The relation lives as long as this form: the listener is removed on
  /// [dispose], so no manual cleanup is needed.
  ///
  /// Throws a [StateError] if this form or [source] has already been
  /// disposed — disposed controllers cannot be reused.
  void addRelation<T, R>(
    AdvancedFieldController<T, dynamic> source,
    R Function(T value) select,
    void Function(R value) onChange,
  ) {
    if (isDisposed || source.isDisposed) {
      throw StateError(
        'Cannot add a relation on a disposed controller.',
      );
    }

    var last = select(source.fieldValue);
    void listener() {
      final next = select(source.fieldValue);
      if (next == last) {
        return;
      }
      last = next;
      onChange(next);
    }

    source.addListener(listener);
    _relationCleanups.add(() => source.removeListener(listener));
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
  /// The [AdvancedFormState.validationMode] is neither read nor changed: the
  /// mode a developer set is the mode the form has for its whole life, so it
  /// behaves the same before and after the first submit.
  ///
  /// A subtree with [AdvancedFormState.validationEnabled] false skips its own
  /// fields, exactly as [AdvancedFormState.canSubmit] leaves them out, so the
  /// two cannot disagree about the same subtree.
  ///
  /// Calling this again before the first call finishes gives you the same
  /// result; it does not start a second pass. Returns `false` on a disposed
  /// form.
  Future<bool> validate() {
    if (_validateCall.inFlight case final inFlight?) {
      return inFlight;
    }
    if (isDisposed) {
      return Future.value(false);
    }

    return _validateCall.run(_runValidate);
  }

  /// Re-runs the **sync** validator on every leaf field whose gate is open.
  ///
  /// Deliberately not [validate]: a sibling's edit does not change a field's own
  /// value, so no async check is owed and a settled async answer still stands.
  /// Read-only fields are included — freezing a value does not stop its rule
  /// from being re-evaluated.
  void revalidateSync() => _broadcast(
        (field) => field.revalidateSync(),
        (subform) => subform.revalidateSync(),
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
    _setState(value._copyWith(subforms: {...value.subforms, form}));
    _publishSettings();
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
    _setState(value._copyWith(subforms: {...value.subforms}..remove(form)));
    if (close) {
      form.dispose();
    } else {
      // It stops hearing from this form. A mode it claimed is its own to keep.
      form.applyValidationSettings(defaultValidationSettings);
    }
    _wireChildren();
    _recomputeWasModified();
  }

  /// Turns validation of this tree on or off — whether this section counts at
  /// all, which outranks every [ValidationMode].
  ///
  /// While it is off, every field in the tree behaves as
  /// [ValidationMode.disabled], [validate] skips them, and their errors are
  /// cleared. Subforms inherit it: a section that switched itself off stays off
  /// when its parent switches on.
  ///
  /// Throws a [StateError] if this form has already been disposed — disposed
  /// controllers cannot be reused.
  void setValidationEnabled(bool validationEnabled) {
    if (isDisposed) {
      throw StateError(
        'Cannot change validation on a disposed AdvancedFormController.',
      );
    }

    _ownEnabled = validationEnabled;
    _publishSettings();
  }

  /// Sets when the fields of this tree validate themselves. Reaches every leaf
  /// field and subform that has no mode of its own; those keep theirs.
  ///
  /// A parent form's mode does not replace what you set here. Changing the mode
  /// validates nothing by itself, and drops validation the old mode started.
  ///
  /// Throws a [StateError] if this form has already been disposed — disposed
  /// controllers cannot be reused.
  void setValidationMode(ValidationMode validationMode) {
    if (isDisposed) {
      throw StateError(
        'Cannot change validation on a disposed AdvancedFormController.',
      );
    }

    _hasOwnMode = true;
    _mode = validationMode;
    _publishSettings();
  }

  /// Applies the settings of the form this one is a subform of. A mode this
  /// form claimed wins over `settings.mode`; `settings.enabled` applies either
  /// way, AND-ed with this form's own switch.
  @internal
  void applyValidationSettings(ValidationSettings settings) {
    final inherited = _hasOwnMode ? settings.overriddenBy(_mode) : settings;
    _mode = inherited.mode;
    _parentEnabled = inherited.enabled;
    _publishSettings();
  }

  @override
  void dispose() {
    _isDisposed = true;
    _runChildCleanups();
    for (final cleanup in _relationCleanups) {
      cleanup();
    }
    _relationCleanups.clear();
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

  Future<bool> _runValidate() async {
    final results = await Future.wait<bool>([
      if (value.validationEnabled)
        for (final field in value.fields) field.validate(),
      for (final subform in value.subforms) subform.validate(),
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
      // The error is watched next to the status because swapping one error code
      // for another leaves the status `invalid` while [validationErrors]
      // changes. Together the two cover every aggregate derived from a field.
      Object? lastError = field.value.error;
      void listener() {
        final state = field.value;
        if (state.value != lastValue) {
          lastValue = state.value;
          _handleValuesChanged();
        }
        if (state.status != lastStatus || state.error != lastError) {
          lastStatus = state.status;
          lastError = state.error;
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

  // The only place a child hears what to validate under, so a new attach path
  // cannot skip the rule.
  void _publishSettings() {
    final settings = (mode: _mode, enabled: _ownEnabled && _parentEnabled);
    final enabledChanged = settings.enabled != value.validationEnabled;

    if (settings != value._settings) {
      // A pass in flight answered under the old settings, so it must not be
      // handed to a caller asking under the new ones.
      _validateCall.invalidate();
      _setState(
        value._copyWith(
          validationMode: settings.mode,
          validationEnabled: settings.enabled,
        ),
      );
    }

    // Unconditional, while the state write is guarded: the children may have
    // changed even when the settings did not, and applying them twice costs
    // nothing.
    for (final field in value.fields) {
      field.applyValidationSettings(settings);
    }
    for (final subform in value.subforms) {
      subform.applyValidationSettings(settings);
    }

    if (enabledChanged) {
      for (final field in value.fields) {
        settings.enabled ? field.revalidateSync() : field.clearErrors();
      }
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
      revalidateSync();
    }
    _recomputeWasModified();
    _onValuesChanged.notifyListeners();
  }

  void _handleStatusChanged() {
    notifyListeners();
    _onStatusChanged.notifyListeners();
  }

  void _recomputeWasModified() {
    final subformsWereModified = value.subforms.any(
      (subform) => subform.value.wasModified,
    );
    final fieldsWereModified = !const DeepCollectionEquality()
        .equals(_initialFieldsState, getFieldValues());

    _setState(
      value._copyWith(wasModified: subformsWereModified || fieldsWereModified),
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
    this.validationMode = ValidationMode.disabled,
    this.validationEnabled = true,
  });

  /// Whether any field value differs from the last `registerFields`, or any
  /// subform was itself modified.
  final bool wasModified;

  /// List of all registered fields by this form.
  final List<AdvancedFieldController<dynamic, dynamic>> fields;

  /// Set of registered subforms. Reference equality is assumed.
  final Set<AdvancedFormController> subforms;

  /// When the fields of this tree validate themselves, with nobody calling
  /// [AdvancedFormController.validate]. Set it with
  /// [AdvancedFormController.setValidationMode].
  ///
  /// A field or a subform that claimed a mode of its own does not follow this
  /// one.
  final ValidationMode validationMode;

  /// Whether this section counts at all. While it is false every field in the
  /// tree behaves as [ValidationMode.disabled] and
  /// [AdvancedFormController.validate] skips them. Errors already on the fields
  /// still count toward [canSubmit].
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
  /// Only known errors count, so it is true on a form where nothing has been
  /// checked yet. It is false while any round is pending or validating. Use it
  /// to enable a submit button, and run [AdvancedFormController.validate]
  /// before you trust the values.
  bool get canSubmit => allFields.every((field) => field.value.isValid);

  /// Every error in the tree, keyed by field.
  Map<AdvancedFieldController<dynamic, dynamic>, dynamic>
      get validationErrors => {
            for (final field in allFields)
              if (field.value.error case final error?) field: error,
          };

  // What this form is running under, as one value.
  ValidationSettings get _settings =>
      (mode: validationMode, enabled: validationEnabled);

  AdvancedFormState _copyWith({
    bool? wasModified,
    List<AdvancedFieldController<dynamic, dynamic>>? fields,
    Set<AdvancedFormController>? subforms,
    ValidationMode? validationMode,
    bool? validationEnabled,
  }) =>
      AdvancedFormState(
        wasModified: wasModified ?? this.wasModified,
        fields: fields ?? this.fields,
        subforms: subforms ?? this.subforms,
        validationMode: validationMode ?? this.validationMode,
        validationEnabled: validationEnabled ?? this.validationEnabled,
      );

  @override
  List<Object?> get props => [
        wasModified,
        fields,
        subforms,
        validationMode,
        validationEnabled,
      ];
}
