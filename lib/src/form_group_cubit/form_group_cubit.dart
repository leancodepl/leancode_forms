import 'dart:async';

import 'package:bloc_dispose_scope/bloc_dispose_scope.dart';
import 'package:collection/collection.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:leancode_forms/src/field/cubit/field_cubit.dart';
import 'package:leancode_forms/src/utils/extensions/stream_extensions';
import 'package:rxdart/rxdart.dart';

/// A parent of multiple [FieldCubit]s. Manages group validation and tracks changes
/// as well as cleans up needed resources.
///
/// A form is a tree which can be recursively defined:
///   1. A form is the root of its own form tree
///   2. A form has direct leaves, which are fields
///   3. A form can have subtrees, which are forms (called subforms)
///
/// Most methods broadcast to all subforms.
///
/// Introducing cycles in forms is not supported and not checked against (most likely will cause a stack overflow somewhere).
class FormGroupCubit extends Cubit<FormGroupState> with Disposable {
  /// Creates a new [FormGroupCubit].
  FormGroupCubit({
    this.debugName = '',
    this.validateAll = false,
  }) : super(const FormGroupState()) {
    _fieldsController.disposedBy(_disposeScope);
    _onFieldsChangeSubscription?.disposedBy(_disposeScope);
    stream
        .map(
          (event) => (
            fields: event.fields,
            subforms: event.subforms,
          ),
        )
        .distinct()
        .listen(_onFieldsChanged)
        .disposedBy(_disposeScope);

    onValuesChangedStream
        .listen((_) => _onFieldsStateChanged())
        .disposedBy(_disposeScope);

    state.subforms.map((e) => e.disposedBy(_disposeScope));
  }

  final _disposeScope = DisposeScope();

  /// A debug label for this form. Not significant to the form.
  final String debugName;

  /// When true, whenever any field changes, all other fields get
  /// their validator called if they have autovalidate enabled.
  final bool validateAll;

  List<dynamic> _initialFieldsState = <dynamic>[];

  StreamSubscription<dynamic>? _onFieldsChangeSubscription;
  final _fieldsController = StreamController<dynamic>.broadcast();

  /// Emits when any of the leaf fields have their value changed.
  Stream<void> get onValuesChangedStream => _fieldsController.stream;

  Future<void> _onFieldsChanged(
    ({
      List<FieldCubit<dynamic, dynamic>> fields,
      Set<FormGroupCubit> subforms,
    }) data,
  ) async {
    await _onFieldsChangeSubscription?.cancel();
    final (:fields, :subforms) = data;

    _onFieldsChangeSubscription = Rx.merge<dynamic>(
      fields.map(
        (field) {
          return field.stream
              .map<dynamic>((state) => state.value)
              .distinctWithFirst(field.state.value);
        },
      ).followedBy(
        subforms.map((e) => e.onValuesChangedStream),
      ),
    ).listen(_fieldsController.add);
  }

  /// Takes ownership of registered fields. Will dispose all cubits.
  /// Fields are expected to be filled with initial states.
  void registerFields(List<FieldCubit<dynamic, dynamic>> fields) {
    emit(
      FormGroupState(
        wasModified: state.wasModified,
        fields: fields,
        subforms: state.subforms,
        validationEnabled: state.validationEnabled,
      ),
    );

    fields.map((e) => e.disposedBy(_disposeScope));

    _initialFieldsState = getFieldValues();
    // inform that the fields have changed
    _fieldsController.add(null);
  }

  /// Returns a list of all field values.
  @visibleForTesting
  List<dynamic> getFieldValues() {
    return state.fields.map<dynamic>((f) => f.state.value).toList();
  }

  /// Recursively calls validate on all subforms/fields if `state.validationEnabled` is true.
  /// [enableAutovalidate] can enable autovalidate on this form.
  ///
  /// Returns the result of validate calls, or always `true` if `state.validationEnabled` is false.
  bool validate({bool enableAutovalidate = true}) {
    if (enableAutovalidate) {
      setAutovalidate(true);
    }
    if (!state.validationEnabled) {
      return true;
    }

    // Eager list to prevent short circuits, all fields should be called with validate
    return [
      for (final field in state.fields) field.validate(),
      for (final subform in state.subforms)
        subform.validate(enableAutovalidate: enableAutovalidate),
    ].every((e) => e);
  }

  /// Marks all leaf fields as readonly.
  void markReadOnly() {
    for (final field in state.fields) {
      field.markReadOnly();
    }
    for (final subform in state.subforms) {
      subform.markReadOnly();
    }
  }

  /// Sets autovalidate on all leaf fields.
  // ignore: avoid_positional_boolean_parameters
  void setAutovalidate(bool autovalidate) {
    for (final field in state.fields) {
      field.setAutovalidate(autovalidate);
    }
    for (final subform in state.subforms) {
      subform.setAutovalidate(autovalidate);
    }
  }

  /// Clears all errors on all leaf fields.
  void clearErrors() {
    for (final field in state.fields) {
      field.clearErrors();
    }
    for (final subform in state.subforms) {
      subform.clearErrors();
    }
  }

  /// Adds a subform to the current form.
  /// If [form] was already added as a subform this is a noop.
  void addSubform(FormGroupCubit form) {
    emit(
      FormGroupState(
        wasModified: state.wasModified,
        fields: state.fields,
        subforms: {...state.subforms, form},
        validationEnabled: state.validationEnabled,
      ),
    );
  }

  /// Removes and disposes an owned subform.
  /// If [form] was not a subform this is a noop.
  Future<void> removeSubform(FormGroupCubit form) async {
    if (state.subforms.contains(form)) {
      emit(
        FormGroupState(
          wasModified: state.wasModified,
          fields: state.fields,
          subforms: {...state.subforms}..remove(form),
          validationEnabled: state.validationEnabled,
        ),
      );
      await form.close();
    }
  }

  /// Calls validate on all fields with autovalidate on.
  void validateWithAutovalidate() {
    for (final field in state.fields) {
      if (field.state.autovalidate) {
        field.validate();
      }
    }
    for (final subform in state.subforms) {
      subform.validateWithAutovalidate();
    }
  }

  /// Changes optionality of this form. When `validationEnabled` is set to false,
  /// all errors are cleared.
  // ignore: avoid_positional_boolean_parameters
  void setValidationEnabled(bool validationEnabled) {
    if (validationEnabled == state.validationEnabled) {
      return;
    }
    emit(
      FormGroupState(
        wasModified: state.wasModified,
        fields: state.fields,
        subforms: state.subforms,
        validationEnabled: validationEnabled,
      ),
    );
    if (validationEnabled) {
      validateWithAutovalidate();
    } else {
      clearErrors();
    }
  }

  void _onFieldsStateChanged() {
    final subformsWereModified = state.subforms.any(
      (subform) => subform.state.wasModified,
    );
    late final fieldsWereModified = !const DeepCollectionEquality()
        .equals(_initialFieldsState, getFieldValues());

    if (validateAll) {
      validateWithAutovalidate();
    }

    emit(
      FormGroupState(
        wasModified: state.wasModified,
        fields: state.fields,
        subforms: state.subforms,
        validationEnabled: subformsWereModified || fieldsWereModified,
      ),
    );
  }

  @override
  Future<void> close() async {
    await dispose();
    return super.close();
  }

  @override
  Future<void> dispose() async {
    await _fieldsController.close();
  }
}

/// The state of a [FormGroupCubit].
class FormGroupState {
  /// Creates a new [FormGroupState].
  const FormGroupState({
    this.wasModified = false,
    this.fields = const [],
    this.subforms = const {},
    this.validationEnabled = true,
  });

  /// wasModified is true when any of the field values differ since the
  /// last `registerFields` or when any of the subforms has wasModified=true.
  final bool wasModified;

  /// List of all registered fields by this form.
  final List<FieldCubit<dynamic, dynamic>> fields;

  /// Set of registered subforms. Reference equality is assumed.
  final Set<FormGroupCubit> subforms;

  /// If false, validators are not ran and `validate` always returns true.
  final bool validationEnabled;
}
