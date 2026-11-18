// Hour 8: tests for highlightSpans (a pure function: easy to test).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:code_lookup/utils/highlight.dart';

/// The texts of all highlighted (bold) pieces.
List<String?> markedWords(TextSpan span) => (span.children ?? [])
    .cast<TextSpan>()
    .where((s) => s.style?.fontWeight == FontWeight.bold)
    .map((s) => s.text)
    .toList();

void main() {
  test('marks every match, ignoring upper/lower case', () {
    final span = highlightSpans(
      'Display flackert, display ok',
      'display',
      color: Colors.red,
    );

    expect(markedWords(span), ['Display', 'display']);
  });

  test('keeps the full text unchanged', () {
    const text = 'Display flackert bei niedriger Helligkeit';
    final span = highlightSpans(text, 'flackert Helligkeit', color: Colors.red);

    expect(span.toPlainText(), text);
  });

  test('empty search returns the text without highlighting', () {
    final span = highlightSpans('abc', '', color: Colors.red);

    expect(span.text, 'abc');
    expect(span.children, isNull);
  });

  test('a dot in the search means a real dot, not "any character"', () {
    final span = highlightSpans('FWV 3.14 and FWV 3x14', '3.14', color: Colors.red);

    expect(markedWords(span), ['3.14']); // "3x14" is not marked
  });
}
