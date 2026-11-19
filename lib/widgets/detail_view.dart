// Hour 7: the CONTENT of the detail page, without Scaffold/AppBar.
//
// Why a separate widget: on a narrow screen it is shown inside DetailScreen
// (a page of its own); on a wide screen (step 2) it sits next to the result
// list. One widget, two places - no duplicated code.

import 'package:flutter/material.dart';

import 'package:code_lookup/models/search_hit.dart';
import 'package:code_lookup/utils/highlight.dart';

class DetailView extends StatelessWidget {
  const DetailView({super.key, required this.hit, this.query = ''});

  final SearchHit hit;
  final String query; // search words to highlight

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colors = Theme.of(context).colorScheme;

    return ListView(
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
    );
  }
}
