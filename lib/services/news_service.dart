import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/news_item.dart';

/// Google Haberler RSS akışından Türkçe haber başlıkları çeker.
class NewsService {
  NewsService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<List<NewsItem>> fetch(String query, {int limit = 12}) async {
    final uri = Uri.https('news.google.com', '/rss/search', {
      'q': query,
      'hl': 'tr',
      'gl': 'TR',
      'ceid': 'TR:tr',
    });

    final res = await _client
        .get(
          uri,
          headers: {
            'User-Agent': 'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36',
          },
        )
        .timeout(const Duration(seconds: 15));

    if (res.statusCode != 200) return const [];
    return parseRss(utf8.decode(res.bodyBytes), limit: limit);
  }

  void dispose() => _client.close();
}

final _itemRe = RegExp(r'<item>(.*?)</item>', dotAll: true);
final _titleRe = RegExp(r'<title>(.*?)</title>', dotAll: true);
final _linkRe = RegExp(r'<link>(.*?)</link>', dotAll: true);
final _dateRe = RegExp(r'<pubDate>(.*?)</pubDate>', dotAll: true);
final _sourceRe = RegExp(r'<source[^>]*>(.*?)</source>', dotAll: true);

/// RSS gövdesini haber listesine çevirir.
List<NewsItem> parseRss(String body, {int limit = 12}) {
  final items = <NewsItem>[];

  for (final match in _itemRe.allMatches(body)) {
    final raw = match.group(1)!;
    final title = _unescape(_titleRe.firstMatch(raw)?.group(1) ?? '');
    if (title.isEmpty) break;

    final source = _unescape(_sourceRe.firstMatch(raw)?.group(1) ?? '');

    items.add(
      NewsItem(
        // Google başlığın sonuna ' - Kaynak' ekler; kaynağı ayrı gösteriyoruz.
        title: source.isNotEmpty && title.endsWith(' - $source')
            ? title.substring(0, title.length - source.length - 3)
            : title,
        source: source,
        link: _unescape(_linkRe.firstMatch(raw)?.group(1) ?? ''),
        publishedAt: _parseDate(_dateRe.firstMatch(raw)?.group(1)),
      ),
    );

    if (items.length >= limit) break;
  }

  return items;
}

DateTime? _parseDate(String? value) {
  if (value == null) return null;
  // Ör. 'Fri, 11 Sep 2026 11:42:48 GMT'
  const months = {
    'Jan': 1,
    'Feb': 2,
    'Mar': 3,
    'Apr': 4,
    'May': 5,
    'Jun': 6,
    'Jul': 7,
    'Aug': 8,
    'Sep': 9,
    'Oct': 10,
    'Nov': 11,
    'Dec': 12,
  };
  final m = RegExp(r'(\d{1,2}) (\w{3}) (\d{4}) (\d{2}):(\d{2}):(\d{2})')
      .firstMatch(value);
  if (m == null || !months.containsKey(m.group(2))) return null;

  return DateTime.utc(
    int.parse(m.group(3)!),
    months[m.group(2)]!,
    int.parse(m.group(1)!),
    int.parse(m.group(4)!),
    int.parse(m.group(5)!),
    int.parse(m.group(6)!),
  ).toLocal();
}

final _numericEntityRe = RegExp(r'&#(x?)([0-9a-fA-F]+);');

String _unescape(String s) => s
    .replaceAllMapped(
      _numericEntityRe,
      (m) => String.fromCharCode(
        int.parse(m.group(2)!, radix: m.group(1)!.isEmpty ? 10 : 16),
      ),
    )
    .replaceAll('<![CDATA[', '')
    .replaceAll(']]>', '')
    .replaceAll('&lt;', '<')
    .replaceAll('&gt;', '>')
    .replaceAll('&quot;', '"')
    .replaceAll('&apos;', "'")
    .replaceAll('&nbsp;', ' ')
    .replaceAll('&amp;', '&')
    .trim();
