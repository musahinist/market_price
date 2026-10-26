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
          return MapEntry(s, await _fetchOne(await _quoteSymbol(s)));
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
  ///
  /// Sürekli vadeli sembollerde (`BZ=F` gibi) Yahoo geçmişi o gün vadesi en
  /// yakın kontrattan çizer; kontrat devrildiğinde seri, fiyatı gösterilen
  /// kontrata göre birden sıçrar (Brent'te ~%4-5). Bu yüzden grafik güncel
  /// kontratın kendi serisinden çekilir; o kontratın geçmişi pencereyi
  /// kapsamıyorsa eksik baş kısım sürekli seriden oranlanarak eklenir.
  Future<PriceSeries> fetchSeries(String symbol, ChartRange range) async {
    final contract = isContinuousFuture(symbol)
        ? await _frontContract(symbol).catchError((_) => null)
        : null;
    if (contract == null) return _fetchRawSeries(symbol, range);

    final results = await Future.wait([
      _fetchRawSeries(symbol, range),
      _fetchRawSeries(
        contract,
        range,
      ).then<PriceSeries?>((s) => s, onError: (_) => null),
    ]);
    final continuous = results[0]!;
    final own = results[1];
    return own == null ? continuous : own.extendedWith(continuous);
  }

  /// Fiyatın çekileceği sembol. Vadesi en yakın kontratı izleyen köklerde
  /// (bkz. [followsNearestContract]) o kontrat, diğerlerinde sembolün kendisi.
  Future<String> _quoteSymbol(String symbol) async {
    if (!followsNearestContract(symbol)) return symbol;
    return await _frontContract(symbol).catchError((_) => null) ?? symbol;
  }

  /// Bir sürekli vadeli sembolün gösterilecek kontratı.
  ///
  /// [followsNearestContract] köklerinde vadesi en yakın, hâlâ işlem gören
  /// kontrat; diğerlerinde Yahoo'nun sürekli sembolünün izlediği kontrat
  /// (ör. BZ=F -> BZF27.NYM). Yahoo hangisi olduğunu chart ucunda vermiyor;
  /// fiyatı sürekli sembolünkiyle eşleşeni seçiyoruz. Sonuç bir saat saklanır.
  Future<String?> _frontContract(String symbol) async {
    final cached = _contractCache[symbol];
    if (cached != null &&
        DateTime.now().difference(cached.$2) < const Duration(hours: 1)) {
      return cached.$1;
    }

    final candidates = futureContracts(symbol, DateTime.now());
    if (candidates.isEmpty) return null;

    final quotes = await Future.wait([
      for (final s in [symbol, ...candidates])
        _fetchOne(s).then<Quote?>((q) => q, onError: (_) => null),
    ]);

    if (followsNearestContract(symbol)) {
      final best = nearestLiveContract(candidates, quotes.sublist(1));
      _contractCache[symbol] = (best, DateTime.now());
      return best;
    }

    final prices = [for (final q in quotes) q?.price];
    final target = prices.first;
    if (target == null) return null;

    String? best;
    var bestDiff = double.infinity;
    for (var i = 0; i < candidates.length; i++) {
      final price = prices[i + 1];
      if (price == null) continue;
      final diff = (price - target).abs() / target;
      if (diff < bestDiff) {
        bestDiff = diff;
        best = candidates[i];
      }
    }
    // Komşu kontratlar arasındaki fark bundan büyük; eşleşme yoksa sürekli
    // seriye düş.
    if (bestDiff > 0.001) best = null;

    _contractCache[symbol] = (best, DateTime.now());
    return best;
  }

  static final _contractCache = <String, (String?, DateTime)>{};

  Future<PriceSeries> _fetchRawSeries(String symbol, ChartRange range) async {
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
    double? field(String key) => (meta?[key] as num?)?.toDouble();
    final previousClose = switch (range) {
      // 1G yüzdesi listedeki günlük değişimle aynı olsun. Kriptoda
      // chartPreviousClose gece yarısı (UTC) fiyatı, günlük değişim ise başka
      // bir referansa göre; ikisi farklı çıkıyor.
      ChartRange.d1 =>
        _previousFromChange(
              field('regularMarketPrice'),
              field('regularMarketChangePercent'),
            ) ??
            field('chartPreviousClose'),
      // Çok günlük gün içi seride Yahoo'nun chartPreviousClose'u güvenilmez:
      // kripto ve BIST'te pencerenin ilk gününün kapanışını veriyor. 1H'de
      // referans serinin ilk noktası.
      ChartRange.w1 => null,
      _ => field('chartPreviousClose'),
    };
    return PriceSeries(
      times: times,
      values: values,
      currency: (meta?['currency'] as String?) ?? '',
      previousClose: previousClose ?? values.first,
    );
  }

  static double? _previousFromChange(double? price, double? changePercent) {
    if (price == null || changePercent == null || changePercent <= -100) {
      return null;
    }
    return price / (1 + changePercent / 100);
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

/// Yahoo'nun sürekli vadeli sembolü mü (ör. `BZ=F`).
bool isContinuousFuture(String symbol) => symbol.endsWith('=F');

/// Vadesi en yakın kontratı izleyen kökler.
///
/// Yahoo `BZ=F`'yi hacme göre vadeden ~bir hafta önce sonraki kontrata
/// geçiriyor; Brent fiyatı denince ise yaygın olarak vadesi dolana kadar en
/// yakın kontrat kastediliyor (Ekim 2026'da 115 $'lık Aralık yerine Yahoo
/// 110 $'lık Ocak'ı gösteriyordu). Diğer köklerde Yahoo'nun seçimi piyasanın
/// alışılmış kontratıyla aynı (altında Kasım değil Aralık gibi).
const _nearestContractRoots = {'BZ'};

bool followsNearestContract(String symbol) =>
    isContinuousFuture(symbol) &&
    _nearestContractRoots.contains(symbol.substring(0, symbol.length - 2));

/// [candidates] arasında vadesi en yakın, hâlâ işlem gören kontrat.
///
/// [quotes] adaylarla aynı sırada; vadesi dolmuş kontrat ya hiç dönmüyor ya da
/// son işlem zamanı en tazesinden günlerce geride kalıyor.
String? nearestLiveContract(List<String> candidates, List<Quote?> quotes) {
  final times = [for (final q in quotes) ?q?.time];
  if (times.isEmpty) return null;
  final freshest = times.reduce((a, b) => a.isAfter(b) ? a : b);
  for (var i = 0; i < candidates.length; i++) {
    final q = quotes[i];
    if (q != null && freshest.difference(q.time) < const Duration(days: 2)) {
      return candidates[i];
    }
  }
  return null;
}

/// Kontrat sembollerinin borsa son ekleri.
const _futureExchanges = {
  'BZ': 'NYM',
  'CL': 'NYM',
  'NG': 'NYM',
  'PL': 'NYM',
  'PA': 'NYM',
  'GC': 'CMX',
  'SI': 'CMX',
  'HG': 'CMX',
};

const _monthCodes = 'FGHJKMNQUVXZ';

/// [symbol] için [now] ayından başlayan altı aylık kontrat sembolleri.
///
/// Ör. BZ=F, Ekim 2026 -> BZV26.NYM, BZX26.NYM, BZZ26.NYM, BZF27.NYM, ...
/// Bilinmeyen kökte boş döner.
List<String> futureContracts(String symbol, DateTime now) {
  final root = symbol.substring(0, symbol.length - 2);
  final exchange = _futureExchanges[root];
  if (exchange == null) return const [];
  return [
    for (var i = 0; i < 6; i++)
      _contractSymbol(root, exchange, DateTime(now.year, now.month + i)),
  ];
}

String _contractSymbol(String root, String exchange, DateTime month) {
  final yy = (month.year % 100).toString().padLeft(2, '0');
  return '$root${_monthCodes[month.month - 1]}$yy.$exchange';
}

class MarketException implements Exception {
  const MarketException(this.message);
  final String message;
  @override
  String toString() => message;
}
