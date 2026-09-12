import 'package:flutter_test/flutter_test.dart';
import 'package:market_price/models/price_series.dart';
import 'package:market_price/services/range_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => ChartRangeSetting.value.value = ChartRange.d1);

  test('varsayılan 1 gün, seçim cihaza yazılır', () async {
    SharedPreferences.setMockInitialValues({});

    await ChartRangeSetting.load();
    expect(ChartRangeSetting.value.value, ChartRange.d1);

    await ChartRangeSetting.set(ChartRange.y1);
    expect(ChartRangeSetting.value.value, ChartRange.y1);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('chart_range_v1'), 'y1');
  });

  test('kayıtlı aralık açılışta geri yüklenir', () async {
    SharedPreferences.setMockInitialValues({'flutter.chart_range_v1': 'm6'});

    await ChartRangeSetting.load();
    expect(ChartRangeSetting.value.value, ChartRange.m6);
  });

  test('bilinmeyen kayıt yok sayılır', () async {
    SharedPreferences.setMockInitialValues({'flutter.chart_range_v1': 'yok'});

    await ChartRangeSetting.load();
    expect(ChartRangeSetting.value.value, ChartRange.d1);
  });

  test('değişiklik dinleyicilere duyurulur', () async {
    SharedPreferences.setMockInitialValues({});

    var notified = 0;
    void listener() => notified++;
    ChartRangeSetting.value.addListener(listener);
    addTearDown(() => ChartRangeSetting.value.removeListener(listener));

    await ChartRangeSetting.set(ChartRange.w1);
    // Aynı değeri tekrar yazmak dinleyicileri boşuna tetiklemesin.
    await ChartRangeSetting.set(ChartRange.w1);

    expect(notified, 1);
  });
}
