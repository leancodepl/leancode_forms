part of 'advanced_form_controller.dart';

// The form's side of its children: the listeners it keeps on them, and what a
// child's change means for the aggregates this form publishes.
mixin _ChildWiring on ChangeNotifier {
  /// The current state of this form.
  AdvancedFormState get value;

  /// When true, any field's change re-runs the sync validator across the tree.
  bool get validateAll;

  /// Re-runs the **sync** validator on every leaf field the mode allows.
  void revalidateSync();

  /// Returns this form's own field values, excluding subforms'.
  List<dynamic> getFieldValues();

  void _setState(AdvancedFormState newValue);

  final _onValuesChanged = ChangeNotifier();

  /// Fires when any leaf field's value changes (recursively through subforms),
  /// or when fields are registered.
  Listenable get onValuesChanged => _onValuesChanged;

  final _onStatusChanged = ChangeNotifier();

  /// Fires when any leaf field's status or error changes (recursively through
  /// subforms).
  Listenable get onStatusChanged => _onStatusChanged;

  final _childCleanups = <VoidCallback>[];
  var _initialFieldsState = const <dynamic>[];

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
}
