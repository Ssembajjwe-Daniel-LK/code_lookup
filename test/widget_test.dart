// Widget tests for the Code Lookup app. Run with: flutter test
//
// These tests only check the screen; they never call the server.

import 'package:flutter_test/flutter_test.dart';

import 'package:code_lookup/main.dart';

void main() {
  testWidgets('start screen shows title, search field and hint',
      (WidgetTester tester) async {
    await tester.pumpWidget(const CodeLookupApp());

    expect(find.text('Code Lookup'), findsOneWidget); // AppBar title
    expect(find.text('Search'), findsOneWidget); // button
    expect(find.text('Enter a search term and press Search.'), findsOneWidget);
  });

  test('SearchHit reads knowledge-base JSON', () {
    final hit = SearchHit.fromJson({
      'source': r'C:\Dev\Demo_data\Dokumente\Handbuch.docx',
      'page': 3,
      'text': 'Display\nflackert',
      'score': 2,
    });

    expect(hit.fileName, 'Handbuch.docx');
    expect(hit.page, 3);
    expect(hit.snippet, 'Display flackert');
  });

  test('SearchHit reads lookup_code JSON', () {
    final hit = SearchHit.fromJson({
      'filepath': '/demo/Dokumente/Servicebericht.docx',
      'page_num': 2,
    });

    expect(hit.fileName, 'Servicebericht.docx');
    expect(hit.page, 2);
    expect(hit.score, isNull);
  });
}
