// Code Lookup – Flutter learning project.
// Enter a search term -> app calls "search_knowledge_base" (or "lookup_code")
// on an MCP server -> shows the result.
//
// Run:
//   flutter run -d chrome --dart-define=MCP_URL=http://127.0.0.1:8010/mcp
//   add --dart-define=TOOL=lookup_code for code lookup (demo data only)
//
// Project structure (hour 6):
//   main.dart              app start, themes, settings state
//   config.dart            constants (URL, tool, colours)
//   models/                data classes (SearchHit)
//   services/              talking to the outside world (MCP client)
//   screens/               one file per screen
//   widgets/               small reusable widgets (HitCard)
//   utils/                 helper functions (highlighting)

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:code_lookup/config.dart';
import 'package:code_lookup/screens/search_screen.dart';

void main() => runApp(const CodeLookupApp());

// Hour 5: the app owns the settings that several screens need (dark mode,
// server URL). Data flows down as parameters, changes flow up via callbacks.
class CodeLookupApp extends StatefulWidget {
  const CodeLookupApp({super.key});

  @override
  State<CodeLookupApp> createState() => _CodeLookupAppState();
}

class _CodeLookupAppState extends State<CodeLookupApp> {
  static const _darkKey = 'dark_mode';
  static const _urlKey = 'server_url';

  bool _isDark = false;
  String _serverUrl = mcpUrl; // default from --dart-define

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _isDark = prefs.getBool(_darkKey) ?? false;
      _serverUrl = prefs.getString(_urlKey) ?? mcpUrl;
    });
  }

  Future<void> _setDark(bool value) async {
    setState(() => _isDark = value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_darkKey, value);
  }

  Future<void> _setServerUrl(String value) async {
    setState(() => _serverUrl = value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_urlKey, value);
  }

  // One function builds both themes, so light and dark only differ in brightness.
  ThemeData _theme(Brightness brightness) => ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: themeBlue,
      brightness: brightness,
      secondary: themeRed,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: themeBlue,
      foregroundColor: Colors.white,
    ),
  );

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Code Lookup',
      debugShowCheckedModeBanner: false,
      theme: _theme(Brightness.light),
      darkTheme: _theme(Brightness.dark),
      themeMode: _isDark ? ThemeMode.dark : ThemeMode.light,
      home: SearchScreen(
        serverUrl: _serverUrl,
        isDark: _isDark,
        onDarkChanged: _setDark,
        onServerUrlChanged: _setServerUrl,
      ),
    );
  }
}
