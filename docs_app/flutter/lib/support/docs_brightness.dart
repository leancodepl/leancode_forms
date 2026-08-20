/*
 * AI-Provenance:
 *   model: Claude Opus 5
 *   harness: Cursor
 */
import 'dart:js_interop';

import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

/// Tracks the colour scheme of the docs page the islands are embedded in.
///
/// The islands share a document with the docs site, so instead of being told
/// about theme changes over a JS bridge they watch what next-themes (used by
/// fumadocs) does: it toggles a `dark` class on `<html>`. Reading it directly
/// keeps the React side free of Flutter-specific plumbing and means a theme
/// switch never has to tear a view down and re-add it.
class DocsBrightness extends ValueNotifier<Brightness> {
  DocsBrightness() : super(_read()) {
    _observer = web.MutationObserver(
      (JSArray<JSObject> _, web.MutationObserver __) {
        value = _read();
      }.toJS,
    )..observe(
      web.document.documentElement!,
      web.MutationObserverInit(
        attributes: true,
        attributeFilter: <JSString>['class'.toJS].toJS,
      ),
    );
  }

  late final web.MutationObserver _observer;

  static Brightness _read() {
    final root = web.document.documentElement;
    final isDark = root != null && root.classList.contains('dark');
    return isDark ? Brightness.dark : Brightness.light;
  }

  @override
  void dispose() {
    _observer.disconnect();
    super.dispose();
  }
}
