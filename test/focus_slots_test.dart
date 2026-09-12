import 'package:flutter_test/flutter_test.dart';
import 'package:market_price/data/asset_catalog.dart';
import 'package:market_price/models/asset.dart';
import 'package:market_price/services/focus_store.dart';

void main() {
  Asset byId(String id) => kAssets.firstWhere((a) => a.id == id);

  final watchlist = [
    byId('wti'),
    byId('gold_gram'),
    byId('usdtry'),
    byId('eurtry'),
    byId('btcusd'),
  ];

  List<String?> ids(FocusSlots s) => [
    s.primary?.id,
    ...s.secondary.map((a) => a?.id),
  ];

  test('seçim yoksa yuvalar liste sırasıyla dolar', () {
    expect(ids(resolveFocus(const FocusConfig(), watchlist)), [
      'wti',
      'gold_gram',
      'usdtry',
    ]);
  });

  test('seçilen varlıklar yuvalarında kalır, boşluk sırayla dolar', () {
    const config = FocusConfig(
      primaryId: 'btcusd',
      secondaryIds: ['', 'eurtry'],
    );
    expect(ids(resolveFocus(config, watchlist)), ['btcusd', 'wti', 'eurtry']);
  });

  test('izleme listesinden çıkarılan seçim yok sayılır', () {
    const config = FocusConfig(primaryId: 'sp500');
    expect(ids(resolveFocus(config, watchlist)).first, 'wti');
  });

  test('aynı varlık iki yuvada görünmez', () {
    const config = FocusConfig(primaryId: 'wti', secondaryIds: ['wti', 'wti']);
    final result = ids(resolveFocus(config, watchlist));
    expect(result.toSet().length, 3);
  });

  test('liste yuvalardan kısaysa boş yuva kalır', () {
    final short = [byId('wti'), byId('usdtry')];
    expect(ids(resolveFocus(const FocusConfig(), short)), [
      'wti',
      'usdtry',
      null,
    ]);
  });

  test('büyük karta seçim yapınca ayar yazılır', () {
    final config = assignFocus(
      const FocusConfig(),
      watchlist,
      slot: 0,
      id: 'eurtry',
    );
    expect(ids(resolveFocus(config, watchlist)).first, 'eurtry');
  });

  test('ikinci küçük karta seçim doğru yuvaya gider', () {
    final config = assignFocus(
      const FocusConfig(),
      watchlist,
      slot: 2,
      id: 'btcusd',
    );
    expect(ids(resolveFocus(config, watchlist)), [
      'wti',
      'gold_gram',
      'btcusd',
    ]);
  });

  test('başka yuvadaki varlık seçilirse yuvalar yer değiştirir', () {
    // Varsayılan: [wti, gold_gram, usdtry]. Büyük karta usdtry seçilirse
    // wti onun yerine geçmeli.
    final config = assignFocus(
      const FocusConfig(),
      watchlist,
      slot: 0,
      id: 'usdtry',
    );
    expect(ids(resolveFocus(config, watchlist)), [
      'usdtry',
      'gold_gram',
      'wti',
    ]);
  });
}
