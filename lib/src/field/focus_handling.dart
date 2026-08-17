part of 'advanced_field_controller.dart';

// The field's side of a [FocusNode]: the node itself, and turning a blur into
// the [handleUnfocus] the rest of the controller already knows how to act on.
mixin _FocusHandling on ChangeNotifier {
  /// Whether this controller has been disposed. Once true it stays true.
  bool get isDisposed;

  /// Optional label used in reported errors and as the `FocusNode` debug label.
  /// Not used for identity — fields are identified by reference.
  String? get name;

  /// The node the caller passed to the constructor, or null when this field
  /// makes its own.
  FocusNode? get _suppliedFocusNode;

  /// Tells the field that focus moved away from it.
  Future<void> handleUnfocus();

  FocusNode? _focusNode;

  // A FocusNode notifies for more than focus, so a blur would otherwise repeat.
  bool _hadFocus = false;

  /// The [FocusNode] bound to this field: the one given to the constructor, or
  /// one created on first use. See [ValidationMode.onUnfocus]. Throws a
  /// [StateError] once disposed.
  FocusNode get focusNode {
    if (isDisposed) {
      throw StateError(
        'Cannot use the focusNode of a disposed AdvancedFieldController.',
      );
    }

    return _focusNode ??= _attachFocusNode();
  }

  /// Requests focus via [focusNode]. A no-op once disposed.
  void focus() {
    if (isDisposed) {
      return;
    }

    focusNode.requestFocus();
  }

  FocusNode _attachFocusNode() {
    final node = _suppliedFocusNode ??
        FocusNode(
          debugLabel:
              'AdvancedFieldController${name?.isNotEmpty ?? false ? '($name)' : ''}',
        );
    return node..addListener(_handleFocusChange);
  }

  // Run from the constructor: a node the caller owns can be bound to a widget
  // directly, so its blurs must reach this field without anyone reading
  // [focusNode] first.
  void _bindSuppliedFocusNode() {
    if (_suppliedFocusNode != null) {
      _focusNode = _attachFocusNode();
    }
  }

  void _handleFocusChange() {
    final hasFocus = _focusNode?.hasFocus ?? false;
    if (hasFocus == _hadFocus) {
      return;
    }
    _hadFocus = hasFocus;
    if (!hasFocus) {
      // handleUnfocus reports its own failures, so nothing escapes into the zone.
      unawaited(handleUnfocus());
    }
  }

  // Only a node this field created is this field's to dispose.
  void _disposeFocusNode() {
    if (_suppliedFocusNode == null) {
      _focusNode?.dispose();
    } else {
      _focusNode?.removeListener(_handleFocusChange);
    }
    _focusNode = null;
  }
}
