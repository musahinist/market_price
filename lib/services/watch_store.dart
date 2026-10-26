import 'package:shared_preferences/shared_preferences.dart';

/// Kullanıcının izleme listesine aldığı varlık id'lerini cihazda saklar.
class WatchStore {
  static const _key = 'watchlist_v1';
  static const _seedKey = 'watchlist_seed_v1';

  /// Uygulama güncellemesiyle izleme listesine bir kez eklenen varlıklar.
  ///
  /// Kullanıcı sonradan çıkarırsa geri gelmez: bayrak bir kez yazılır.
  static const seeded = ['paxg', 'usdttry'];

  Future<Set<String>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final ids = (prefs.getStringList(_key) ?? const []).toSet();
    if (prefs.getBool(_seedKey) ?? false) return ids;

    ids.addAll(seeded);
    await prefs.setStringList(_key, ids.toList());
    await prefs.setBool(_seedKey, true);
    return ids;
  }

  Future<void> save(Set<String> ids) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_key, ids.toList());
  }
}
