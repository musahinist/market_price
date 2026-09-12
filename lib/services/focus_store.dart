import 'package:shared_preferences/shared_preferences.dart';

import '../models/asset.dart';

/// İzleme sekmesinin üstündeki odak bloklarının ayarı.
class FocusConfig {
  const FocusConfig({
    this.primaryId,
    this.secondaryIds = const [],
    this.primaryOpen = true,
    this.secondaryOpen = true,
    this.listOpen = true,
    this.chartOpen = true,
  });

  /// Büyük kartta gösterilen varlık. Boşsa izleme listesinin ilki kullanılır.
  final String? primaryId;

  /// İki küçük kartta gösterilen varlıklar.
  final List<String> secondaryIds;

  final bool primaryOpen;
  final bool secondaryOpen;
  final bool listOpen;
  final bool chartOpen;

  FocusConfig copyWith({
    String? primaryId,
    List<String>? secondaryIds,
    bool? primaryOpen,
    bool? secondaryOpen,
    bool? listOpen,
    bool? chartOpen,
  }) => FocusConfig(
    primaryId: primaryId == '' ? null : (primaryId ?? this.primaryId),
    secondaryIds: secondaryIds ?? this.secondaryIds,
    primaryOpen: primaryOpen ?? this.primaryOpen,
    secondaryOpen: secondaryOpen ?? this.secondaryOpen,
    listOpen: listOpen ?? this.listOpen,
    chartOpen: chartOpen ?? this.chartOpen,
  );
}

class FocusStore {
  static const _primary = 'focus_primary_v1';
  static const _secondary = 'focus_secondary_v1';
  static const _open = 'focus_open_v1';

  Future<FocusConfig> load() async {
    final prefs = await SharedPreferences.getInstance();
    final open = (prefs.getStringList(_open) ?? const []).toSet();
    final hasOpen = prefs.getStringList(_open) != null;

    return FocusConfig(
      primaryId: prefs.getString(_primary),
      secondaryIds: prefs.getStringList(_secondary) ?? const [],
      // İlk açılışta hepsi açık.
      primaryOpen: !hasOpen || open.contains('primary'),
      secondaryOpen: !hasOpen || open.contains('secondary'),
      listOpen: !hasOpen || open.contains('list'),
      chartOpen: !hasOpen || open.contains('chart'),
    );
  }

  Future<void> save(FocusConfig config) async {
    final prefs = await SharedPreferences.getInstance();
    if (config.primaryId == null) {
      await prefs.remove(_primary);
    } else {
      await prefs.setString(_primary, config.primaryId!);
    }
    await prefs.setStringList(_secondary, config.secondaryIds);
    await prefs.setStringList(_open, [
      if (config.primaryOpen) 'primary',
      if (config.secondaryOpen) 'secondary',
      if (config.listOpen) 'list',
      if (config.chartOpen) 'chart',
    ]);
  }
}

/// Odak yuvalarına yerleşen varlıklar.
class FocusSlots {
  const FocusSlots({required this.primary, required this.secondary});

  final Asset? primary;

  /// İki ikincil yuva; dolacak varlık kalmadıysa null.
  final List<Asset?> secondary;
}

/// Ayardaki seçimleri izleme listesine oturtur.
///
/// Seçilmemiş ya da artık listede olmayan yuvalar, listenin sırasıyla soldan
/// sağa doldurulur; aynı varlık iki yuvada görünmez.
FocusSlots resolveFocus(FocusConfig config, List<Asset> watchlist) {
  final byId = {for (final a in watchlist) a.id: a};
  final used = <String>{};

  Asset? claim(String? id) {
    if (id == null || id.isEmpty) return null;
    final asset = byId[id];
    if (asset == null || !used.add(asset.id)) return null;
    return asset;
  }

  final primary = claim(config.primaryId);
  final secondary = [
    for (var i = 0; i < 2; i++)
      claim(i < config.secondaryIds.length ? config.secondaryIds[i] : null),
  ];

  // Boş yuvaları listenin başından doldur.
  final rest = watchlist.where((a) => !used.contains(a.id)).iterator;
  Asset? next() => rest.moveNext() ? rest.current : null;

  return FocusSlots(
    primary: primary ?? next(),
    secondary: [for (final a in secondary) a ?? next()],
  );
}

/// [slot]'a (0 = büyük kart, 1-2 = küçük kartlar) [id]'yi yerleştirir.
///
/// Varlık başka bir yuvadaysa iki yuva yer değiştirir; böylece aynı varlık
/// iki kartta birden görünmez.
FocusConfig assignFocus(
  FocusConfig config,
  List<Asset> watchlist, {
  required int slot,
  required String id,
}) {
  final slots = resolveFocus(config, watchlist);
  final current = [slots.primary?.id, ...slots.secondary.map((a) => a?.id)];

  final previous = current[slot];
  final existing = current.indexOf(id);
  current[slot] = id;
  // Varlık başka yuvadaysa oraya eskisini koy.
  if (existing >= 0 && existing != slot) current[existing] = previous;

  return config.copyWith(
    primaryId: current[0] ?? '',
    secondaryIds: [current[1] ?? '', current[2] ?? ''],
  );
}
