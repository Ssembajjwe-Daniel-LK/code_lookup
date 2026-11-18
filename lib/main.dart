// Code Lookup – Flutter learning project.
// Enter a search term -> app calls "search_knowledge_base" (or "lookup_code")
// on an MCP server -> shows the result.
//
// Run (Windows desktop):
//   flutter run -d windows --dart-define=MCP_URL=http://127.0.0.1:8010/mcp
//   add --dart-define=TOOL=lookup_code for code lookup (demo data only)

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'detail_screen.dart';
import 'highlight.dart';
import 'mcp_client.dart';
import 'settings_screen.dart';

// Read at build time from --dart-define, so no URL is hard-coded in the source.
const String mcpUrl =
    String.fromEnvironment('MCP_URL', defaultValue: 'http://127.0.0.1:8010/mcp');

// Which tool to call: knowledge base (default) or code lookup.
//   --dart-define=TOOL=lookup_code   switches to code lookup
const String toolName =
    String.fromEnvironment('TOOL', defaultValue: 'search_knowledge_base');
const bool isCodeMode = toolName == 'lookup_code';

// Theme colours: dark blue + red.
const Color themeBlue = Color(0xFF0B2A5B);
const Color themeRed = Color(0xFFD32F2F);

void main() => runApp(const CodeLookupApp());

// Hour 5: the app itself is now Stateful, because it owns the settings that
// several screens need (dark mode, server URL). "Lifting state up": the data
// lives in the highest widget that needs it and flows down as parameters;
// changes flow back up through callbacks (functions passed down).
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
        // AppBar stays dark blue with white text in both modes.
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
      home: LookupPage(
        serverUrl: _serverUrl,
        isDark: _isDark,
        onDarkChanged: _setDark,
        onServerUrlChanged: _setServerUrl,
      ),
    );
  }
}

// StatefulWidget = a widget with changing data (like a class with attributes
// whose changes redraw the screen). The data lives in the State class below.
class LookupPage extends StatefulWidget {
  const LookupPage({
    super.key,
    required this.serverUrl,
    required this.isDark,
    required this.onDarkChanged,
    required this.onServerUrlChanged,
  });

  final String serverUrl;
  final bool isDark;
  // ValueChanged<T> = a function that takes a T and returns nothing.
  final ValueChanged<bool> onDarkChanged;
  final ValueChanged<String> onServerUrlChanged;

  @override
  State<LookupPage> createState() => _LookupPageState();
}

class _LookupPageState extends State<LookupPage> {
  final _controller = TextEditingController();
  // `late`: set in initState, not here, because it needs widget.serverUrl.
  late McpClient _client;

  bool _loading = false;
  String? _error;
  String? _result; // raw text, shown only if the answer has no hit list
  List<SearchHit>? _hits; // parsed hits
  String _lastQuery = ''; // Hour 2: what was searched, for highlighting

  // Hour 3: search history, saved in the browser / on the device.
  static const _historyKey = 'search_history';
  List<String> _history = [];

  // initState runs once, when the screen is created (like __init__ for the
  // screen's lifetime). It can't be async itself, so it starts an async method.
  @override
  void initState() {
    super.initState();
    _client = McpClient(Uri.parse(widget.serverUrl));
    _loadHistory();
  }

  // Hour 5: called when the parent rebuilds this widget with new parameters.
  // If the server URL changed in the settings, connect to the new server.
  @override
  void didUpdateWidget(LookupPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.serverUrl != widget.serverUrl) {
      _client.close();
      _client = McpClient(Uri.parse(widget.serverUrl));
    }
  }

  void _openSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SettingsScreen(
          isDark: widget.isDark,
          serverUrl: widget.serverUrl,
          onDarkChanged: widget.onDarkChanged,
          onServerUrlChanged: widget.onServerUrlChanged,
        ),
      ),
    );
  }

  Future<void> _loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    // After an await the screen may already be gone -> check `mounted`.
    if (!mounted) return;
    setState(() => _history = prefs.getStringList(_historyKey) ?? []);
  }

  Future<void> _addToHistory(String query) async {
    // Newest first, no duplicates (ignoring case), at most 10 entries.
    final updated = [
      query,
      ..._history.where((h) => h.toLowerCase() != query.toLowerCase()),
    ].take(10).toList();

    setState(() => _history = updated);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_historyKey, updated);
  }

  Future<void> _clearHistory() async {
    setState(() => _history = []);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_historyKey);
  }

  @override
  void dispose() {
    _controller.dispose();
    _client.close();
    super.dispose();
  }

  Future<void> _search() async {
    final code = _controller.text.trim();
    if (code.isEmpty) return;

    // setState(...) = "data changed, please redraw".
    setState(() {
      _loading = true;
      _error = null;
      _result = null;
      _hits = null;
      _lastQuery = code;
    });

    try {
      final text = await _client.callTool(
        toolName,
        isCodeMode ? {'code': code} : {'query': code},
      );
      final hits = _parseHits(text);
      setState(() {
        _hits = hits;
        if (hits == null) _result = _prettyJson(text);
      });
      _addToHistory(code); // Hour 3: only successful searches are saved
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  /// Turns the server's JSON {"treffer": [ {...}, {...} ]} into a list of
  /// SearchHit objects. Returns null if the answer has no "treffer" list.
  List<SearchHit>? _parseHits(String text) {
    try {
      final data = jsonDecode(text);
      if (data is Map<String, dynamic> && data['treffer'] is List) {
        return (data['treffer'] as List)
            .whereType<Map<String, dynamic>>()
            .map(SearchHit.fromJson)
            .toList();
      }
    } on FormatException {
      // not JSON -> fall back to raw text
    }
    return null;
  }

  /// If the tool answers with JSON, indent it; otherwise show it as is.
  String _prettyJson(String text) {
    try {
      return const JsonEncoder.withIndent('  ').convert(jsonDecode(text));
    } on FormatException {
      return text;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Code Lookup'),
        // Colours now come from appBarTheme in CodeLookupApp.
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Settings',
            onPressed: _openSettings,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(
                      labelText: isCodeMode
                          ? 'Code (e.g. DMX-2001, KBX-104A)'
                          : 'Search documents (e.g. Display flackert)',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _search(), // Enter key
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton.icon(
                  onPressed: _loading ? null : _search,
                  icon: const Icon(Icons.search),
                  label: const Text('Search'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('Server: ${widget.serverUrl}',
                style: Theme.of(context).textTheme.bodySmall),

            // Hour 3: history chips. "...[ ]" (spread) inserts several
            // widgets at once, only if the condition is true.
            if (_history.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  for (final q in _history)
                    ActionChip(
                      avatar: const Icon(Icons.history, size: 16),
                      label: Text(q),
                      onPressed: () {
                        _controller.text = q;
                        _search();
                      },
                    ),
                  TextButton.icon(
                    onPressed: _clearHistory,
                    icon: const Icon(Icons.clear_all),
                    label: const Text('Clear'),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 16),
            Expanded(child: _buildResultArea(colors)),
          ],
        ),
      ),
    );
  }

  Widget _buildResultArea(ColorScheme colors) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    if (_error != null) {
      return Card(
        color: colors.errorContainer,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: SelectableText(_error!),
        ),
      );
    }

    final hits = _hits;
    if (hits != null) {
      if (hits.isEmpty) return const Center(child: Text('No hits.'));

      // ListView.builder only builds the cards that are visible on screen.
      return ListView.builder(
        itemCount: hits.length,
        itemBuilder: (context, i) {
          final hit = hits[i];
          return Card(
            child: ListTile(
              // Hour 1: open the detail page on tap.
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => DetailScreen(hit: hit, query: _lastQuery),
                ),
              ),
              trailing: const Icon(Icons.chevron_right),
              leading: Icon(Icons.description, color: colors.primary),
              title: Text(hit.fileName,
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Page ${hit.page}'
                      '${hit.score != null ? ' · Score ${hit.score}' : ''}'),
                  if (hit.text.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text.rich(
                      highlightSpans(hit.snippet, _lastQuery,
                          color: colors.secondary),
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 4),
                  SelectableText(hit.path,
                      style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
          );
        },
      );
    }

    if (_result == null) {
      return const Center(child: Text('Enter a search term and press Search.'));
    }

    return Card(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: SelectableText(
          _result!,
          style: const TextStyle(fontFamily: 'Consolas', fontSize: 13),
        ),
      ),
    );
  }
}

/// One search hit. Python comparison: like a @dataclass with a from_dict().
/// Works for both tools: search_knowledge_base sends source/page/text/score,
/// lookup_code sends filepath/page_num.
class SearchHit {
  SearchHit({required this.path, required this.page, this.text = '', this.score});

  final String path;
  final int page;
  final String text;
  final num? score;

  factory SearchHit.fromJson(Map<String, dynamic> json) => SearchHit(
        path: (json['source'] ?? json['filepath'] ?? '') as String,
        page: (json['page'] ?? json['page_num'] ?? 0) as int,
        text: (json['text'] ?? '') as String,
        score: json['score'] as num?,
      );

  /// File name without folder (works with \ and /).
  String get fileName => path.split(RegExp(r'[\\/]')).last;

  /// Text without line breaks, for the preview.
  String get snippet => text.replaceAll(RegExp(r'\s+'), ' ').trim();
}
