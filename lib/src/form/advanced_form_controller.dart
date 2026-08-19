import 'dart:async';

import 'package:advanced_forms/src/field/advanced_field_controller.dart';
import 'package:advanced_forms/src/form/advanced_form_state.dart';
import 'package:advanced_forms/src/utils/shared_call.dart';
import 'package:advanced_forms/src/validation_mode.dart';
import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
// Older Flutter versions need this import
// ignore: unnecessary_import
import 'package:meta/meta.dart';

part 'child_wiring.dart';
part 'relations.dart';

/// A parent of multiple [AdvancedFieldController]s. Manages group validation,
/// tracks changes, and cleans up the resources it owns.
///
/// A form is a tree: it is the root of its own tree, its direct leaves are
/// fields, and its subtrees are subforms. Most methods broadcast to the whole
/// tree. Cycles are not supported and not checked against.
class AdvancedFormController
    with ChangeNotifier, _ChildWiring, _Relations
    implements ValueListenable<AdvancedFormState> {
  /// Creates a new [AdvancedFormController].
  ///
  /// A [validationMode] given here is this form's own: a parent form's mode
  /// does not replace it.
  AdvancedFormController({
    this.debugName = '',
    this.validateAll = false,
    ValidationMode? validationMode,
  })  : _ownMode = validationMode,
        _value = AdvancedFormState(
          validationMode: validationMode ?? ValidationMode.manual,
        );

  /// A label you can log to tell nested subforms apart. The package never reads
  /// it.
  final String debugName;

  /// When true, any field's change re-runs the sync validator across the tree.
  /// See [revalidateSync].
  @override
  final bool validateAll;

  AdvancedFormState _value;

  @override
  AdvancedFormState get value => _value;

  bool _isDisposed = false;

  /// Whether this controller has been disposed. Once true it stays true;
  /// disposed controllers are not to be reused.
  @override
  bool get isDisposed => _isDisposed;

  // Internals with no public surface.
  // Explicit type — inference would widen the error type from dynamic to Object.
  final Set<AdvancedFieldController<dynamic, dynamic>> _ownedFields = {};
  final Set<AdvancedFormController> _ownedSubforms = {};
  final _validateCall = SharedCall<bool>();

  // null: follow the parent form's mode. Non-null: this form manages its own.
  ValidationMode? _ownMode;

  // This form's own on/off switch and what the parent last sent.
  // validationEnabled is true only when both are on.
  var _ownEnabled = true;
  var _parentEnabled = true;

  /// Registers [fields] as this form's own fields and takes ownership of them,
  /// disposing them when this form is disposed. Their current values become the
  /// [AdvancedFormState.wasModified] baseline.
  ///
  /// The tree's mode is applied to new fields immediately. Removed fields stop
  /// validating unless they have their own mode.
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
    for (final field in value.fields) {
      if (!fields.contains(field)) {
        // enabled: true keeps a field's own mode; others get disabled, same as
        // if they were never registered.
        field.applyValidationMode(ValidationMode.manual, enabled: true);
      }
    }
    // value.fields is replaced but _ownedFields keeps growing on purpose —
    // deregistered fields stop participating but are still disposed with the form.
    _setState(value.copyWith(fields: fields));

    _ownedFields.addAll(fields);
    _initialFieldsState = getFieldValues();
    _wireChildren();
    _publishValidationMode(value.validationMode);
    _recomputeWasModified();
    _onValuesChanged.notifyListeners();
  }

  /// Returns this form's own field values, excluding subforms'.
  @override
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
  /// [AdvancedFormState.validationMode] is neither consulted nor changed; every
  /// field runs, including ones the user never touched. Returns `true` for a
  /// subtree with [AdvancedFormState.validationEnabled] false, `false` once
  /// disposed.
  ///
  /// Calling this again before the first call finishes returns the same
  /// result; it does not start a second validation run.
  Future<bool> validate() {
    // Check in-flight first — callers mid-disposal still get the running
    // validate() result.
    if (_validateCall.inFlight case final inFlight?) {
      return inFlight;
    }

    return isDisposed ? Future.value(false) : _validateCall.run(_runValidate);
  }

  /// Re-runs the **sync** validator on every leaf field in the tree that its
  /// mode and the interaction guarantee allow.
  ///
  /// Deliberately not [validate]: a sibling's edit does not change a field's
  /// own value, so async validation is not re-run. Read-only fields are
  /// included — freezing a value does not stop its rule from being re-evaluated.
  @override
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

  /// Sets validation mode for this tree and passes it to subforms. Subforms
  /// with their own mode keep it. Does not trigger validation by itself.
  void setValidationMode(ValidationMode mode) {
    _ownMode = mode;
    _publishValidationMode(mode);
  }

  /// Applies the parent's mode and enabled flag; this form's own mode wins if set.
  @internal
  void applyValidationMode(ValidationMode mode, {required bool enabled}) {
    _parentEnabled = enabled;
    _publishValidationMode(_ownMode ?? mode);
  }

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

  /// Adds an owned subform to the current form and takes ownership of it,
  /// disposing it when this form is disposed. A noop if [form] is already a
  /// subform.
  ///
  /// Ownership outlives [removeSubform]: a detached subform is still disposed
  /// with this form, the same way a deregistered field is.
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
    // value.subforms is what participates; _ownedSubforms is what gets disposed.
    _setState(value.copyWith(subforms: {...value.subforms, form}));
    _ownedSubforms.add(form);
    _wireChildren();
    _publishValidationMode(value.validationMode);
    _recomputeWasModified();
  }

  /// Detaches an owned subform: it stops validating, notifying and counting
  /// towards this form's state. A noop if [form] was not a subform.
  ///
  /// Does not dispose [form] — this form still owns it and disposes it in
  /// [dispose], so a detached subform can be re-attached with [addSubform].
  ///
  /// Throws a [StateError] if this form has already been disposed — disposed
  /// controllers cannot be reused.
  void removeSubform(AdvancedFormController form) {
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
    _wireChildren();
    _recomputeWasModified();
  }

  /// Turns validation for this whole subtree on or off — above every mode.
  /// See [AdvancedFormState.validationEnabled].
  ///
  /// Throws a [StateError] if this form has already been disposed — disposed
  /// controllers cannot be reused.
  void setValidationEnabled(bool validationEnabled) {
    if (isDisposed) {
      throw StateError(
        'Cannot change validation on a disposed AdvancedFormController.',
      );
    }
    if (validationEnabled == _ownEnabled) {
      return;
    }
    _ownEnabled = validationEnabled;
    _publishValidationMode(value.validationMode);
  }

  @override
  void dispose() {
    _isDisposed = true;
    _runChildCleanups();
    _runRelationCleanups();
    for (final field in _ownedFields) {
      field.dispose();
    }
    _ownedFields.clear();
    // Detached subforms are disposed too, and one a caller disposed itself is
    // skipped rather than disposed twice.
    for (final subform in _ownedSubforms) {
      if (!subform.isDisposed) {
        subform.dispose();
      }
    }
    _ownedSubforms.clear();
    _onValuesChanged.dispose();
    _onStatusChanged.dispose();
    super.dispose();
  }

  Future<bool> _runValidate() async {
    // Disabled subtrees skip validation, same as canSubmit ignores them —
    // so validate() and canSubmit always agree.
    if (!value.validationEnabled) {
      return true;
    }

    final results = await Future.wait<bool>([
      for (final field in value.fields) field.validate(),
      for (final subform in value.subforms) subform.validate(),
    ]);

    return results.every((result) => result);
  }

  // The only place mode and enabled reach this tree's children.
  void _publishValidationMode(ValidationMode mode) {
    final enabled = _ownEnabled && _parentEnabled;
    final enabledChanged = enabled != value.validationEnabled;

    if (mode != value.validationMode || enabledChanged) {
      // Settings changed — drop any validate() still running under the old ones.
      _validateCall.invalidate();
      _setState(
        value.copyWith(validationMode: mode, validationEnabled: enabled),
      );
    }

    // Always sent to children — they may have changed even if mode did not.
    // Already-correct children ignore it, so this is cheap.
    for (final field in value.fields) {
      field.applyValidationMode(mode, enabled: enabled);
    }
    for (final subform in value.subforms) {
      subform.applyValidationMode(mode, enabled: enabled);
    }

    if (enabledChanged) {
      for (final field in value.fields) {
        if (enabled) {
          field.revalidateSync();
        } else {
          field.clearErrors();
        }
      }
    }
  }

  // Calls each subform's method instead of flattening allFields, so
  // subclasses that override still run.
  void _broadcast(
    void Function(AdvancedFieldController<dynamic, dynamic> field) onField,
    void Function(AdvancedFormController subform) onSubform,
  ) {
    value.fields.forEach(onField);
    value.subforms.forEach(onSubform);
  }

  @override
  void _setState(AdvancedFormState newValue) {
    if (_isDisposed || newValue == _value) {
      return;
    }
    _value = newValue;
    notifyListeners();
  }
}
