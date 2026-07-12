import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:leancode_forms/src/field/advanced_field_controller.dart';

/// Migration helpers for [AdvancedFieldController].
///
/// These utilities are **not** part of the core listening model of this
/// library — that model is [Listenable]: `addListener`/`removeListener`,
/// [AdvancedFieldController.subscribeToFields], and builder widgets. They
/// exist as an escape hatch for codebases migrating from 0.1.x that built
/// listening patterns on cubit streams. For new code, prefer the core model.
extension AdvancedFieldControllerListen<T, E extends Object>
    on AdvancedFieldController<T, E> {
  /// Calls [onChange] whenever the part of the field value selected by
  /// [select] changes.
  ///
  /// A migration aid for 0.1.x codebases that wired field dependencies with
  /// stream-based `select`/`listen` extensions on cubits. In new code, prefer
  /// [AdvancedFieldController.subscribeToFields] for revalidation
  /// dependencies, or a plain `addListener` with your own comparison.
  ///
  /// Returns a cleanup callback — call it to stop listening.
  VoidCallback onValueChange<R>(
    R Function(T value) select,
    void Function(R value) onChange,
  ) {
    var last = select(fieldValue);

    void listener() {
      final next = select(fieldValue);
      if (next == last) {
        return;
      }

      last = next;

      onChange(next);
    }

    addListener(listener);

    return () => removeListener(listener);
  }

  /// Bridges this controller to a broadcast [Stream] of states.
  ///
  /// This is a **last-resort migration bridge** for that composes fields with
  /// stream operators (e.g. rxdart) and cannot be rewritten right away. It is
  /// not the recommended way to observe a field — new code should
  /// use `addListener`, [AdvancedFieldController.subscribeToFields], or the
  /// builder widgets instead. Expect this bridge to be the first candidate
  /// for deprecation once migrations are over.
  ///
  /// Note: every call to this getter allocates a new [StreamController] —
  /// store the stream in a variable instead of reading the getter repeatedly.
  /// Listeners are attached lazily on first subscription and detached when
  /// the last subscription is cancelled.
  Stream<AdvancedFieldState<T, E>> get stream {
    StreamController<AdvancedFieldState<T, E>>? controller;

    void listener() => controller?.add(value);

    controller = StreamController.broadcast(
      onListen: () => addListener(listener),
      onCancel: () => removeListener(listener),
    );

    return controller.stream;
  }
}
