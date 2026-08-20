/*
 * AI-Provenance:
 *   model: Claude Opus 5
 *   harness: Cursor
 */
import 'package:advanced_forms_docs_islands/support/docs_brightness.dart';
import 'package:advanced_forms_docs_islands/support/island_frame.dart';
import 'package:flutter/material.dart';

/// One docs example, following the light/dark setting of the page it is
/// embedded in.
///
/// Everything that does not need a browser lives in [IslandFrame]; this widget
/// only wires the page's colour scheme to it.
class IslandShell extends StatefulWidget {
  const IslandShell({super.key, required this.exampleId, this.builder});

  final String? exampleId;
  final WidgetBuilder? builder;

  @override
  State<IslandShell> createState() => _IslandShellState();
}

class _IslandShellState extends State<IslandShell> {
  final _brightness = DocsBrightness();

  @override
  void dispose() {
    _brightness.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: _brightness,
      builder: (context, brightness, _) => IslandFrame(
        brightness: brightness,
        exampleId: widget.exampleId,
        builder: widget.builder,
      ),
    );
  }
}
