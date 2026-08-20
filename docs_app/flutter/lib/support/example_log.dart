/*
 * AI-Provenance:
 *   model: Claude Opus 5
 *   harness: Cursor
 */
import 'package:flutter/material.dart';

/// Collects lines an example wants to show the reader.
///
/// A form example normally ends in `debugPrint`, which is invisible to someone
/// reading the docs, so the island shell renders whatever the example logs
/// directly underneath it. This is the one docs-only affordance that shows up
/// in published snippets; everything else in a snippet is code a reader could
/// paste into their own app unchanged.
class ExampleLog extends ChangeNotifier {
  final _lines = <String>[];

  List<String> get lines => List.unmodifiable(_lines);

  void add(String line) {
    _lines.add(line);
    notifyListeners();
  }

  void clear() {
    if (_lines.isEmpty) {
      return;
    }
    _lines.clear();
    notifyListeners();
  }

  /// The log for the surrounding example.
  static ExampleLog of(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<ExampleLogScope>();
    assert(scope != null, 'No ExampleLog above this widget.');
    return scope!.log;
  }
}

/// Publishes an [ExampleLog] to the example below it.
class ExampleLogScope extends InheritedWidget {
  const ExampleLogScope({
    super.key,
    required this.log,
    required super.child,
  });

  final ExampleLog log;

  @override
  bool updateShouldNotify(ExampleLogScope oldWidget) => log != oldWidget.log;
}

/// Renders [log] as a compact transcript under an example.
class ExampleLogView extends StatelessWidget {
  const ExampleLogView({super.key, required this.log});

  final ExampleLog log;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListenableBuilder(
      listenable: log,
      builder: (context, _) {
        if (log.lines.isEmpty) {
          return const SizedBox.shrink();
        }

        return Container(
          width: double.infinity,
          margin: const EdgeInsets.only(top: 16),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Output',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: log.clear,
                    icon: const Icon(Icons.close, size: 16),
                    visualDensity: VisualDensity.compact,
                    tooltip: 'Clear',
                  ),
                ],
              ),
              for (final line in log.lines)
                Text(line, style: theme.textTheme.bodySmall),
            ],
          ),
        );
      },
    );
  }
}
