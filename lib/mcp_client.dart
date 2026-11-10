// Minimal MCP client over "Streamable HTTP", written by hand with package:http.
//
// Why by hand instead of a library (mcp_dart / dart_mcp)?
// -> For learning: you see exactly what an MCP client (like Claude) does when
//    it talks to a Python MCP server. Swapping in mcp_dart later is optional.
//
// The MCP flow (JSON-RPC 2.0 over HTTP POST):
//   1. POST "initialize"                -> server answers + sends Mcp-Session-Id header
//   2. POST "notifications/initialized" -> no answer (HTTP 202)
//   3. POST "tools/call"                -> result with content: [{type: text, text: ...}]
//
// Python comparison:
//   Future<T>  ~ coroutine / awaitable
//   Map<String, dynamic> ~ dict
//   String?    = "may be None" (null safety: Dart forces you to handle null)

import 'dart:convert';

import 'package:http/http.dart' as http;

class McpException implements Exception {
  McpException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => 'McpException: $message';
}

class McpClient {
  McpClient(this.endpoint, {http.Client? httpClient})
      : _http = httpClient ?? http.Client();

  final Uri endpoint;
  final http.Client _http;

  String? _sessionId;
  String _protocolVersion = '2025-06-18';
  bool _initialized = false;
  int _nextId = 1;

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        // Streamable HTTP: the server may answer with plain JSON OR with SSE.
        'Accept': 'application/json, text/event-stream',
        if (_sessionId != null) 'Mcp-Session-Id': _sessionId!,
        if (_initialized) 'MCP-Protocol-Version': _protocolVersion,
      };

  /// Sends one JSON-RPC message. Returns the "result" object,
  /// or null for notifications (which get no answer).
  Future<Map<String, dynamic>?> _post(Map<String, dynamic> message) async {
    final res = await _http
        .post(endpoint, headers: _headers, body: jsonEncode(message))
        .timeout(const Duration(seconds: 60));

    // package:http gives header names in lower case.
    final sid = res.headers['mcp-session-id'];
    if (sid != null) _sessionId = sid;

    final isNotification = !message.containsKey('id');
    if (isNotification || res.statusCode == 202) return null;

    // Always decode as UTF-8 (umlauts!). res.body would fall back to latin1
    // if the server sends no charset.
    final text = utf8.decode(res.bodyBytes);

    if (res.statusCode != 200) {
      throw McpException('HTTP ${res.statusCode}: $text',
          statusCode: res.statusCode);
    }

    final contentType = res.headers['content-type'] ?? '';
    final Map<String, dynamic> reply = contentType.contains('text/event-stream')
        ? _replyFromSse(text, message['id'])
        : jsonDecode(text) as Map<String, dynamic>;

    final error = reply['error'];
    if (error != null) {
      throw McpException('Server error ${error['code']}: ${error['message']}');
    }
    return reply['result'] as Map<String, dynamic>;
  }

  /// SSE body looks like:
  ///   event: message
  ///   data: {"jsonrpc":"2.0","id":1,"result":{...}}
  ///   (blank line)
  /// We look for the event whose JSON "id" matches our request.
  Map<String, dynamic> _replyFromSse(String body, Object? requestId) {
    final events = body.replaceAll('\r\n', '\n').split('\n\n');
    for (final event in events) {
      final data = event
          .split('\n')
          .where((line) => line.startsWith('data:'))
          .map((line) => line.substring(5).trimLeft())
          .join('\n');
      if (data.isEmpty) continue;
      final decoded = jsonDecode(data);
      if (decoded is Map<String, dynamic> && decoded['id'] == requestId) {
        return decoded;
      }
    }
    throw McpException('No answer for request $requestId in SSE stream');
  }

  Future<void> initialize() async {
    final result = await _post({
      'jsonrpc': '2.0',
      'id': _nextId++,
      'method': 'initialize',
      'params': {
        'protocolVersion': _protocolVersion,
        'capabilities': <String, dynamic>{},
        'clientInfo': {'name': 'code_lookup_flutter', 'version': '0.1.0'},
      },
    });
    // The server tells us which protocol version it actually speaks.
    _protocolVersion =
        (result?['protocolVersion'] as String?) ?? _protocolVersion;
    _initialized = true;

    await _post({'jsonrpc': '2.0', 'method': 'notifications/initialized'});
  }

  /// Calls a tool and returns all text parts of the answer joined together.
  Future<String> callTool(String name, Map<String, dynamic> arguments) async {
    if (!_initialized) await initialize();

    Future<Map<String, dynamic>?> send() => _post({
          'jsonrpc': '2.0',
          'id': _nextId++,
          'method': 'tools/call',
          'params': {'name': name, 'arguments': arguments},
        });

    Map<String, dynamic>? result;
    try {
      result = await send();
    } on McpException catch (e) {
      // 404 = session expired (e.g. server restarted). Start a new one, retry once.
      if (e.statusCode != 404) rethrow;
      _sessionId = null;
      _initialized = false;
      await initialize();
      result = await send();
    }

    final content = (result?['content'] as List?) ?? const [];
    final text = content
        .whereType<Map<String, dynamic>>()
        .where((part) => part['type'] == 'text')
        .map((part) => part['text'] as String)
        .join('\n');

    if (result?['isError'] == true) throw McpException(text);
    return text;
  }

  void close() => _http.close();
}
