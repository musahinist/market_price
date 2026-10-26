import 'quote.dart';

enum AssetGroup { emtia, doviz, kripto, endeks, fon }

extension AssetGroupLabel on AssetGroup {
  String get label => switch (this) {
    AssetGroup.emtia => 'Emtia & Metal',
    AssetGroup.doviz => 'Döviz',
    AssetGroup.kripto => 'Kripto',
    AssetGroup.endeks => 'Endeks',
    AssetGroup.fon => 'Fon',
  };
}

/// Listede gösterilecek bir varlığın tanımı.
///
/// [symbol] doluysa fiyat doğrudan Yahoo Finance'ten çekilir. Boşsa fiyat
/// [derive] ile başka varlıkların fiyatlarından hesaplanır (ör. gram altın).
class Asset {
  const Asset({
    required this.id,
    required this.name,
    required this.icon,
    required this.group,
    required this.unit,
    this.symbol,
    this.derive,
    this.deps = const [],
    this.chartSymbol,
    this.chartFxSymbol,
    this.chartDivisor = 1,
    this.decimals = 2,
    this.suffix = '',
    this.fundCode,
    required this.newsQuery,
  });

  final String id;
  final String name;
  final String icon;
  final AssetGroup group;

  /// Fiyatın yanında gösterilecek birim, ör. '\$' veya '₺'.
  final String unit;

  /// Yahoo Finance sembolü.
  final String? symbol;

  /// Türetilmiş fiyat hesaplayıcı. Ham fiyatları alır, null dönerse gizlenir.
  final Quote? Function(Map<String, Quote> quotes)? derive;

  /// [derive]'ın ihtiyaç duyduğu semboller.
  final List<String> deps;

  /// Bu varlığı gösterebilmek için çekilmesi gereken semboller.
  Iterable<String> get requiredSymbols => [?symbol, ...deps];

  /// Grafiğin çekileceği sembol. Türetilmiş varlıklarda dayanak sembol olur.
  final String? chartSymbol;

  /// Grafik serisini gösterim birimine çevirmek için çarpılacak kur sembolü.
  ///
  /// Ör. gram altında 'TRY=X'; her nokta o tarihteki kurla çarpılır.
  final String? chartFxSymbol;

  /// Kurla çarptıktan sonra bölünecek sabit (ör. ons -> gram için 31,1).
  final double chartDivisor;

  final int decimals;

  /// Fiyatın sonuna eklenecek işaret, ör. faizlerde '%'.
  final String suffix;

  /// TEFAS fon kodu. Doluysa fiyat Yahoo'dan değil TEFAS'tan gelir.
  final String? fundCode;

  bool get isFund => fundCode != null;

  /// Haber araması için Türkçe anahtar kelime.
  final String newsQuery;

  /// Ham fiyatlardan bu varlığın fiyatı; türetilmişse hesaplanır.
  Quote? quoteFrom(Map<String, Quote> quotes) =>
      symbol != null ? quotes[symbol] : derive?.call(quotes);

  /// Grafikte kullanılacak gerçek sembol.
  String? get effectiveChartSymbol => chartSymbol ?? symbol;
}
