// Highlighting the search words in a text.
//
// New concepts:
//  - TextSpan: a piece of text with its own style. A TextSpan with
//    `children` is a whole text made of several styled pieces.
//  - Text.rich / SelectableText.rich: show such a TextSpan.
//  - RegExp with caseSensitive: false, and allMatches() to find every hit.

import 'package:flutter/material.dart';

/// Splits [text] into pieces and marks every word of [query] (case-insensitive).
TextSpan highlightSpans(
  String text,
  String query, {
  TextStyle? style,
  required Color color,
}) {
  // "Display flackert" -> ["Display", "flackert"]; single letters are ignored.
  // RegExp.escape makes characters like "." or "-" match literally.
  final terms = query
      .split(RegExp(r'\s+'))
      .where((t) => t.length > 1)
      .map(RegExp.escape)
      .toList();

  if (terms.isEmpty) return TextSpan(text: text, style: style);

  // One pattern for all words: "Display|flackert"
  final pattern = RegExp(terms.join('|'), caseSensitive: false);
  final marked = TextStyle(
    fontWeight: FontWeight.bold,
    color: color,
    backgroundColor: color.withValues(alpha: 0.15),
  );

  final spans = <TextSpan>[];
  var start = 0;
  for (final match in pattern.allMatches(text)) {
    // normal text before the match
    if (match.start > start) {
      spans.add(TextSpan(text: text.substring(start, match.start)));
    }
    // the match itself, highlighted
    spans.add(TextSpan(text: match.group(0), style: marked));
    start = match.end;
  }
  // rest after the last match
  if (start < text.length) spans.add(TextSpan(text: text.substring(start)));

  return TextSpan(style: style, children: spans);
}
