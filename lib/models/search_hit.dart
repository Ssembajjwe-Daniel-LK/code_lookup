/// One search hit. Python comparison: like a @dataclass with a from_dict().
/// Works for both tools: search_knowledge_base sends source/page/text/score,
/// lookup_code sends filepath/page_num.
class SearchHit {
  SearchHit({
    required this.path,
    required this.page,
    this.text = '',
    this.score,
  });

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
