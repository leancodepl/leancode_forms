import 'dart:async';

import 'package:leancode_forms/src/field/advanced_field_controller.dart';

/// Deprecated migration helper for [AdvancedFieldController].
///
/// This is **not** part of the listening model of this library — that model is
/// `Listenable`: `addListener`/`removeListener`,
/// [AdvancedFieldController.subscribeToFields], and builder widgets. It exists
/// only so that codebases migrating from 0.1.x, which built listening patterns
/// on cubit streams, do not have to rewrite them in the same pass.
extension AdvancedFieldControllerListen<T, E extends Object>
    on AdvancedFieldController<T, E> {
  /// Bridges this controller to a broadcast [Stream] of states.
  ///
  /// In 0.1.x, `FieldCubit` extended `Cubit`, so `stream` was inherited public
  /// API — both this library and downstream code composed fields through it.
  /// This getter replaces it, so stream-based helpers written against
  /// `FieldCubit.stream` keep compiling until they can be rewritten.
  ///
  /// Note: every call to this getter allocates a new [StreamController] —
  /// store the stream in a variable instead of reading the getter repeatedly.
  /// Listeners are attached lazily on first subscription and detached when
  /// the last subscription is cancelled.
  @Deprecated(
    'Migration bridge for 0.1.x cubit streams, to be removed in 0.3.0. '
    'Use addListener, subscribeToFields, or the builder widgets instead.',
  )
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
