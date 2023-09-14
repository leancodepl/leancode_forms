import 'dart:async';

import 'package:flutter/material.dart';

/// A callback that disposes of a resource.
typedef DisposeCallback = FutureOr<void> Function();

/// Disposable mixin with automatic disposal
mixin Disposable {
  final List<DisposeCallback> _disposeCallbacks = [];
  bool _isDisposed = false;

  /// Whether the object is disposed.
  bool get isDisposed => _isDisposed;

  /// Adds a [disposeCallback] to be called when the object is disposed.
  @protected
  void addDisposable(DisposeCallback disposeCallback) {
    _disposeCallbacks.add(disposeCallback);
  }

  /// Disposes of the object.
  @mustCallSuper
  Future<void> dispose() async {
    final future = Future.wait(_disposeCallbacks.map((e) async => await e()));
    _disposeCallbacks.clear();
    await future;
    _isDisposed = true;
  }
}
