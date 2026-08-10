import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:leancode_forms/src/form/advanced_form_controller.dart';

/// Creates, exposes, and disposes an [AdvancedFormController] for its
/// descendants — a small, forms-only replacement for wiring
/// `ChangeNotifierProvider` from the `provider` package.
///
/// The default constructor is **lazy**: [create] doesn't run until a
/// descendant first looks the controller up via [watch] or [read]. A
/// controller that's never looked up is never created and never disposed;
/// once created, it's disposed automatically when this widget unmounts.
///
/// Use [AdvancedFormScope.value] instead when the controller already exists
/// and is owned elsewhere — that controller is never disposed by this widget.
///
/// ```dart
/// AdvancedFormScope<MyFormController>(
///   create: (context) => MyFormController(),
///   child: const MyForm(),
/// )
///
/// // Elsewhere, below the scope:
/// final controller = context.watchForm<MyFormController>();
/// ```
///
/// [AdvancedFormScopeExtension] provides `context.watchForm<T>()` and
/// `context.readForm<T>()` as shorthands for [watch] and [read].
class AdvancedFormScope<T extends AdvancedFormController>
    extends StatefulWidget {
  /// Creates a scope that builds its controller lazily, on first lookup, via
  /// [create]. The controller is disposed when this widget unmounts.
  const AdvancedFormScope({
    required T Function(BuildContext context) this.create,
    required this.child,
    super.key,
  }) : value = null;

  /// Creates a scope around a controller that already exists and is owned
  /// elsewhere. Ownership is not transferred: this widget never disposes
  /// [value], even when it unmounts.
  const AdvancedFormScope.value({
    required T this.value,
    required this.child,
    super.key,
  }) : create = null;

  /// Builds the controller on first lookup. `null` when constructed via
  /// [AdvancedFormScope.value].
  final T Function(BuildContext context)? create;

  /// A controller owned elsewhere. `null` when constructed via the default
  /// constructor.
  final T? value;

  /// The subtree that can look this scope's controller up.
  final Widget child;

  /// Looks up the nearest [AdvancedFormScope]`<T>` above [context] and
  /// subscribes so [context] rebuilds on every notification.
  ///
  /// Throws an [AdvancedFormScopeNotFoundException] if no matching scope is
  /// found — lookup matches the *exact* type argument `T`.
  static T watch<T extends AdvancedFormController>(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<_AdvancedFormScope<T>>();
    if (scope == null) {
      throw AdvancedFormScopeNotFoundException(T);
    }
    return scope.state._ensureController();
  }

  /// Looks the controller up without subscribing to rebuilds — `context`
  /// will not rebuild when the controller notifies its listeners.
  ///
  /// Throws an [AdvancedFormScopeNotFoundException] if no matching scope is
  /// found.
  static T read<T extends AdvancedFormController>(BuildContext context) {
    final scope =
        context.getInheritedWidgetOfExactType<_AdvancedFormScope<T>>();
    if (scope == null) {
      throw AdvancedFormScopeNotFoundException(T);
    }
    return scope.state._ensureController();
  }

  @override
  State<AdvancedFormScope<T>> createState() => _AdvancedFormScopeState<T>();
}

class _AdvancedFormScopeState<T extends AdvancedFormController>
    extends State<AdvancedFormScope<T>> {
  T? _controller;
  bool _ownsController = false;
  int _version = 0;

  /// Creates the controller on first call and starts listening to it.
  /// Subsequent calls return the same instance.
  T _ensureController() {
    final existing = _controller;
    if (existing != null) {
      return existing;
    }

    final controller = widget.value ?? widget.create!(context);
    assert(
      !controller.isDisposed,
      'AdvancedFormScope was given an already-disposed AdvancedFormController.',
    );
    _ownsController = widget.value == null;
    _controller = controller;
    controller.addListener(_handleControllerNotify);
    return controller;
  }

  void _handleControllerNotify() {
    if (!mounted) {
      return;
    }
    // A controller can notify synchronously while still being created
    // mid-build (e.g. from within its own constructor). setState is not
    // allowed during the build phase, so defer to right after this frame.
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() => _version++);
        }
      });
    } else {
      setState(() => _version++);
    }
  }

  @override
  void didUpdateWidget(covariant AdvancedFormScope<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    final newValue = widget.value;
    final current = _controller;
    if (newValue != null && current != null && !identical(newValue, current)) {
      current.removeListener(_handleControllerNotify);
      _ownsController = false;
      _controller = newValue;
      newValue.addListener(_handleControllerNotify);
      _version++;
    }
  }

  @override
  void dispose() {
    final controller = _controller;
    if (controller != null) {
      if (_ownsController) {
        controller.dispose();
      } else {
        controller.removeListener(_handleControllerNotify);
      }
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _AdvancedFormScope<T>(
      state: this,
      version: _version,
      child: widget.child,
    );
  }
}

/// Carries the version counter [AdvancedFormScope.watch] subscribes to, and
/// a reference to the [State] that owns the controller, which
/// [AdvancedFormScope.read] reads directly without subscribing.
class _AdvancedFormScope<T extends AdvancedFormController>
    extends InheritedWidget {
  const _AdvancedFormScope({
    required this.state,
    required this.version,
    required super.child,
  });

  final _AdvancedFormScopeState<T> state;
  final int version;

  @override
  bool updateShouldNotify(_AdvancedFormScope<T> oldWidget) =>
      version != oldWidget.version;
}

/// Thrown by [AdvancedFormScope.watch] and [AdvancedFormScope.read] when no
/// [AdvancedFormScope] with a matching type argument is found above the
/// given [BuildContext].
class AdvancedFormScopeNotFoundException implements Exception {
  /// Creates an exception for a lookup of [controllerType] that found no
  /// matching scope.
  AdvancedFormScopeNotFoundException(this.controllerType);

  /// The exact type argument the failed lookup was made with.
  final Type controllerType;

  @override
  String toString() => 'AdvancedFormScopeNotFoundException: no '
      'AdvancedFormScope<$controllerType> found above this widget.\n'
      "Lookup matches the exact type argument, not the controller's runtime "
      'type — an AdvancedFormScope<SimpleFormController> does not satisfy a '
      'lookup for AdvancedFormScope<AdvancedFormController>, even though '
      'SimpleFormController extends it.';
}

/// Context shorthands for [AdvancedFormScope] lookups.
extension AdvancedFormScopeExtension on BuildContext {
  /// Shorthand for [AdvancedFormScope.watch].
  T watchForm<T extends AdvancedFormController>() =>
      AdvancedFormScope.watch<T>(this);

  /// Shorthand for [AdvancedFormScope.read].
  T readForm<T extends AdvancedFormController>() =>
      AdvancedFormScope.read<T>(this);
}
