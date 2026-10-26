import 'package:flutter_test/flutter_test.dart';
import 'package:market_price/data/asset_catalog.dart';
import 'package:market_price/models/price_series.dart';
import 'package:market_price/models/quote.dart';
import 'package:market_price/services/market_service.dart';
import 'package:market_price/services/watch_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

Quote _quote(double price, double changePercent) => Quote(
  price: price,
  changePercent: changePercent,
  currency: 'USD',
  time: DateTime(2026, 10, 26),
  previousClose: price / (1 + changePercent / 100),
);

void main() {
  test('vadeli kontrat sembolleri yıl dönümünü aşar', () {
    expect(futureContracts('BZ=F', DateTime(2026, 10, 26)), [
      'BZV26.NYM',
      'BZX26.NYM',
      'BZZ26.NYM',
      'BZF27.NYM',
      'BZG27.NYM',
      'BZH27.NYM',
    ]);
    expect(futureContracts('GC=F', DateTime(2026, 12, 1)).first, 'GCZ26.CMX');
    expect(futureContracts('XX=F', DateTime(2026, 1, 1)), isEmpty);
    expect(isContinuousFuture('BZ=F'), isTrue);
    expect(isContinuousFuture('BTC-USD'), isFalse);
  });

  test('Brent vadesi en yakın canlı kontratı izler', () {
    Quote at(DateTime t) =>
        Quote(price: 1, changePercent: 0, currency: 'USD', time: t);
    final now = DateTime(2026, 10, 26, 16);
    final candidates = ['BZV26.NYM', 'BZX26.NYM', 'BZZ26.NYM', 'BZF27.NYM'];

    // Ekim ve Kasım yok; Aralık hâlâ işlem görüyor.
    expect(
      nearestLiveContract(candidates, [null, null, at(now), at(now)]),
      'BZZ26.NYM',
    );
    // Aralık'ın vadesi doldu: son işlemi günlerce geride kaldı.
    expect(
      nearestLiveContract(candidates, [
        null,
        null,
        at(now.subtract(const Duration(days: 4))),
        at(now),
      ]),
      'BZF27.NYM',
    );
    expect(nearestLiveContract(candidates, [null, null, null, null]), isNull);

    expect(followsNearestContract('BZ=F'), isTrue);
    expect(followsNearestContract('GC=F'), isFalse);
  });

  test('kontrat serisi kısa kalırsa baş kısım oranlanarak eklenir', () {
    final older = PriceSeries(
      times: [DateTime(2026, 1, 1), DateTime(2026, 1, 2), DateTime(2026, 1, 3)],
      values: [100, 110, 116],
      currency: 'USD',
      previousClose: 90,
    );
    // Devirden sonraki kontrat 5 $ aşağıda işliyor.
    final own = PriceSeries(
      times: [DateTime(2026, 1, 3)],
      values: [111],
      currency: 'USD',
      previousClose: 109,
    );

    final joined = own.extendedWith(older);
    final ratio = 111 / 116;
    expect(joined.values.length, 3);
    expect(joined.values[0], closeTo(100 * ratio, 1e-9));
    expect(joined.values[1], closeTo(110 * ratio, 1e-9));
    expect(joined.values.last, 111);
    expect(joined.previousClose, closeTo(90 * ratio, 1e-9));
  });

  test('pencereyi kapsayan kontrat serisi olduğu gibi kalır', () {
    final series = PriceSeries(
      times: [DateTime(2026, 1, 1), DateTime(2026, 1, 2)],
      values: [10, 11],
      currency: 'USD',
      previousClose: 9,
    );
    expect(identical(series.extendedWith(series), series), isTrue);
  });

  test('TL çevriminde yüzde bileşik, önceki kapanış tutarlı', () {
    final quotes = {
      'USDT-USD': _quote(1.0, 0),
      'TRY=X': _quote(50, 1),
      'BTC-USD': _quote(80000, 10),
    };
    final btc = kAssets.firstWhere((a) => a.id == 'btctry').quoteFrom(quotes)!;
    // %10 ve %1: toplam 11 değil 11,1.
    expect(btc.changePercent, closeTo(11.1, 1e-9));
    expect(btc.price, 4000000);
    expect(
      (btc.price - btc.previousClose!) / btc.previousClose! * 100,
      closeTo(btc.changePercent, 1e-9),
    );

    final usdt = kAssets.firstWhere((a) => a.id == 'usdttry');
    expect(usdt.quoteFrom(quotes)!.price, 50);
  });

  test('PAXG ve USDT izleme listesine bir kez eklenir', () async {
    SharedPreferences.setMockInitialValues({
      'watchlist_v1': ['brent'],
    });
    final store = WatchStore();
    expect(await store.load(), {'brent', 'paxg', 'usdttry'});

    // Kullanıcı çıkarırsa geri gelmez.
    await store.save({'brent'});
    expect(await store.load(), {'brent'});
  });
}
