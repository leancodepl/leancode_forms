/*
 * AI-Provenance:
 *   model: Claude Opus 5
 *   harness: Cursor
 */
import 'package:advanced_forms_docs_islands/support/example_log.dart';
import 'package:flutter/material.dart';

/// The part of an island that has nothing to do with the browser.
///
/// Kept free of `package:web` on purpose: `test/examples_test.dart` runs on the
/// Dart VM and puts every docs example through the same constraints the real
/// island imposes.
///
/// Deliberately **not** a [Scaffold]. An auto-height island is laid out with
/// unbounded vertical constraints so the framework's computed height can size
/// the host `<div>`, and [Scaffold] takes `constraints.biggest`. [MaterialApp]
/// itself is fine under unbounded height: its [Navigator] pushes an opaque
/// [ModalRoute], whose overlay entry sets `canSizeOverlay`, so the overlay
/// sizes itself to the route instead of to the constraints.
///
/// The background stays transparent — the docs page draws the frame around the
/// island, so the island only draws its content.
class IslandFrame extends StatefulWidget {
  const IslandFrame({
    super.key,
    required this.brightness,
    this.exampleId,
    this.builder,
  });

  final Brightness brightness;

  /// The id requested by the host page, kept for the missing-example message.
  final String? exampleId;

  /// Builds the example. Null when the requested id is not in this bundle,
  /// which means the docs and the bundle were built from different revisions.
  final WidgetBuilder? builder;

  @override
  State<IslandFrame> createState() => _IslandFrameState();
}

class _IslandFrameState extends State<IslandFrame> {
  final _log = ExampleLog();

  @override
  void dispose() {
    _log.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: islandTheme(widget.brightness),
      home: Material(
        type: MaterialType.transparency,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: ExampleLogScope(
            log: _log,
            // A Builder so the example resolves Theme, MediaQuery and
            // Localizations from inside MaterialApp rather than from the
            // context that constructed it.
            child: Builder(
              builder: (context) => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  widget.builder?.call(context) ??
                      _MissingExample(exampleId: widget.exampleId),
                  ExampleLogView(log: _log),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The theme docs islands render with.
///
/// Kept plain on purpose: an example should read as stock Material so nobody
/// mistakes the docs styling for something the package provides.
ThemeData islandTheme(Brightness brightness) {
  return ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFF3B82F6),
      brightness: brightness,
    ),
    useMaterial3: true,
    visualDensity: VisualDensity.compact,
  );
}

class _MissingExample extends StatelessWidget {
  const _MissingExample({required this.exampleId});

  final String? exampleId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        exampleId == null
            ? 'This island was attached without an example id.'
            : 'Example "$exampleId" is not in this bundle. Re-run '
                  '`npm run examples:build`.',
        style: TextStyle(color: theme.colorScheme.onErrorContainer),
      ),
    );
  }
}
