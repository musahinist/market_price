import 'package:shared_preferences/shared_preferences.dart';

/// Kullanıcının izleme listesine aldığı varlık id'lerini cihazda saklar.
class WatchStore {
  static const _key = 'watchlist_v1';

  Future<Set<String>> load() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_key) ?? const []).toSet();
  }

  Future<void> save(Set<String> ids) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_key, ids.toList());
  }
}
