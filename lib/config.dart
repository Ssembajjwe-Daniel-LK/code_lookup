// App-wide constants. One place to change them.

import 'package:flutter/material.dart';

/// Server URL, set at build time: --dart-define=MCP_URL=...
const String mcpUrl =
    String.fromEnvironment('MCP_URL', defaultValue: 'http://127.0.0.1:8010/mcp');

/// Which tool to call: knowledge base (default) or code lookup.
///   --dart-define=TOOL=lookup_code   switches to code lookup
const String toolName =
    String.fromEnvironment('TOOL', defaultValue: 'search_knowledge_base');
const bool isCodeMode = toolName == 'lookup_code';

/// Hour 7: layout breakpoints (logical pixels, not device pixels).
/// Below [compactWidth] the search button shows only its icon.
/// From [wideWidth] on, list and detail sit side by side (step 2).
const double compactWidth = 420;
const double wideWidth = 800;

/// Theme colours: dark blue + red.
const Color themeBlue = Color(0xFF0B2A5B);
const Color themeRed = Color(0xFFD32F2F);
