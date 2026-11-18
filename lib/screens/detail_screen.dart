// Detail page for one search hit.
//
// Hour 1: navigation - data comes in through the constructor; the AppBar back
//         arrow calls Navigator.pop automatically.
// Hour 1 exercise: copy button in the AppBar.
// Hour 2: the search words are highlighted in the full text.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:code_lookup/utils/highlight.dart';
import 'package:code_lookup/models/search_hit.dart';

class DetailScreen extends StatelessWidget {
  const DetailScreen({super.key, required this.hit, this.query = ''});

  final SearchHit hit;
  final String query; // Hour 2: the search words to highlight

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(hit.fileName), // colours come from appBarTheme (hour 5)
        actions: [
          IconButton(
            icon: const Icon(Icons.copy),
            tooltip: 'Copy path',
            onPressed: () {
              Clipboard.setData(ClipboardData(text: hit.path));
              ScaffoldMessenger.of(context)
                  .showSnackBar(const SnackBar(content: Text('Path copied')));
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Info row: page + score
          Wrap(
            spacing: 8,
            children: [
              Chip(label: Text('Page ${hit.page}')),
              if (hit.score != null) Chip(label: Text('Score ${hit.score}')),
            ],
          ),
          const SizedBox(height: 12),

          // Full path, selectable so it can be copied
          Text('Path', style: textTheme.labelLarge),
          SelectableText(hit.path, style: textTheme.bodySmall),
          const Divider(height: 32),

          // Full text of the page, search words highlighted
          Text('Text', style: textTheme.labelLarge),
          const SizedBox(height: 8),
          if (hit.text.isEmpty)
            const Text('(no text for this hit)')
          else
            SelectableText.rich(
              highlightSpans(
                hit.text,
                query,
                style: textTheme.bodyMedium?.copyWith(height: 1.5),
                color: colors.secondary,
              ),
            ),
        ],
      ),
    );
  }
}
