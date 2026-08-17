part of 'advanced_form_controller.dart';

// Listeners on fields this form does not own — for external callbacks only.
// Does not update the form's own state.
mixin _Relations on ChangeNotifier {
  /// Whether this controller has been disposed. Once true it stays true.
  bool get isDisposed;

  final _relationCleanups = <VoidCallback>[];

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

  void _runRelationCleanups() {
    for (final cleanup in _relationCleanups) {
      cleanup();
    }
    _relationCleanups.clear();
  }
}
