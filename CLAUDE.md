# market_price

Flutter/Android uygulaması: piyasa varlıkları ve Türk yatırım fonları için
güncel fiyat, grafik ve haber. Arayüz Türkçe.

## Önce oku

**Dış veri kaynakları: [`docs/veri-kaynaklari.md`](docs/veri-kaynaklari.md).**
Yeni varlık, fon ya da alan eklerken oradaki uç noktalara ve tuzaklara bak —
hepsi doğrulanmış durumda, sıfırdan keşfetme. Özellikle TEFAS'ın eski API'si
öldü ve HTML sayfaları bot korumasının arkasında; belgede çalışan uçlar ve
gövde biçimleri var.

## Yapı

| dosya | iş |
| --- | --- |
| `lib/data/asset_catalog.dart` | piyasa varlıkları (`kAssets`), fon → varlık dönüşümü |
| `lib/models/asset.dart` | varlık tanımı: sembol, türetme, grafik dayanağı, fon kodu |
| `lib/services/market_service.dart` | Yahoo Finance: fiyat ve seri |
| `lib/services/fund_service.dart` | TEFAS: fon listesi, künye, valör |
| `lib/services/news_service.dart` | Google Haberler RSS |
| `lib/services/*_store.dart` | cihazda saklanan ayarlar (sıra, izleme, odak, grafik aralığı) |
| `lib/ui/home_page.dart` | üç sekme: İzleme / Tüm Liste / Fonlar |
| `lib/ui/detail_page.dart` | grafik + haber; fonlarda grafik yerine dönem getirileri |
| `tool/make_icon.py` | launcher ikonu PNG'lerini üretir |

## Derleme

`flutter build apk --debug` çalışıyor. **`--release` bu makinede çalışmıyor** —
`/etc/hosts` `dl.google.com`'u engelliyor, sebebi ve çözümü belgede.

İkonu değiştirmek: `python3 tool/make_icon.py && dart run flutter_launcher_icons`

## Alışkanlıklar

- Değişiklikten sonra gerçek cihazda doğrula (`adb install` + `exec-out screencap`);
  ekran görüntüsüne bakmadan "oldu" deme.
- Kaydırma listelerinde `Row(crossAxisAlignment: stretch)` ve sınırsız yükseklik
  isteyen kurgulardan kaçın — bir kez tüm sekmeyi sessizce boş bıraktı.
  Yerleşim düzeltmelerini widget testiyle sabitle (`test/fund_tile_test.dart`,
  `test/focus_layout_test.dart` örnek).
- Türetilmiş TL fiyatlarında geçmişi bugünkü kurla çarpma; kur serisini de çek.
