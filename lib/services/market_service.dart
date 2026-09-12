import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/asset.dart';
import '../models/price_series.dart';
import '../models/quote.dart';

/// Yahoo Finance'in açık chart uç noktasından fiyat çeker.
///
/// Anahtar gerektirmez; her sembol için tek bir istek atılır ve hepsi paralel
/// çalışır.
class MarketService {
  MarketService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static const _base = 'https://query1.finance.yahoo.com/v8/finance/chart';
  static const _headers = {
    'User-Agent':
        'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 '
        '(KHTML, like Gecko) Chrome/124.0 Safari/537.36',
    'Accept': 'application/json',
  };

  /// Verilen sembollerin fiyatlarını paralel çeker.
  ///
  /// Tek tek başarısız olan semboller sonuçtan düşer; tamamı başarısız olursa
  /// [MarketException] fırlatır.
  Future<Map<String, Quote>> fetchQuotes(List<String> symbols) async {
    final results = await Future.wait(
      symbols.map((s) async {
        try {
          return MapEntry(s, await _fetchOne(s));
        } catch (_) {
          return MapEntry(s, null);
        }
      }),
    );

    final quotes = <String, Quote>{
      for (final e in results)
        if (e.value != null) e.key: e.value!,
    };

    if (quotes.isEmpty) {
      throw const MarketException('Fiyatlar alınamadı. Bağlantını kontrol et.');
    }
    return quotes;
  }

  /// Bir varlığın grafiğini gösterim birimiyle çeker.
  ///
  /// Türetilmiş varlıklarda kur serisi de çekilip her noktaya kendi tarihindeki
  /// kur uygulanır.
  Future<PriceSeries> fetchAssetSeries(Asset asset, ChartRange range) async {
    final symbol = asset.effectiveChartSymbol;
    if (symbol == null) {
      throw const MarketException('Bu varlık için grafik yok.');
    }

    final fxSymbol = asset.chartFxSymbol;
    final results = await Future.wait([
      fetchSeries(symbol, range),
      if (fxSymbol != null) fetchSeries(fxSymbol, range),
    ]);

    if (results.length == 1) return results.first;
    return results.first.convertedWith(results[1], divisor: asset.chartDivisor);
  }

  /// Bir sembolün [range] aralığındaki kapanış serisini çeker.
  Future<PriceSeries> fetchSeries(String symbol, ChartRange range) async {
    final uri = Uri.parse(
      '$_base/${Uri.encodeComponent(symbol)}'
      '?interval=${range.interval}&range=${range.range}',
    );
    final res = await _client
        .get(uri, headers: _headers)
        .timeout(const Duration(seconds: 15));

    if (res.statusCode != 200) {
      throw MarketException('Grafik alınamadı (HTTP ${res.statusCode}).');
    }

    final result =
        (jsonDecode(res.body) as Map<String, dynamic>)['chart']?['result']?[0];
    if (result is! Map) throw const MarketException('Grafik verisi yok.');

    final stamps = (result['timestamp'] as List?) ?? const [];
    final closes =
        (result['indicators']?['quote']?[0]?['close'] as List?) ?? const [];

    final times = <DateTime>[];
    final values = <double>[];
    for (var i = 0; i < stamps.length && i < closes.length; i++) {
      final close = closes[i];
      if (close is! num) continue; // Yahoo kapalı seanslarda null döner.
      times.add(
        DateTime.fromMillisecondsSinceEpoch((stamps[i] as num).toInt() * 1000),
      );
      values.add(close.toDouble());
    }

    if (values.isEmpty) throw const MarketException('Grafik verisi yok.');

    final meta = result['meta'] as Map?;
    return PriceSeries(
      times: times,
      values: values,
      currency: (meta?['currency'] as String?) ?? '',
      previousClose:
          (meta?['chartPreviousClose'] as num?)?.toDouble() ?? values.first,
    );
  }

  Future<Quote> _fetchOne(String symbol) async {
    final uri = Uri.parse(
      '$_base/${Uri.encodeComponent(symbol)}?interval=1d&range=1d',
    );
    final res = await _client
        .get(uri, headers: _headers)
        .timeout(const Duration(seconds: 12));

    if (res.statusCode != 200) {
      throw MarketException('$symbol: HTTP ${res.statusCode}');
    }

    final meta = (jsonDecode(
      res.body,
    ) as Map<String, dynamic>)['chart']?['result']?[0]?['meta'];
    if (meta is! Map) throw MarketException('$symbol: beklenmeyen yanıt');

    final price = (meta['regularMarketPrice'] as num?)?.toDouble();
    if (price == null) throw MarketException('$symbol: fiyat yok');

    final epoch = (meta['regularMarketTime'] as num?)?.toInt();

    double? field(String key) => (meta[key] as num?)?.toDouble();

    return Quote(
      price: price,
      changePercent: field('regularMarketChangePercent') ?? 0,
      currency: (meta['currency'] as String?) ?? '',
      time: epoch != null
          ? DateTime.fromMillisecondsSinceEpoch(epoch * 1000)
          : DateTime.now(),
      dayLow: field('regularMarketDayLow'),
      dayHigh: field('regularMarketDayHigh'),
      weekLow: field('fiftyTwoWeekLow'),
      weekHigh: field('fiftyTwoWeekHigh'),
      // Yahoo bu uçta önceki kapanışı chartPreviousClose olarak veriyor.
      previousClose: field('chartPreviousClose') ?? field('previousClose'),
    );
  }

  void dispose() => _client.close();
}

class MarketException implements Exception {
  const MarketException(this.message);
  final String message;
  @override
  String toString() => message;
}
