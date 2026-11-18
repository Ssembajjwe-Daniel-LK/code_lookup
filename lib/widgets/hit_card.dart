// One result card in the hit list. A small, reusable widget:
// everything it needs comes in through the constructor.

import 'package:flutter/material.dart';

import 'package:code_lookup/models/search_hit.dart';
import 'package:code_lookup/utils/highlight.dart';

class HitCard extends StatelessWidget {
  const HitCard({
    super.key,
    required this.hit,
    required this.query,
    required this.onTap,
  });

  final SearchHit hit;
  final String query;
  final VoidCallback onTap; // a function with no parameters

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Card(
      child: ListTile(
        onTap: onTap,
        trailing: const Icon(Icons.chevron_right),
        leading: Icon(Icons.description, color: colors.primary),
        title: Text(
          hit.fileName,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Page ${hit.page}'
              '${hit.score != null ? ' · Score ${hit.score}' : ''}',
            ),
            if (hit.text.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text.rich(
                highlightSpans(hit.snippet, query, color: colors.secondary),
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 4),
            SelectableText(
              hit.path,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
