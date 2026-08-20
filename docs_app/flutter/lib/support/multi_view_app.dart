/*
 * AI-Provenance:
 *   model: Claude Opus 5
 *   harness: Cursor
 */
import 'dart:ui' show FlutterView;

import 'package:flutter/widgets.dart';

/// Calls [viewBuilder] for every view the host page attaches, and renders the
/// result into that view.
///
/// Taken from the multi-view embedding guide at
/// https://docs.flutter.dev/platform-integration/web/embedding-flutter-web —
/// in embedded mode there is no implicit view, so the root widget has to build
/// a [View] per entry in `platformDispatcher.views` and group them under a
/// [ViewCollection]. View additions and removals arrive as
/// [WidgetsBindingObserver.didChangeMetrics].
class MultiViewApp extends StatefulWidget {
  const MultiViewApp({super.key, required this.viewBuilder});

  final WidgetBuilder viewBuilder;

  @override
  State<MultiViewApp> createState() => _MultiViewAppState();
}

class _MultiViewAppState extends State<MultiViewApp>
    with WidgetsBindingObserver {
  Map<Object, Widget> _views = <Object, Widget>{};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _updateViews();
  }

  @override
  void didUpdateWidget(MultiViewApp oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The builder changed, so every view has to be rebuilt through it.
    _views.clear();
    _updateViews();
  }

  @override
  void didChangeMetrics() => _updateViews();

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _updateViews() {
    final newViews = <Object, Widget>{};
    for (final view in WidgetsBinding.instance.platformDispatcher.views) {
      newViews[view.viewId] = _views[view.viewId] ?? _createViewWidget(view);
    }
    setState(() => _views = newViews);
  }

  Widget _createViewWidget(FlutterView view) {
    return View(
      view: view,
      child: Builder(builder: widget.viewBuilder),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ViewCollection(views: _views.values.toList(growable: false));
  }
}
