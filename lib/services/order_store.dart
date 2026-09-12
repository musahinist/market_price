import 'package:shared_preferences/shared_preferences.dart';

import '../models/asset.dart';

/// Kullanıcının sürükleyerek belirlediği liste sırasını cihazda saklar.
class OrderStore {
  static const _key = 'asset_order_v1';

  /// Kayıtlı sırayı [catalog] ile birleştirir.
  Future<List<Asset>> load(List<Asset> catalog) async {
    final prefs = await SharedPreferences.getInstance();
    return applyOrder(prefs.getStringList(_key) ?? const [], catalog);
  }

  Future<void> save(List<Asset> assets) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_key, assets.map((a) => a.id).toList());
  }

  Future<List<Asset>> reset(List<Asset> catalog) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
    return List.of(catalog);
  }
}

/// Kayıtlı sırayı katalogla birleştirir.
///
/// Kayıtta olmayan (uygulamaya sonradan eklenmiş ya da yeni yüklenen fon)
/// varlıklar katalog sırasıyla sona eklenir, artık var olmayan id'ler yok
/// sayılır.
List<Asset> applyOrder(List<String> savedIds, List<Asset> catalog) {
  final remaining = {for (final a in catalog) a.id: a};
  final ordered = <Asset>[];

  for (final id in savedIds) {
    final asset = remaining.remove(id);
    if (asset != null) ordered.add(asset);
  }
  ordered.addAll(catalog.where((a) => remaining.containsKey(a.id)));

  return ordered;
}
