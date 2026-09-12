import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/price_series.dart';

/// Bütün grafiklerin paylaştığı zaman aralığı seçimi.
///
/// Kullanıcı bir grafikte 1Y seçtiğinde odak kartı ve diğer detay sayfaları da
/// 1Y açılsın diye tek bir yerde tutulup cihaza yazılır.
class ChartRangeSetting {
  ChartRangeSetting._();

  static const _key = 'chart_range_v1';

  static final ValueNotifier<ChartRange> value = ValueNotifier(ChartRange.d1);

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_key);
    if (saved == null) return;

    for (final range in ChartRange.values) {
      if (range.name == saved) {
        value.value = range;
        return;
      }
    }
  }

  static Future<void> set(ChartRange range) async {
    if (range == value.value) return;
    value.value = range;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, range.name);
  }
}
