// Hour 8: widget tests for screens. A widget test builds the UI in memory,
// taps and types like a user, and checks what is on screen.
//
//   tester.pumpWidget(...)   build the widget
//   tester.tap / enterText   act like a user
//   tester.pump()            redraw once
//   tester.pumpAndSettle()   redraw until all animations are finished

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:code_lookup/main.dart';
import 'package:code_lookup/models/search_hit.dart';
import 'package:code_lookup/screens/detail_screen.dart';
import 'package:code_lookup/screens/settings_screen.dart';
import 'package:code_lookup/widgets/hit_card.dart';

void main() {
  final hit = SearchHit(
    path: r'C:\Docs\Handbuch.docx',
    page: 2,
    text: 'Display flackert',
  );

  testWidgets('tapping a hit card opens the detail page', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        // Builder gives us a context below MaterialApp, needed for Navigator.
        home: Builder(
          builder: (context) => Scaffold(
            body: HitCard(
              hit: hit,
              query: 'Display',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => DetailScreen(hit: hit, query: 'Display'),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('Handbuch.docx'), findsOneWidget);

    await tester.tap(find.byType(HitCard));
    await tester.pumpAndSettle(); // wait for the page animation

    expect(find.byType(DetailScreen), findsOneWidget);
    expect(find.byIcon(Icons.copy), findsOneWidget);
  });

  testWidgets('settings reject an invalid URL and save a valid one',
      (tester) async {
    String? savedUrl;
    await tester.pumpWidget(
      MaterialApp(
        home: SettingsScreen(
          isDark: false,
          serverUrl: 'http://127.0.0.1:8010/mcp',
          onDarkChanged: (_) {},
          onServerUrlChanged: (value) => savedUrl = value,
        ),
      ),
    );

    await tester.enterText(find.byType(TextFormField), 'abc');
    await tester.tap(find.text('Save'));
    await tester.pump();

    expect(find.textContaining('Enter a full URL'), findsOneWidget);
    expect(savedUrl, isNull); // nothing saved

    await tester.enterText(find.byType(TextFormField), 'http://localhost:9000/mcp');
    await tester.tap(find.text('Save'));
    await tester.pump();

    expect(savedUrl, 'http://localhost:9000/mcp');
  });

  testWidgets('dark mode switch calls the callback', (tester) async {
    bool? darkValue;
    await tester.pumpWidget(
      MaterialApp(
        home: SettingsScreen(
          isDark: false,
          serverUrl: 'http://127.0.0.1:8010/mcp',
          onDarkChanged: (value) => darkValue = value,
          onServerUrlChanged: (_) {},
        ),
      ),
    );

    await tester.tap(find.byType(SwitchListTile));
    await tester.pump();

    expect(darkValue, isTrue);
  });

  testWidgets('saved search history appears as chips', (tester) async {
    // Fake storage that already contains two searches.
    SharedPreferences.setMockInitialValues({
      'search_history': <String>['Display', 'Firmware'],
    });

    await tester.pumpWidget(const CodeLookupApp());
    await tester.pumpAndSettle(); // let _loadHistory() finish

    expect(find.widgetWithText(ActionChip, 'Display'), findsOneWidget);
    expect(find.widgetWithText(ActionChip, 'Firmware'), findsOneWidget);
  });
}
