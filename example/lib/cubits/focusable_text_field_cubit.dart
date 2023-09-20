import 'package:flutter/material.dart';
import 'package:leancode_forms/leancode_forms.dart';

class FocusableTextFieldCubit<E extends Object> extends TextFieldCubit<E> {
  FocusableTextFieldCubit({
    super.initialValue,
    super.validator,
    super.asyncValidator,
    super.asyncValidationDebounce,
  });

  /// Focuses the field.
  void focus() => focusNode.requestFocus();

  /// The focus node of the field.
  final focusNode = FocusNode();
}
