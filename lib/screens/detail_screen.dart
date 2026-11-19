// Detail page for one search hit (used on narrow screens).
//
// Hour 1: navigation - data comes in through the constructor; the AppBar back
//         arrow calls Navigator.pop automatically.
// Hour 1 exercise: copy button in the AppBar.
// Hour 7: the content moved into widgets/detail_view.dart, so the wide
//         layout can show the same content next to the list.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:code_lookup/models/search_hit.dart';
import 'package:code_lookup/widgets/detail_view.dart';

class DetailScreen extends StatelessWidget {
  const DetailScreen({super.key, required this.hit, this.query = ''});

  final SearchHit hit;
  final String query;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(hit.fileName), // colours come from appBarTheme (hour 5)
        actions: [
          IconButton(
            icon: const Icon(Icons.copy),
            tooltip: 'Copy path',
            onPressed: () {
              Clipboard.setData(ClipboardData(text: hit.path));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Path copied')),
              );
            },
          ),
        ],
      ),
      body: DetailView(hit: hit, query: query),
    );
  }
}
