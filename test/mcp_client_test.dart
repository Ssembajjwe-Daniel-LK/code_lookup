// Hour 8: tests for the MCP client - without a real server.
//
// MockClient (from package:http/testing.dart) is a fake http.Client: instead
// of sending requests over the network, it calls our function and returns
// whatever Response we build. So we can test every server answer, even errors.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:code_lookup/services/mcp_client.dart';

/// A JSON answer, encoded as UTF-8 bytes (so umlauts survive).
http.Response jsonResponse(
  Object body, {
  int status = 200,
  Map<String, String> headers = const {},
}) =>
    http.Response.bytes(
      utf8.encode(jsonEncode(body)),
      status,
      headers: {'content-type': 'application/json', ...headers},
    );

/// A tool result in MCP format: {"content":[{"type":"text","text":...}]}
Map<String, dynamic> toolResult(Object? id, String text, {bool isError = false}) => {
      'jsonrpc': '2.0',
      'id': id,
      'result': {
        'content': [
          {'type': 'text', 'text': text},
        ],
        'isError': isError,
      },
    };

/// Fake MCP server. Answers initialize and the notification itself;
/// tools/call is answered by [onToolCall]. Every method name goes into [log].
MockClient fakeServer({
  required http.Response Function(http.Request req, Map<String, dynamic> msg)
      onToolCall,
  List<String>? log,
}) {
  return MockClient((req) async {
    final msg = jsonDecode(req.body) as Map<String, dynamic>;
    log?.add(msg['method'] as String);

    switch (msg['method']) {
      case 'initialize':
        return jsonResponse(
          {
            'jsonrpc': '2.0',
            'id': msg['id'],
            'result': {'protocolVersion': '2025-06-18'},
          },
          headers: {'mcp-session-id': 'session-123'},
        );
      case 'notifications/initialized':
        return http.Response('', 202);
      default:
        return onToolCall(req, msg);
    }
  });
}

void main() {
  final url = Uri.parse('http://test/mcp');

  test('runs initialize -> notification -> tools/call and keeps umlauts', () async {
    final log = <String>[];
    final client = McpClient(
      url,
      httpClient: fakeServer(
        log: log,
        onToolCall: (req, msg) => jsonResponse(toolResult(msg['id'], 'Größe ändern')),
      ),
    );

    final text = await client.callTool('search_knowledge_base', {'query': 'x'});

    expect(text, 'Größe ändern');
    expect(log, ['initialize', 'notifications/initialized', 'tools/call']);
  });

  test('sends the session ID from initialize with every later request', () async {
    String? sentSession;
    final client = McpClient(
      url,
      httpClient: fakeServer(onToolCall: (req, msg) {
        sentSession = req.headers['Mcp-Session-Id'];
        return jsonResponse(toolResult(msg['id'], 'ok'));
      }),
    );

    await client.callTool('search_knowledge_base', {'query': 'x'});

    expect(sentSession, 'session-123');
  });

  test('reads an SSE (text/event-stream) answer', () async {
    final client = McpClient(
      url,
      httpClient: fakeServer(onToolCall: (req, msg) {
        final data = jsonEncode(toolResult(msg['id'], 'from SSE'));
        return http.Response.bytes(
          utf8.encode('event: message\ndata: $data\n\n'),
          200,
          headers: {'content-type': 'text/event-stream'},
        );
      }),
    );

    expect(await client.callTool('t', {}), 'from SSE');
  });

  test('throws McpException when the tool reports an error', () async {
    final client = McpClient(
      url,
      httpClient: fakeServer(
        onToolCall: (req, msg) =>
            jsonResponse(toolResult(msg['id'], 'tool failed', isError: true)),
      ),
    );

    expect(
      () => client.callTool('t', {}),
      throwsA(isA<McpException>()),
    );
  });

  test('starts a new session once when the server answers 404', () async {
    final log = <String>[];
    var toolCalls = 0;
    final client = McpClient(
      url,
      httpClient: fakeServer(
        log: log,
        onToolCall: (req, msg) {
          toolCalls++;
          // first call: session expired; second call: works
          if (toolCalls == 1) return http.Response('session expired', 404);
          return jsonResponse(toolResult(msg['id'], 'after retry'));
        },
      ),
    );

    expect(await client.callTool('t', {}), 'after retry');
    expect(log.where((m) => m == 'initialize').length, 2);
  });
}
