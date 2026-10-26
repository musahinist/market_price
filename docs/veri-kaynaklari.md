# Veri kaynakları

Uygulamanın kullandığı üç dış kaynak, tam istek biçimleriyle. **Yeni varlık ya
da fon eklerken önce buraya bak** — uçların hepsi doğrulandı, tekrar keşfetmeye
gerek yok.

Hiçbiri API anahtarı istemiyor.

---

## 1. Yahoo Finance — piyasa fiyatları ve grafikler

Kod: `lib/services/market_service.dart`

### Anlık fiyat

```
GET https://query1.finance.yahoo.com/v8/finance/chart/{sembol}?interval=1d&range=1d
```

Tarayıcı `User-Agent` başlığı şart, yoksa boş dönebiliyor. Yanıt
`chart.result[0].meta` içinde:

| alan | kullanım |
| --- | --- |
| `regularMarketPrice` | fiyat |
| `regularMarketChangePercent` | günlük değişim |
| `chartPreviousClose` | önceki kapanış (aralık değişimi bundan hesaplanır) |
| `regularMarketDayLow` / `High` | gün aralığı |
| `fiftyTwoWeekLow` / `High` | 52 hafta aralığı |
| `currency`, `regularMarketTime` | birim, zaman damgası |

### Grafik serisi

Aynı uç, `interval` ve `range` değişir (bkz. `ChartRange`):

| etiket | range | interval |
| --- | --- | --- |
| 1G | `1d` | `5m` |
| 1H | `5d` | `15m` |
| 1A | `1mo` | `1d` |
| 6A | `6mo` | `1d` |
| 1Y | `1y` | `1d` |
| 5Y | `5y` | `1wk` |

`timestamp[]` ve `indicators.quote[0].close[]` eşleştirilir; kapalı seanslarda
`close` **null gelir, atlanmalı**.

`meta.chartPreviousClose` pencereden **bir önceki** kapanıştır — dönem
değişimini bundan hesaplamak doğrudur, denetlendi. (Ör. Brent 6 aylıkta 91,98
= pencere başlangıcından bir gün önceki kapanış; serinin ilk noktasıyla arasındaki
fark gerçek bir günlük sıçramadan geliyor, hata değil.)

**Referans kapanış tuzakları** (uygulamada `fetchSeries` düzeltiyor):

- **1H (`5d`/`15m`)**: `chartPreviousClose` kripto ve BIST'te pencereden önceki
  değil, pencerenin *ilk gününün* kapanışı. Referans serinin ilk noktası alınıyor.
- **1G**: kriptoda `chartPreviousClose` UTC gece yarısı fiyatı, ama
  `regularMarketChangePercent` başka referansa göre; liste ile detay farklı yüzde
  gösteriyordu. 1G referansı `fiyat / (1 + değişim%)`.

### Vadeli işlemler: kontrat devri

`BZ=F` gibi sürekli semboller **geriye dönük düzeltilmemiş**. Geçmiş, o gün
vadesi en yakın kontrattan; anlık fiyat ise yeni kontrattan. Devir günü seri
sıçrıyor. Ör. Ekim 2026: `BZ=F` günlük serisinde 23 Ekim = 116,72 (Aralık
kontratı `BZZ26.NYM`), anlık fiyatın önceki kapanışı 111,70 (Ocak kontratı
`BZF27.NYM`). Grafik son gün sahte −%5 düşüş, 1A değişimi +%6 yerine gerçekte
+%18. Doğal gazda fark %15'e çıkabiliyor.

Çözüm: kontrat sembolü `{kök}{ay kodu}{yy}.{borsa}` (ay kodları `FGHJKMNQUVXZ`;
`BZ CL NG PL PA` → `.NYM`, `GC SI HG` → `.CMX`). Önümüzdeki 6 ayın kontratları
çekilip fiyatı sürekli sembolünkiyle eşleşen (fark < %0,1) seçilir, grafik o
kontratın kendi serisinden çizilir. Kontratların 5 yıllık geçmişi de var; yoksa
eksik baş kısım sürekli seriden oranlanıp eklenir (`PriceSeries.extendedWith`).
**Brent istisnası — vadesi en yakın kontrat.** Yahoo `BZ=F`'yi hacme göre
vadeden ~bir hafta önce sonrakine geçiriyor: 26 Ekim 2026'da `BZ=F` = 110 $
(Ocak) iken Aralık kontratı 30 Ekim vadesine kadar 115 $'dan işlem görüyordu ve
kullanıcının baktığı kaynaklar Brent'i 115 $ gösteriyordu. Bu yüzden `BZ` kökünde
hem anlık fiyat hem grafik, adaylardan **son işlem zamanı en tazesine 2 günden
yakın olan ilk** kontrattan çekiliyor (`nearestLiveContract`). Vadesi dolan
kontratın zamanı geride kalınca kendiliğinden bir sonrakine geçer. Diğer
köklerde (`CL`, `GC`, `NG`...) Yahoo'nun seçimi alışılmış kontratla aynı; altında
seyrek işlem gören Kasım (`GCX26`) yerine Aralık gibi. Onlarda anlık fiyat
`=F` sembolünden geliyor.

### Sembol notları

- Vadeli: `BZ=F` Brent, `CL=F` WTI, `NG=F` doğal gaz, `GC=F` altın, `SI=F` gümüş,
  `PL=F` platin, `PA=F` paladyum, `HG=F` bakır
- Döviz: `TRY=X` = **USD/TRY**, `EURTRY=X`, `GBPTRY=X`, `CHFTRY=X`, `EURUSD=X`,
  `USDJPY=X`; dolar endeksi `DX-Y.NYB`; ABD 10Y tahvil `^TNX`
- Kripto: `BTC-USD`, `PAXG-USD`, `USDT-USD`, `ETH-USD`, `SOL-USD`, `XRP-USD`, `BNB-USD`, `DOGE-USD`
- Endeks: `^GSPC`, `^IXIC`, `^DJI`, `^GDAXI`, `^FTSE`, `^N225`, `^VIX`,
  `XU100.IS`, `XU030.IS`, `XBANK.IS`
- **Yok**: spot `XAUUSD=X` / `XAGUSD=X` çalışmıyor, `BTC-TRY` ve `USDT-TRY` yok (USDT/TL `USDT-USD × TRY=X` ile türetiliyor). Spot altın
  için `PAXG-USD` (1 PAXG = 1 ons altın) vekil olarak kullanılıyor.

### Yeni piyasa varlığı ekleme

`lib/data/asset_catalog.dart` içindeki `kAssets` listesine bir `Asset` ekle.
Doğrudan sembolü varsa `symbol` yeter. Türetilmişse (ör. gram altın):

- `derive`: canlı fiyatı hesaplar
- `deps`: `derive`'ın ihtiyaç duyduğu semboller (fiyat isteği listesi buradan çıkar)
- `chartSymbol` + `chartFxSymbol` + `chartDivisor`: grafik dayanağı ve TL'ye çevrim

**Uzun vadeli çevrimde tuzak:** bir dolar serisini *bugünkü* kurla çarpmak
geçmişi bozar. `PriceSeries.convertedWith` kur serisini de çekip her noktaya o
tarihteki kuru uygular. Aynı sebeple türetilmiş varlıklarda 52 haftalık aralık
gösterilmiyor (`Quote.scaledBy(keepWeekRange: false)`).

---

## 2. TEFAS — Türk yatırım fonları

Kod: `lib/services/fund_service.dart`

### Önce bilinmesi gerekenler

- **Eski API öldü.** `BindHistoryInfo`, `BindComparisonFundReturns` gibi uçlar
  404 / "Method not found or disabled" dönüyor. İnternetteki eski örnekler ve
  `tefas-crawler` benzeri kütüphaneler çalışmaz.
- **HTML sayfaları F5/Shape (TSPD) bot korumasının arkasında.** `curl` ile
  sayfa çekmeye çalışırsan 5 KB'lık JS challenge gelir. Sayfa kazımaya kalkma.
- **`/api/...` JSON uçlarında koruma yok**, düz HTTP istemcisiyle çalışıyor.
  Uygulamanın telefondan çağırdığı uçlar bunlar.

### Uçları nasıl keşfettim (gerekirse tekrarla)

Tarayıcıda tefas.gov.tr'yi aç, sonra `XMLHttpRequest.prototype.send`'i yamala
ve ilgili UI eylemini tetikle. **`window.fetch`'i yamalamak yetmez** — site
axios kullanıyor, o da XHR üzerinden gidiyor. Sayfa ilk yüklenirken atılan
istekler kaçar; bir filtreyi değiştirip yeniden sorgu tetiklemek gerekiyor
(sonuçlar redux'ta önbelleklendiği için aynı sorgu tekrar atılmaz).

### Fon listesi + dönem getirileri (tek istek)

```
POST https://www.tefas.gov.tr/api/funds/fonGetiriBazliBilgiGetir
Content-Type: application/json
```
```json
{
  "dil": "TR", "fonTipi": "YAT",
  "kurucuKodu": null, "sfonTurKod": null, "fonTurAciklama": null,
  "islem": null, "fonTurKod": null, "fonGrubu": null,
  "donemGetiri1a": "1", "donemGetiri3a": "1", "donemGetiri6a": "1",
  "donemGetiri1y": "1", "donemGetiriyb": "1", "donemGetiri3y": "1",
  "donemGetiri5y": "1",
  "basTarih": null, "bitTarih": null, "calismaTipi": 2, "getiriOrani": "1"
}
```

`resultList[]`: `fonKodu`, `fonUnvan`, `fonTurAciklama` (şemsiye türü),
`tefasDurum`, `riskDegeri`, `getiri1a/3a/6a/yb/1y/3y/5y`.

Parametre tuzakları:

- **`islem: 1`** yalnızca TEFAS'ta işlem görenleri verir. `null` yapmazsan
  Garanti'nin GTL, GAL, GNP gibi en büyük fonları listeye girmez (bunlar
  yalnızca kurucunun kendi kanallarından satılıyor, `tefasDurum: false`).
- **`sfonTurKod`** şemsiye türü kodu (para piyasası = `107`). Ama para piyasası
  fonları üç şemsiyeye dağılmış (para piyasası / katılım / serbest), tek türle
  süzmek üçte birini kaçırır. Bu yüzden `null` gönderip **ada göre** süzüyoruz
  (`normalizeForSearch(unvan).contains('para piyasasi')`).
- Yanıt **~669 KB ve gzip yok**. Fonlar günde bir fiyatlandığı için
  `FundCache` günlük önbellekliyor; aşağı çekerek yenileme önbelleği atlıyor.

### Fon künyesi ve son fiyat

```
POST /api/funds/fonBilgiGetir      {"fonKodu": "GPZ", "dil": "TR"}
```

`sonFiyat`, `gunlukGetiri`, `portBuyukluk`, `yatirimciSayi`, `fonKategori`,
`kategoriDerece`, `kategoriFonSay`, `payAdet`, `pazarPayi`.

Toplu fiyat veren uç **yok** — bu yüzden yalnızca izleme listesindeki fonlar
için, fon başına bir istek atılıyor.

### Valör (takas tarihi)

```
POST /api/funds/fonAlSatEkranValorHesapla
{"islemTip": "A", "fonKodu": "GPZ", "paraBirimi": "TL"}     // A alış, S satış
→ {"result": "20260914"}
```

Bugün verilecek emrin takas tarihini, TEFAS'ın kendi tatil ve işlem saati
hesabıyla döndürür. TEFAS dışı fonlarda hata verir ("güncel kısıt bilgisine
ulaşılamadı") — beklenen davranış, o fonlar platformda alınıp satılamıyor.

### Tüm fon kodları

```
POST /api/statistics/tefas/getFplFonList   {}
```

1053 fon: `fonKod`, `unvan`, `kurucuKod`, `kurucuAd`, `durum`. Kurucu koduna
göre filtrelemek için kullanışlı (ör. `GPY` = Garanti Portföy Yönetimi —
**bu bir fon kodu değil, kurucu kodu**).

### Genel tuzaklar

- Sayısal alanlar bazen **metin** gelir (`riskDegeri: "2"`, `getiri1a: "4,4"`).
  `_num()` hem sayıyı hem virgüllü metni çözüyor.
- Unvanlar tamamen büyük harf. Türkçe küçültmede `I → ı` yabancı adları bozuyor
  (`TRIVE → Trıve`); `Fund._titleCaseWord` önce `İ → i` çevirip standart
  küçültme yapıyor.

### Çözülemeyenler

- `fonFiyatBilgiGetir` ve `fonGnlBlgSiraliGetir` (fonun günlük fiyat geçmişi)
  doğru gövdeyi bulamadım. `fonGnlBlgSiraliGetir` tarihleri `yyyyMMdd`
  bekliyor ve aralığı 1 ayla sınırlıyor, ama doğru parametrelerle bile
  "Index 0 out of bounds" veriyor. **Bu yüzden fonlarda çizgi grafik yok**,
  yerine dönem getirileri gösteriliyor. Detay sayfası sunucuda render edildiği
  için tarayıcıdan da yakalanamıyor.

### Yeni fon türü ekleme

`FundService._moneyMarketName` süzgecini genişlet ya da `sfonTurKod` ile başka
bir şemsiyeyi çek. `Fund` → `Asset` dönüşümü `fundAsset()` içinde; kimlikler
`fon:KOD` önekiyle piyasa varlıklarından ayrılıyor, böylece izleme listesi,
sıralama ve odak kartları aynı altyapıyı paylaşıyor.

---

## 3. Google Haberler RSS — Türkçe haberler

Kod: `lib/services/news_service.dart`

```
GET https://news.google.com/rss/search?q={sorgu}&hl=tr&gl=TR&ceid=TR:tr
```

Her varlığın `newsQuery` alanı Türkçe anahtar kelime tutuyor. Yahoo'nun kendi
haber ucu (`/v1/finance/search`) denendi — sembol bazlı sonuçlar alakasız
çıkıyordu, Google RSS çok daha isabetli (fonlarda KAP bildirimleri bile geliyor).

Ayrıştırma notları: başlık sonuna `" - Kaynak"` ekleniyor, temizleniyor;
sayısal HTML varlıkları (`&#8217;`) çözülüyor; `&amp;` **en sonda** çevrilmeli
yoksa çift çözme olur.

---

## Derleme ortamı

`flutter build apk --release --split-per-abi` çalışıyor (Ekim 2026). Telefona
`build/app/outputs/flutter-apk/app-arm64-v8a-release.apk` kurulur.

Önceden `/etc/hosts` `dl.google.com`'u `0.0.0.0`'a yönlendiriyordu (reklam
engelleyici listesi) ve release derlemesi bu yüzden başarısızdı. Belirti:
`Connect to dl.google.com:443 ... Connection refused`, ardından "Repository
Google is disabled". Tekrar görülürse sebep odur, sandbox değil; hosts satırını
yorum satırı yapmak kullanıcının kararı (sudo).
