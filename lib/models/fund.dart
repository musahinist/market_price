/// TEFAS'ta işlem gören bir yatırım fonu.
class Fund {
  Fund({
    required this.code,
    required this.title,
    required this.returns,
    this.risk,
    this.umbrella,
    this.onTefas = true,
  });

  factory Fund.fromJson(Map<String, dynamic> json) => Fund(
    code: json['code'] as String,
    title: json['title'] as String,
    returns: {
      for (final entry in (json['returns'] as Map).entries)
        entry.key as String: (entry.value as num).toDouble(),
    },
    risk: json['risk'] as int?,
    umbrella: json['umbrella'] as String?,
    onTefas: json['onTefas'] as bool? ?? true,
  );

  Map<String, dynamic> toJson() => {
    'code': code,
    'title': title,
    'returns': returns,
    'risk': risk,
    'umbrella': umbrella,
    'onTefas': onTefas,
  };

  /// Üç harfli fon kodu, ör. 'GPZ'.
  final String code;

  /// Resmî unvan, ör. 'GARANTİ PORTFÖY ÜÇÜNCÜ PARA PİYASASI FONU'.
  final String title;

  /// Dönem getirileri (%); anahtarlar [FundPeriod.key].
  final Map<String, double> returns;

  /// 1-7 arası risk değeri.
  final int? risk;

  /// Şemsiye fon türü, ör. 'Katılım Şemsiye Fonu'.
  final String? umbrella;

  /// TEFAS'ta işlem görüyor mu. Görmüyorsa yalnızca kurucunun kendi
  /// kanallarından alınabilir (ör. Garanti BBVA uygulaması).
  final bool onTefas;

  /// Klasik para piyasası fonundan farklıysa kısa etiket: 'K' ya da 'S'.
  String? get umbrellaLabel {
    final name = umbrella ?? '';
    if (name.startsWith('Katılım')) return 'K';
    if (name.startsWith('Serbest')) return 'S';
    return null;
  }

  /// Listede gösterilecek kısa ad.
  ///
  /// 'GARANTİ PORTFÖY ÜÇÜNCÜ PARA PİYASASI FONU' -> 'Garanti Portföy Üçüncü'
  ///
  /// Regex + başlık dönüşümü pahalı; satır çiziminde tekrarlanmasın diye
  /// nesne başına bir kez hesaplanıyor.
  late final String shortName = _computeShortName();

  /// Arama için sadeleştirilmiş metin: kod + ad, Türkçe harfler düzleştirilmiş.
  late final String searchText = normalizeForSearch('$code $title');

  String _computeShortName() {
    final trimmed = title.replaceAll(_suffixPattern, '').trim();
    return _titleCase(trimmed.isEmpty ? title : trimmed);
  }

  double? periodReturn(String key) => returns[key];
}

/// Fon getirilerinin gösterildiği dönemler.
enum FundPeriod {
  m1('1 ay', 'getiri1a'),
  m3('3 ay', 'getiri3a'),
  m6('6 ay', 'getiri6a'),
  ytd('Yılbaşı', 'getiriyb'),
  y1('1 yıl', 'getiri1y'),
  y3('3 yıl', 'getiri3y'),
  y5('5 yıl', 'getiri5y');

  const FundPeriod(this.label, this.key);

  final String label;
  final String key;
}

/// Aramada 'gumus' ile 'Gümüş'ün eşleşmesi için harfleri düzleştirir.
String normalizeForSearch(String value) {
  const map = {
    'İ': 'i',
    'I': 'i',
    'ı': 'i',
    'Ş': 's',
    'ş': 's',
    'Ğ': 'g',
    'ğ': 'g',
    'Ü': 'u',
    'ü': 'u',
    'Ö': 'o',
    'ö': 'o',
    'Ç': 'c',
    'ç': 'c',
  };
  final buffer = StringBuffer();
  for (final ch in value.split('')) {
    buffer.write(map[ch] ?? ch);
  }
  return buffer.toString().toLowerCase();
}

/// Unvanın sonundaki tür açıklaması; kısa adda tekrar etmesin.
final _suffixPattern = RegExp(
  r'\s+(KATILIM\s+)?PARA\s+P[İI]YASASI'
  r'(\s+(SERBEST|KATILIM|ÖZEL|\(TL\)|\(DÖVİZ\)|\(TL\)))*\s+FONU?$',
);

/// Büyük harf yazılmış unvanı okunur hale getirir.
///
/// TEFAS unvanları tamamen büyük harftir; kısaltmalar olduğu gibi kalır.
String _titleCase(String value) =>
    value.split(' ').map(_titleCaseWord).join(' ');

const _keepAsIs = {'TL', '(TL)', 'A.Ş.', 'BIST', 'ETF', 'BES'};

String _titleCaseWord(String word) {
  if (word.isEmpty || _keepAsIs.contains(word)) return word;

  // Türkçe'de İ -> i; gerisini standart küçültme halleder ki 'TRIVE' gibi
  // yabancı adlar 'Trıve' olmasın.
  final lower = word.replaceAll('İ', 'i').toLowerCase();
  final first = lower[0] == 'i' ? 'İ' : lower[0].toUpperCase();
  return first + lower.substring(1);
}
