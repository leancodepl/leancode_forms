import 'package:flutter/material.dart';

/// A small information card shown at the top of each example form screen,
/// describing what the screen demonstrates. Accepts a list of [InlineSpan]s
/// so callers can mix plain text with bold / inline-code spans using the
/// [plain], [bold] and [code] helpers below.
class ScreenDescription extends StatelessWidget {
  const ScreenDescription(this.spans, {super.key});

  final List<InlineSpan> spans;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Text.rich(
          TextSpan(children: spans),
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ),
    );
  }
}

/// A regular-weight text span. Equivalent to `TextSpan(text: text)` —
/// provided as a helper for symmetry with [bold] and [code].
TextSpan plain(String text) => TextSpan(text: text);

/// A bolded text span, for emphasis on key terms.
TextSpan bold(String text) =>
    TextSpan(text: text, style: const TextStyle(fontWeight: FontWeight.bold));

/// A monospace text span with a subtle background, for inline references to
/// code identifiers (class names, method names, types).
TextSpan code(String text) => TextSpan(
      text: text,
      style: const TextStyle(
        fontFamily: 'monospace',
        backgroundColor: Color(0xFFEEEEEE),
      ),
    );
