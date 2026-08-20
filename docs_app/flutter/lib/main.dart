/*
 * AI-Provenance:
 *   model: Claude Opus 5
 *   harness: Cursor
 */
import 'dart:js_interop';
import 'dart:ui_web' as ui_web;

import 'package:advanced_forms_docs_islands/generated/registry.dart';
import 'package:advanced_forms_docs_islands/support/island_shell.dart';
import 'package:advanced_forms_docs_islands/support/multi_view_app.dart';
import 'package:flutter/widgets.dart';

/// What the host page passes to `app.addView({initialData: ...})`.
extension type _IslandOptions._(JSObject _) implements JSObject {
  external String? get exampleId;
}

void main() {
  // The docs page owns the address bar. Without this a Navigator inside an
  // island can rewrite the URL of the page hosting it, and multi-view routing
  // is not supported anyway (flutter/flutter#139174).
  ui_web.urlStrategy = null;

  // `runApp` needs an implicit view, which does not exist in multi-view mode.
  // `runWidget` renders only into views the host has explicitly added.
  runWidget(
    MultiViewApp(
      viewBuilder: (context) {
        final viewId = View.of(context).viewId;
        final options =
            ui_web.views.getInitialData(viewId) as _IslandOptions?;
        final exampleId = options?.exampleId;

        return IslandShell(
          exampleId: exampleId,
          builder: exampleId == null ? null : examples[exampleId],
        );
      },
    ),
  );
}
