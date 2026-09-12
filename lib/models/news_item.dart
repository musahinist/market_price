class NewsItem {
  const NewsItem({
    required this.title,
    required this.source,
    required this.link,
    required this.publishedAt,
  });

  final String title;
  final String source;
  final String link;
  final DateTime? publishedAt;
}
