import 'package:flutter_test/flutter_test.dart';
import 'package:market_price/data/asset_catalog.dart';
import 'package:market_price/models/price_series.dart';
import 'package:market_price/models/quote.dart';
import 'package:market_price/services/news_service.dart';
import 'package:market_price/services/order_store.dart';

void main() {
  test('gram altın ons fiyatı ve kurdan hesaplanır', () {
    final now = DateTime.now();
    final quotes = {
      'PAXG-USD': Quote(
        price: 4354.91,
        changePercent: -0.07,
        currency: 'USD',
        time: now,
      ),
      'TRY=X': Quote(
        price: 48.55,
        changePercent: 0.05,
        currency: 'TRY',
        time: now,
      ),
    };

    final gram = kAssets.firstWhere((a) => a.id == 'gold_gram');
    final q = gram.derive!(quotes)!;

    expect(q.price, closeTo(4354.91 / 31.1034768 * 48.55, 0.01));
    expect(q.currency, 'TRY');
  });

  test('veri eksikse türetilmiş varlık null döner', () {
    final gram = kAssets.firstWhere((a) => a.id == 'gold_gram');
    expect(gram.derive!({}), isNull);
  });

  test('her varlığın ya sembolü ya türeticisi var', () {
    for (final a in kAssets) {
      expect(a.symbol != null || a.derive != null, isTrue, reason: a.id);
    }
  });

  test('kayıtlı sıra uygulanır, yeni varlıklar sona eklenir', () {
    final ids = kAssets.map((a) => a.id).toList();
    final saved = [ids.last, ids.first];

    final ordered = applyOrder(saved, kAssets);

    expect(ordered.first.id, ids.last);
    expect(ordered[1].id, ids.first);
    expect(ordered.length, kAssets.length);
    expect(ordered.map((a) => a.id).toSet(), ids.toSet());
  });

  test('bilinmeyen id yok sayılır, boş kayıt varsayılan sırayı verir', () {
    expect(
      applyOrder(['yok-boyle-bir-sey'], kAssets).map((a) => a.id),
      kAssets.map((a) => a.id),
    );
    expect(applyOrder([], kAssets).map((a) => a.id), kAssets.map((a) => a.id));
  });

  test('RSS ayrıştırılır ve başlıktaki kaynak eki temizlenir', () {
    const xml = '''
<rss><channel>
<item>
  <title>Brent petrol &#39;yükseldi&#39; - NTV</title>
  <link>https://example.com/1</link>
  <pubDate>Fri, 11 Sep 2026 11:42:48 GMT</pubDate>
  <source url="https://ntv.com.tr">NTV</source>
</item>
<item>
  <title>Ikinci haber - CNBC-e</title>
  <link>https://example.com/2</link>
  <pubDate>Thu, 10 Sep 2026 20:56:00 GMT</pubDate>
  <source url="https://cnbce.com">CNBC-e</source>
</item>
</channel></rss>''';

    final items = parseRss(xml);

    expect(items, hasLength(2));
    expect(items.first.title, "Brent petrol 'yükseldi'");
    expect(items.first.source, 'NTV');
    expect(items.first.link, 'https://example.com/1');
    expect(
      items.first.publishedAt!.toUtc(),
      DateTime.utc(2026, 9, 11, 11, 42, 48),
    );
  });

  test('sayısal HTML varlıkları çözülür', () {
    const xml =
        '<rss><item><title>Fiyat &#8217;yeni&#8217; zirvede</title></item></rss>';
    expect(parseRss(xml).first.title, 'Fiyat \u2019yeni\u2019 zirvede');
  });

  test('boş RSS gövdesi boş liste verir', () {
    expect(parseRss('<rss><channel></channel></rss>'), isEmpty);
  });

  test('kur serisi her noktaya kendi tarihindeki kurla uygulanır', () {
    final t0 = DateTime(2025, 9, 12);
    final t1 = DateTime(2026, 9, 12);

    final ounce = PriceSeries(
      times: [t0, t1],
      values: [3000, 4000],
      currency: 'USD',
      previousClose: 2900,
    );
    // Kur bir yılda 41 -> 48,55.
    final fx = PriceSeries(
      times: [t0, t1],
      values: [41, 48.55],
      currency: 'TRY',
      previousClose: 40,
    );

    final gram = ounce.convertedWith(fx, divisor: 31.1034768);

    expect(gram.values.first, closeTo(3000 * 41 / 31.1034768, 0.01));
    expect(gram.values.last, closeTo(4000 * 48.55 / 31.1034768, 0.01));
    expect(gram.previousClose, closeTo(2900 * 40 / 31.1034768, 0.01));
    expect(gram.currency, 'TRY');

    // Kur hareketi dahil olduğu için TL değişimi USD değişiminden büyük olmalı.
    expect(gram.changePercent, greaterThan(ounce.changePercent));
  });

  test('rateAt seriden en yakın önceki kuru seçer', () {
    final fx = PriceSeries(
      times: [DateTime(2026, 1, 1), DateTime(2026, 2, 1), DateTime(2026, 3, 1)],
      values: [10, 20, 30],
      currency: 'TRY',
      previousClose: 9,
    );

    expect(fx.rateAt(DateTime(2025, 12, 1)), 10); // seriden önce
    expect(fx.rateAt(DateTime(2026, 1, 15)), 10);
    expect(fx.rateAt(DateTime(2026, 2, 1)), 20); // tam eşleşme
    expect(fx.rateAt(DateTime(2026, 9, 1)), 30); // seriden sonra
  });

  test('yalnızca görünen varlıkların sembolleri istenir', () {
    final gram = kAssets.firstWhere((a) => a.id == 'gold_gram');
    final usd = kAssets.firstWhere((a) => a.id == 'usdtry');

    expect(symbolsFor([usd]), ['TRY=X']);
    // Türetilmiş varlık dayanaklarını da ister, tekrarsız.
    expect(symbolsFor([gram, usd]).toSet(), {'PAXG-USD', 'TRY=X'});
    expect(symbolsFor(kAssets).length, lessThan(kAssets.length));
  });

  test('her varlığın gereken sembolleri katalogda tanımlı', () {
    for (final a in kAssets) {
      expect(a.requiredSymbols, isNotEmpty, reason: a.id);
      if (a.symbol == null) {
        expect(a.deps, isNotEmpty, reason: '${a.id} deps eksik');
      }
    }
  });

  test('türetilmiş varlıkta 52 haftalık aralık gösterilmez', () {
    final now = DateTime.now();
    final quotes = {
      'PAXG-USD': Quote(
        price: 4355,
        changePercent: 0,
        currency: 'USD',
        time: now,
        dayLow: 4350,
        dayHigh: 4360,
        weekLow: 3630,
        weekHigh: 5622,
      ),
      'TRY=X': Quote(
        price: 48.55,
        changePercent: 0,
        currency: 'TRY',
        time: now,
      ),
    };

    final gram = kAssets.firstWhere((a) => a.id == 'gold_gram').derive!(
      quotes,
    )!;

    // Gün aralığı çevrilir, 52 hafta bugünkü kurla çevrilemeyeceği için düşer.
    expect(gram.dayLow, closeTo(4350 * 48.55 / 31.1034768, 0.01));
    expect(gram.weekLow, isNull);
    expect(gram.weekHigh, isNull);
    expect(gram.weekPosition, isNull);
  });
}
