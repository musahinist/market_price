import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:market_price/data/asset_catalog.dart';
import 'package:market_price/models/fund.dart';
import 'package:market_price/services/fund_cache.dart';
import 'package:market_price/services/fund_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('TEFAS unvanı okunur kısa ada dönüşür', () {
    final fund = Fund(
      code: 'GPZ',
      title: 'GARANTİ PORTFÖY ÜÇÜNCÜ PARA PİYASASI FONU',
      returns: {},
    );
    expect(fund.shortName, 'Garanti Portföy Üçüncü');
  });

  test('unvan kuyruğu ve kısaltmalar doğru işlenir', () {
    String short(String title) =>
        Fund(code: 'X', title: title, returns: const {}).shortName;

    expect(short('ATA PORTFÖY PARA PİYASASI (TL) FONU'), 'Ata Portföy');
    // 'FON' (U'suz) ve (TL) kuyruğu da düşer.
    expect(short('BV PORTFÖY PARA PİYASASI (TL) FON'), 'Bv Portföy');
    // Yabancı ad 'Trıve' olmamalı.
    expect(short('TRIVE PORTFÖY PARA PİYASASI (TL) FONU'), 'Trive Portföy');
    expect(short('İŞ PORTFÖY PARA PİYASASI FONU'), 'İş Portföy');
    expect(
      short('RE-PIE PORTFÖY BİRİNCİ PARA PİYASASI (TL) FONU'),
      'Re-pie Portföy Birinci',
    );
    // Tanınan kısaltma olduğu gibi kalır.
    expect(short('X PORTFÖY TL KATILIM PARA PİYASASI FONU'), 'X Portföy TL');
  });

  test('fon listesi aylık getiriye göre sıralanır', () async {
    final client = MockClient((request) async {
      expect(request.url.path, endsWith('fonGetiriBazliBilgiGetir'));
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      // Para piyasası fonları üç şemsiyeye dağıldığı için tür süzgeci yok.
      expect(body['sfonTurKod'], isNull);
      // TEFAS dışı fonlar da gelsin (ör. GTL).
      expect(body['islem'], isNull);
      expect(body['donemGetiri1a'], '1');

      return http.Response(
        jsonEncode({
          'errorMessage': null,
          'resultList': [
            {
              'fonKodu': 'AAA',
              'fonUnvan': 'A PORTFÖY PARA PİYASASI (TL) FONU',
              'getiri1a': 3.1,
              'getiri1y': 44.0,
              'riskDegeri': 1,
            },
            {
              'fonKodu': 'BBB',
              'fonUnvan': 'B PORTFÖY PARA PİYASASI (TL) FONU',
              'getiri1a': '4,4',
              'riskDegeri': '2',
            },
            {
              'fonKodu': 'CCC',
              'fonUnvan': 'C PORTFÖY PARA PİYASASI (TL) FONU',
              'riskDegeri': 1,
            },
            {
              'fonKodu': 'GPN',
              'fonUnvan': 'GARANTİ PORTFÖY PARA PİYASASI KATILIM (TL) FONU',
              'fonTurAciklama': 'Katılım Şemsiye Fonu',
              'getiri1a': 3.3,
            },
            {
              'fonKodu': 'ZZZ',
              'fonUnvan': 'Z PORTFÖY HİSSE SENEDİ FONU',
              'getiri1a': 9.9,
            },
            {
              'fonKodu': 'GTL',
              'fonUnvan': 'GARANTİ PORTFÖY BİRİNCİ PARA PİYASASI (TL) FONU',
              'fonTurAciklama': 'Para Piyasası Şemsiye Fonu',
              'tefasDurum': false,
              'getiri1a': 3.2,
            },
          ],
        }),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });

    final funds = await FundService(client: client).fetchMoneyMarketFunds();

    // Hisse senedi fonu elenir; katılım şemsiyesindeki para piyasası fonu kalır.
    expect(funds.map((f) => f.code), ['BBB', 'GPN', 'GTL', 'AAA', 'CCC']);
    // TEFAS dışı fon listede kalır ama işaretlenir.
    expect(funds.firstWhere((f) => f.code == 'GTL').onTefas, isFalse);
    expect(funds.firstWhere((f) => f.code == 'AAA').onTefas, isTrue);
    expect(funds.firstWhere((f) => f.code == 'GPN').umbrellaLabel, 'K');
    expect(funds.firstWhere((f) => f.code == 'AAA').umbrellaLabel, isNull);
    expect(funds.first.periodReturn(FundPeriod.m1.key), 4.4);
    // TEFAS sayıları metin olarak da döndürebiliyor.
    expect(funds.first.risk, 2);
    // Getirisi olmayan fon sona düşer, boş harita ile gelir.
    expect(funds.last.periodReturn(FundPeriod.m1.key), isNull);
  });

  test('fon künyesi fiyat ve günlük getiriyi verir', () async {
    final client = MockClient((request) async {
      expect(request.url.path, endsWith('fonBilgiGetir'));
      return http.Response(
        jsonEncode({
          'resultList': [
            {
              'fonKodu': 'GPZ',
              'fonUnvan': 'GARANTİ PORTFÖY ÜÇÜNCÜ PARA PİYASASI FONU',
              'sonFiyat': 3.562621,
              'gunlukGetiri': '0.1004',
              'fonKategori': 'Para Piyasası Fonu',
              'portBuyukluk': 1922769965.19,
              'yatirimciSayi': '4447',
              'kategoriDerece': 72,
              'kategoriFonSay': 87,
            },
          ],
        }),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });

    final info = await FundService(client: client).fetchFundInfo('GPZ');

    expect(info.quote.price, 3.562621);
    expect(info.quote.changePercent, 0.1004);
    expect(info.quote.currency, 'TRY');
    expect(info.investors, 4447);
    expect(info.categoryRank, 72);
  });

  test('TEFAS hata mesajı istisnaya dönüşür', () async {
    final client = MockClient(
      (request) async => http.Response(
        jsonEncode({'errorMessage': 'Sistem Hatası!!', 'resultList': null}),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      ),
    );

    expect(
      () => FundService(client: client).fetchMoneyMarketFunds(),
      throwsA(isA<Exception>()),
    );
  });

  test('fon varlığa çevrilince kimliği fon: önekiyle ayrılır', () {
    final fund = Fund(
      code: 'GPZ',
      title: 'GARANTİ PORTFÖY ÜÇÜNCÜ PARA PİYASASI FONU',
      returns: {},
    );
    final asset = fundAsset(fund);

    expect(asset.id, 'fon:GPZ');
    expect(asset.isFund, isTrue);
    expect(asset.fundCode, 'GPZ');
    expect(asset.unit, '₺');
    // Fonun Yahoo sembolü yok; fiyat isteği listesine girmemeli.
    expect(symbolsFor([asset]), isEmpty);
  });

  test('arama kodu ve adı Türkçe harflere takılmadan bulur', () {
    final fund = Fund(
      code: 'GPZ',
      title: 'GARANTİ PORTFÖY ÜÇÜNCÜ PARA PİYASASI FONU',
      returns: {},
    );

    expect(fund.searchText.contains(normalizeForSearch('gpz')), isTrue);
    expect(fund.searchText.contains(normalizeForSearch('garanti')), isTrue);
    // 'ü' -> 'u', 'İ' -> 'i' düzleştirmesi.
    expect(fund.searchText.contains(normalizeForSearch('ucuncu')), isTrue);
    expect(fund.searchText.contains(normalizeForSearch('GARANTI')), isTrue);
    expect(fund.searchText.contains(normalizeForSearch('pusula')), isFalse);
  });

  test('valör tarihi yyyyMMdd yanıtından okunur', () async {
    final client = MockClient((request) async {
      expect(request.url.path, endsWith('fonAlSatEkranValorHesapla'));
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      expect(body['fonKodu'], 'GPZ');
      expect(body['paraBirimi'], 'TL');
      return http.Response(
        jsonEncode({
          'result': body['islemTip'] == 'A' ? '20260914' : '20260915',
        }),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });

    final service = FundService(client: client);
    expect(
      await service.fetchSettlementDate('GPZ', buy: true),
      DateTime(2026, 9, 14),
    );
    expect(
      await service.fetchSettlementDate('GPZ', buy: false),
      DateTime(2026, 9, 15),
    );
  });

  test('boş valör yanıtı null döner', () async {
    final client = MockClient(
      (request) async => http.Response(
        jsonEncode({'result': null}),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      ),
    );
    expect(
      await FundService(client: client).fetchSettlementDate('GPZ', buy: true),
      isNull,
    );
  });

  test('fon önbelleğe yazılıp aynı gün geri okunur', () async {
    SharedPreferences.setMockInitialValues({});
    final cache = FundCache();

    expect(await cache.load(), isNull);

    await cache.save([
      Fund(
        code: 'GTL',
        title: 'GARANTİ PORTFÖY BİRİNCİ PARA PİYASASI (TL) FONU',
        returns: {'getiri1a': 3.2},
        risk: 1,
        umbrella: 'Para Piyasası Şemsiye Fonu',
        onTefas: false,
      ),
    ]);

    final loaded = await cache.load();
    expect(loaded, hasLength(1));
    expect(loaded!.first.code, 'GTL');
    expect(loaded.first.onTefas, isFalse);
    expect(loaded.first.periodReturn('getiri1a'), 3.2);
    expect(loaded.first.shortName, 'Garanti Portföy Birinci');
  });

  test('dünden kalan önbellek kullanılmaz', () async {
    SharedPreferences.setMockInitialValues({
      'flutter.fund_cache_v1': jsonEncode({
        'date': '2020-1-1',
        'funds': [
          {'code': 'X', 'title': 'X PARA PİYASASI FONU', 'returns': {}},
        ],
      }),
    });

    expect(await FundCache().load(), isNull);
  });
}
