part of 'advanced_field_controller.dart';

// The field's side of a [FocusNode]: the node itself, and turning a blur into
// the [handleUnfocus] the rest of the controller already knows how to act on.
mixin _FocusHandling on ChangeNotifier {
  /// Whether this controller has been disposed. Once true it stays true.
  bool get isDisposed;

  /// Optional label used in reported errors and as the `FocusNode` debug label.
  /// Not used for identity — fields are identified by reference.
  String? get name;

  /// Tells the field the user has left it.
  void handleUnfocus();

  FocusNode? _focusNode;

  // A FocusNode notifies for more than focus, so a blur would otherwise repeat.
  bool _hadFocus = false;

  /// The [FocusNode] bound to this field, created on first use. See
  /// [ValidationMode.onUnfocus]. Throws a [StateError] once disposed.
  FocusNode get focusNode {
    if (isDisposed) {
      throw StateError(
        'Cannot use the focusNode of a disposed AdvancedFieldController.',
      );
    }

    return _focusNode ??= FocusNode(
      debugLabel:
          'AdvancedFieldController${name?.isNotEmpty ?? false ? '($name)' : ''}',
    )..addListener(_handleFocusChange);
  }

  /// Requests focus via [focusNode]. A no-op once disposed.
  void focus() {
    if (isDisposed) {
      return;
    }

    focusNode.requestFocus();
  }

  void _handleFocusChange() {
    final hasFocus = _focusNode?.hasFocus ?? false;
    if (hasFocus == _hadFocus) {
      return;
    }
    _hadFocus = hasFocus;
    if (!hasFocus) {
      handleUnfocus();
    }
  }

  void _disposeFocusNode() {
    _focusNode?.dispose();
    _focusNode = null;
  }
}
