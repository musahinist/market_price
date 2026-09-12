import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/fund.dart';

/// Fon listesini günlük önbelleğe alır.
///
/// TEFAS'ın getiri listesi ~650 KB ve fonlar günde bir fiyatlanıyor; her
/// açılışta yeniden indirmenin anlamı yok.
class FundCache {
  static const _key = 'fund_cache_v1';

  /// Bugün kaydedilmiş liste; yoksa ya da bayatsa null.
  Future<List<Fund>?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return null;

    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      if (json['date'] != _today()) return null;

      return [
        for (final item in json['funds'] as List)
          Fund.fromJson(item as Map<String, dynamic>),
      ];
    } catch (_) {
      return null; // Biçim değiştiyse yeniden indir.
    }
  }

  Future<void> save(List<Fund> funds) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      jsonEncode({
        'date': _today(),
        'funds': [for (final fund in funds) fund.toJson()],
      }),
    );
  }

  static String _today() {
    final now = DateTime.now();
    return '${now.year}-${now.month}-${now.day}';
  }
}
