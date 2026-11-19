// The main screen: search field, history chips, result list.
// (Was LookupPage in main.dart before hour 6.)

import 'dart:async'; // Hour 4: Timer
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:code_lookup/config.dart';
import 'package:code_lookup/models/search_hit.dart';
import 'package:code_lookup/screens/detail_screen.dart';
import 'package:code_lookup/screens/settings_screen.dart';
import 'package:code_lookup/services/mcp_client.dart';
import 'package:code_lookup/widgets/hit_card.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({
    super.key,
    required this.serverUrl,
    required this.isDark,
    required this.onDarkChanged,
    required this.onServerUrlChanged,
  });

  final String serverUrl;
  final bool isDark;
  final ValueChanged<bool> onDarkChanged;
  final ValueChanged<String> onServerUrlChanged;

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _controller = TextEditingController();
  late McpClient _client;

  bool _loading = false;
  String? _error;
  String? _result; // raw text, shown only if the answer has no hit list
  List<SearchHit>? _hits; // parsed hits
  String _lastQuery = ''; // for highlighting

  // Hour 4: search as you type.
  static const _debounceDelay = Duration(milliseconds: 400);
  Timer? _debounce; // waits until the user stops typing
  int _requestId = 0; // counts searches, to ignore outdated answers

  // Search history, saved in the browser / on the device.
  static const _historyKey = 'search_history';
  List<String> _history = [];

  @override
  void initState() {
    super.initState();
    _client = McpClient(Uri.parse(widget.serverUrl));
    _loadHistory();
  }

  // Reconnect when the server URL was changed in the settings.
  @override
  void didUpdateWidget(SearchScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.serverUrl != widget.serverUrl) {
      _client.close();
      _client = McpClient(Uri.parse(widget.serverUrl));
    }
  }

  @override
  void dispose() {
    _debounce?.cancel(); // a timer must not fire after the screen is gone
    _controller.dispose();
    _client.close();
    super.dispose();
  }

  // ---------- history ----------

  Future<void> _loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() => _history = prefs.getStringList(_historyKey) ?? []);
  }

  Future<void> _addToHistory(String query) async {
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

  // ---------- navigation ----------

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

  void _openDetail(SearchHit hit) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DetailScreen(hit: hit, query: _lastQuery),
      ),
    );
  }

  // ---------- search ----------

  /// Hour 4: called on every keystroke. Each keystroke cancels the previous
  /// timer and starts a new one, so the search only runs when the user has
  /// stopped typing for 400 ms ("debounce").
  void _onTextChanged(String text) {
    _debounce?.cancel();
    if (text.trim().length < 2) return; // too short to search
    _debounce = Timer(_debounceDelay, () => _search(saveHistory: false));
  }

  /// [saveHistory]: only searches the user really "sent" (Enter, button,
  /// chip) go into the history, not every half-typed word.
  Future<void> _search({bool saveHistory = true}) async {
    _debounce?.cancel(); // Enter/button: no extra timer search afterwards
    final query = _controller.text.trim();
    if (query.isEmpty) return;

    // Every search gets a number. If a newer search started while this one
    // was waiting for the server, this answer is outdated and is ignored.
    final myId = ++_requestId;

    setState(() {
      _loading = true;
      _error = null;
      _result = null;
      _hits = null;
      _lastQuery = query;
    });

    try {
      final text = await _client.callTool(
        toolName,
        isCodeMode ? {'code': query} : {'query': query},
      );
      if (myId != _requestId || !mounted) return; // outdated -> ignore
      final hits = _parseHits(text);
      setState(() {
        _hits = hits;
        if (hits == null) _result = _prettyJson(text);
      });
      if (saveHistory) _addToHistory(query);
    } catch (e) {
      if (myId != _requestId || !mounted) return;
      setState(() => _error = e.toString());
    } finally {
      // only the newest search may switch the spinner off
      if (myId == _requestId && mounted) setState(() => _loading = false);
    }
  }

  /// Turns the server's JSON {"treffer": [ {...}, {...} ]} into SearchHits.
  /// Returns null if the answer has no "treffer" list.
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

  String _prettyJson(String text) {
    try {
      return const JsonEncoder.withIndent('  ').convert(jsonDecode(text));
    } on FormatException {
      return text;
    }
  }

  // ---------- UI ----------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Code Lookup'),
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
            _buildSearchRow(),
            const SizedBox(height: 8),
            Text('Server: ${widget.serverUrl}',
                style: Theme.of(context).textTheme.bodySmall),
            if (_history.isNotEmpty) ...[
              const SizedBox(height: 8),
              _buildHistory(),
            ],
            const SizedBox(height: 16),
            Expanded(child: _buildResultArea()),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchRow() {
    // Hour 7: LayoutBuilder tells us how much width THIS part has
    // (constraints.maxWidth), not the whole window. On a narrow screen the
    // button shrinks to an icon so the text field keeps enough room.
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < compactWidth;

        return Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                decoration: InputDecoration(
                  labelText: compact
                      ? 'Search'
                      : isCodeMode
                          ? 'Code (e.g. DMX-2001, KBX-104A)'
                          : 'Search documents (e.g. Display flackert)',
                  border: const OutlineInputBorder(),
                ),
                onChanged: _onTextChanged, // Hour 4: every keystroke
                onSubmitted: (_) => _search(), // Enter: search now + history
              ),
            ),
            SizedBox(width: compact ? 8 : 12),
            if (compact)
              IconButton.filled(
                onPressed: _loading ? null : () => _search(),
                icon: const Icon(Icons.search),
                tooltip: 'Search',
              )
            else
              FilledButton.icon(
                onPressed: _loading ? null : () => _search(),
                icon: const Icon(Icons.search),
                label: const Text('Search'),
              ),
          ],
        );
      },
    );
  }

  Widget _buildHistory() {
    return Wrap(
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
    );
  }

  Widget _buildResultArea() {
    final colors = Theme.of(context).colorScheme;

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
      return ListView.builder(
        itemCount: hits.length,
        itemBuilder: (context, i) => HitCard(
          hit: hits[i],
          query: _lastQuery,
          onTap: () => _openDetail(hits[i]),
        ),
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
