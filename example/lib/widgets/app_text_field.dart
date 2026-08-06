import 'package:flutter/material.dart';

/// A text field that renders an externally-owned [TextEditingController] and
/// [FocusNode]. The widget never disposes the controller, and only disposes a
/// fallback [FocusNode] it allocated itself.
class AppTextField extends StatefulWidget {
  const AppTextField({
    super.key,
    required this.controller,
    this.focusNode,
    this.onUnfocus,
    this.onFieldSubmitted,
    this.trimOnUnfocus = false,
    this.labelText,
    this.hintText,
    this.errorText,
    this.suffix,
    this.onSetToInitial,
  });

  final TextEditingController controller;
  final FocusNode? focusNode;
  final VoidCallback? onUnfocus;
  final ValueChanged<String>? onFieldSubmitted;
  final bool trimOnUnfocus;
  final String? labelText;
  final String? hintText;
  final String? errorText;
  final Widget? suffix;
  final VoidCallback? onSetToInitial;

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  FocusNode? _ownedFocusNode;

  FocusNode get _focusNode =>
      widget.focusNode ?? (_ownedFocusNode ??= FocusNode());

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _ownedFocusNode?.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    if (_focusNode.hasFocus) {
      return;
    }
    widget.onUnfocus?.call();
    if (widget.trimOnUnfocus) {
      widget.controller.text = widget.controller.text.trim();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Flexible(
          child: TextFormField(
            autocorrect: false,
            focusNode: _focusNode,
            controller: widget.controller,
            onTapOutside: (_) => _focusNode.unfocus(),
            onFieldSubmitted: widget.onFieldSubmitted,
            decoration: InputDecoration(
              labelText: widget.labelText,
              hintText: widget.hintText,
              errorText: widget.errorText,
              suffix: widget.suffix,
            ),
          ),
        ),
        const SizedBox(width: 16),
        ElevatedButton(
          onPressed: widget.controller.clear,
          child: const Text('Empty'),
        ),
        if (widget.onSetToInitial case final onSetToInitial?) ...[
          const SizedBox(width: 16),
          ElevatedButton(
            onPressed: onSetToInitial,
            child: const Text('Set to initial'),
          ),
        ],
      ],
    );
  }
}
