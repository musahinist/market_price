import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/fund.dart';
import '../models/quote.dart';
import 'market_service.dart';

/// TEFAS'ın açık uçlarından fon verisi çeker.
///
/// Fonlar günde bir fiyatlanır; anlık veri yoktur.
class FundService {
  FundService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static const _base = 'https://www.tefas.gov.tr/api/funds';

  /// Para piyasası fonlarını ayıklayan ad kalıbı.
  ///
  /// Bu fonlar üç ayrı şemsiye altında dağılmış durumda (para piyasası,
  /// katılım, serbest); TEFAS tek bir türle süzmeye izin vermediği için
  /// listeyi ada göre ayıklıyoruz.
  static final _moneyMarketName = RegExp(
    'para p[iİ]yasasi',
    caseSensitive: false,
  );

  static const _headers = {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
    'Origin': 'https://www.tefas.gov.tr',
    'Referer': 'https://www.tefas.gov.tr/tr/fon-getirileri',
    'User-Agent':
        'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 '
        '(KHTML, like Gecko) Chrome/124.0 Safari/537.36',
  };

  /// Para piyasası fonlarını dönem getirileriyle birlikte tek istekte çeker.
  Future<List<Fund>> fetchMoneyMarketFunds() async {
    final rows = await _post('fonGetiriBazliBilgiGetir', {
      'dil': 'TR',
      'fonTipi': 'YAT',
      'kurucuKodu': null,
      'sfonTurKod': null,
      'fonTurAciklama': null,
      // null: TEFAS'ta işlem görmeyenler de gelsin (ör. GTL).
      'islem': null,
      'fonTurKod': null,
      'fonGrubu': null,
      for (final period in FundPeriod.values)
        'donem${_capitalize(period.key)}': '1',
      'basTarih': null,
      'bitTarih': null,
      'calismaTipi': 2,
      'getiriOrani': '1',
    });

    final funds = <Fund>[];
    for (final row in rows) {
      final code = row['fonKodu'] as String?;
      final title = row['fonUnvan'] as String?;
      if (code == null || title == null) continue;
      if (!normalizeForSearch(title).contains(_moneyMarketName)) continue;

      funds.add(
        Fund(
          code: code,
          title: title,
          risk: _num(row['riskDegeri'])?.toInt(),
          umbrella: row['fonTurAciklama'] as String?,
          onTefas: row['tefasDurum'] as bool? ?? true,
          returns: {
            for (final period in FundPeriod.values)
              if (_num(row[period.key]) != null)
                period.key: _num(row[period.key])!,
          },
        ),
      );
    }

    // Çok kazandıran önce: son bir aylık getiriye göre.
    funds.sort((a, b) {
      final x = a.periodReturn(FundPeriod.m1.key);
      final y = b.periodReturn(FundPeriod.m1.key);
      if (x == null) return 1;
      if (y == null) return -1;
      return y.compareTo(x);
    });

    return funds;
  }

  /// Bir fonun son fiyatı ve günlük getirisi.
  Future<FundInfo> fetchFundInfo(String code) async {
    final rows = await _post('fonBilgiGetir', {'fonKodu': code, 'dil': 'TR'});
    if (rows.isEmpty) throw MarketException('$code: fon bulunamadı.');

    final row = rows.first;
    final price = _num(row['sonFiyat']);
    if (price == null) throw MarketException('$code: fiyat yok.');

    double? number(String key) => _num(row[key]);

    return FundInfo(
      code: code,
      title: (row['fonUnvan'] as String?) ?? code,
      category: row['fonKategori'] as String?,
      quote: Quote(
        price: price,
        changePercent: number('gunlukGetiri') ?? 0,
        currency: 'TRY',
        time: DateTime.now(),
      ),
      portfolioSize: number('portBuyukluk'),
      investors: number('yatirimciSayi')?.toInt(),
      categoryRank: number('kategoriDerece')?.toInt(),
      categoryCount: number('kategoriFonSay')?.toInt(),
    );
  }

  /// Bugün verilecek emrin valör (takas) tarihi.
  ///
  /// TEFAS tatilleri ve fonun işlem saatini hesaba katarak döndürür.
  Future<DateTime?> fetchSettlementDate(
    String code, {
    required bool buy,
  }) async {
    final value = await _postValue('fonAlSatEkranValorHesapla', {
      'islemTip': buy ? 'A' : 'S',
      'fonKodu': code,
      'paraBirimi': 'TL',
    });
    if (value == null || value.length != 8) return null;

    return DateTime.tryParse(
      '${value.substring(0, 4)}-${value.substring(4, 6)}-${value.substring(6)}',
    );
  }

  Future<String?> _postValue(String path, Map<String, Object?> body) async {
    final json = await _send(path, body);
    return json['result'] as String?;
  }

  Future<List<Map<String, dynamic>>> _post(
    String path,
    Map<String, Object?> body,
  ) async {
    final json = await _send(path, body);
    return ((json['resultList'] as List?) ?? const [])
        .cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> _send(
    String path,
    Map<String, Object?> body,
  ) async {
    final res = await _client
        .post(
          Uri.parse('$_base/$path'),
          headers: _headers,
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 20));

    if (res.statusCode != 200) {
      throw MarketException('Fon verisi alınamadı (HTTP ${res.statusCode}).');
    }

    final json = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    final error = json['errorMessage'] as String?;
    if (error != null) throw MarketException('Fon verisi alınamadı: $error');

    return json;
  }

  void dispose() => _client.close();
}

/// Bir fonun anlık künyesi.
class FundInfo {
  const FundInfo({
    required this.code,
    required this.title,
    required this.quote,
    this.category,
    this.portfolioSize,
    this.investors,
    this.categoryRank,
    this.categoryCount,
  });

  final String code;
  final String title;
  final Quote quote;
  final String? category;
  final double? portfolioSize;
  final int? investors;
  final int? categoryRank;
  final int? categoryCount;
}

/// TEFAS bazı sayısal alanları metin olarak döndürüyor (ör. riskDegeri: "2").
double? _num(Object? value) => switch (value) {
  num() => value.toDouble(),
  String() => double.tryParse(value.replaceAll(',', '.')),
  _ => null,
};

String _capitalize(String value) => value[0].toUpperCase() + value.substring(1);
