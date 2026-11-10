// Code Lookup – Flutter learning project.
// Enter a search term -> app calls "search_knowledge_base" (or "lookup_code")
// on an MCP server -> shows the result.
//
// Run (Windows desktop):
//   flutter run -d windows --dart-define=MCP_URL=http://127.0.0.1:8010/mcp
//   add --dart-define=TOOL=lookup_code for code lookup (demo data only)

import 'dart:convert';

import 'package:flutter/material.dart';

import 'mcp_client.dart';

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

class CodeLookupApp extends StatelessWidget {
  const CodeLookupApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Code Lookup',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: themeBlue,
          primary: themeBlue,
          secondary: themeRed,
        ),
      ),
      home: const LookupPage(),
    );
  }
}

// StatefulWidget = a widget with changing data (like a class with attributes
// whose changes redraw the screen). The data lives in the State class below.
class LookupPage extends StatefulWidget {
  const LookupPage({super.key});

  @override
  State<LookupPage> createState() => _LookupPageState();
}

class _LookupPageState extends State<LookupPage> {
  final _controller = TextEditingController();
  final _client = McpClient(Uri.parse(mcpUrl));

  bool _loading = false;
  String? _error;
  String? _result; // raw text, shown only if the answer has no hit list
  List<SearchHit>? _hits; // parsed hits

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
        backgroundColor: colors.primary,
        foregroundColor: Colors.white,
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
            Text('Server: $mcpUrl', style: Theme.of(context).textTheme.bodySmall),
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
                    Text(hit.snippet, maxLines: 4, overflow: TextOverflow.ellipsis),
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
