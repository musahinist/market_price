import '../models/asset.dart';
import '../models/fund.dart';
import '../models/quote.dart';

/// Bir troy ons kaç gram.
const double _gramPerOunce = 31.1034768;

/// Gram fiyatı üreten türetici: ons fiyatı (USD) * USD/TRY / 31.1
Quote? Function(Map<String, Quote>) _gramTry(String ounceSymbol) {
  return (quotes) {
    final ounce = quotes[ounceSymbol];
    final usdTry = quotes['TRY=X'];
    if (ounce == null || usdTry == null) return null;
    return ounce.scaledBy(
      usdTry.price / _gramPerOunce,
      changePercent: ounce.changePercent + usdTry.changePercent,
      currency: 'TRY',
      keepWeekRange: false,
    );
  };
}

/// USD fiyatını TL'ye çeviren türetici.
Quote? Function(Map<String, Quote>) _inTry(String usdSymbol) {
  return (quotes) {
    final base = quotes[usdSymbol];
    final usdTry = quotes['TRY=X'];
    if (base == null || usdTry == null) return null;
    return base.scaledBy(
      usdTry.price,
      changePercent: base.changePercent + usdTry.changePercent,
      currency: 'TRY',
      keepWeekRange: false,
    );
  };
}

/// Ekranda gösterilecek varlıklar, sırasıyla.
final List<Asset> kAssets = [
  // ------------------------------ Emtia & metal ------------------------------
  const Asset(
    id: 'brent',
    name: 'Brent Petrol',
    icon: '🛢️',
    group: AssetGroup.emtia,
    symbol: 'BZ=F',
    unit: '\$',
    newsQuery: 'brent petrol',
  ),
  const Asset(
    id: 'wti',
    name: 'Ham Petrol (WTI)',
    icon: '🛢️',
    group: AssetGroup.emtia,
    symbol: 'CL=F',
    unit: '\$',
    newsQuery: 'ham petrol wti',
  ),
  const Asset(
    id: 'natgas',
    name: 'Doğal Gaz',
    icon: '🔥',
    group: AssetGroup.emtia,
    symbol: 'NG=F',
    unit: '\$',
    decimals: 3,
    newsQuery: 'doğal gaz fiyatı',
  ),
  const Asset(
    id: 'gold',
    name: 'Altın (ons)',
    icon: '🥇',
    group: AssetGroup.emtia,
    symbol: 'GC=F',
    unit: '\$',
    newsQuery: 'ons altın',
  ),
  Asset(
    id: 'gold_gram',
    name: 'Gram Altın',
    icon: '🥇',
    group: AssetGroup.emtia,
    unit: '₺',
    derive: _gramTry('PAXG-USD'),
    deps: const ['PAXG-USD', 'TRY=X'],
    chartSymbol: 'PAXG-USD',
    chartFxSymbol: 'TRY=X',
    chartDivisor: _gramPerOunce,
    newsQuery: 'gram altın',
  ),
  const Asset(
    id: 'silver',
    name: 'Gümüş (ons)',
    icon: '🥈',
    group: AssetGroup.emtia,
    symbol: 'SI=F',
    unit: '\$',
    newsQuery: 'ons gümüş',
  ),
  Asset(
    id: 'silver_gram',
    name: 'Gram Gümüş',
    icon: '🥈',
    group: AssetGroup.emtia,
    unit: '₺',
    derive: _gramTry('SI=F'),
    deps: const ['SI=F', 'TRY=X'],
    chartSymbol: 'SI=F',
    chartFxSymbol: 'TRY=X',
    chartDivisor: _gramPerOunce,
    newsQuery: 'gram gümüş',
  ),
  const Asset(
    id: 'platinum',
    name: 'Platin (ons)',
    icon: '⚪',
    group: AssetGroup.emtia,
    symbol: 'PL=F',
    unit: '\$',
    newsQuery: 'platin fiyatı',
  ),
  const Asset(
    id: 'palladium',
    name: 'Paladyum (ons)',
    icon: '⚙️',
    group: AssetGroup.emtia,
    symbol: 'PA=F',
    unit: '\$',
    newsQuery: 'paladyum fiyatı',
  ),
  const Asset(
    id: 'copper',
    name: 'Bakır (libre)',
    icon: '🟠',
    group: AssetGroup.emtia,
    symbol: 'HG=F',
    unit: '\$',
    decimals: 3,
    newsQuery: 'bakır fiyatı',
  ),

  // --------------------------------- Döviz ----------------------------------
  const Asset(
    id: 'usdtry',
    name: 'Dolar / TL',
    icon: '💵',
    group: AssetGroup.doviz,
    symbol: 'TRY=X',
    unit: '₺',
    decimals: 4,
    newsQuery: 'dolar kuru',
  ),
  const Asset(
    id: 'eurtry',
    name: 'Euro / TL',
    icon: '💶',
    group: AssetGroup.doviz,
    symbol: 'EURTRY=X',
    unit: '₺',
    decimals: 4,
    newsQuery: 'euro kuru',
  ),
  const Asset(
    id: 'gbptry',
    name: 'Sterlin / TL',
    icon: '💷',
    group: AssetGroup.doviz,
    symbol: 'GBPTRY=X',
    unit: '₺',
    decimals: 4,
    newsQuery: 'sterlin kuru',
  ),
  const Asset(
    id: 'chftry',
    name: 'İsviçre Frangı / TL',
    icon: '🇨🇭',
    group: AssetGroup.doviz,
    symbol: 'CHFTRY=X',
    unit: '₺',
    decimals: 4,
    newsQuery: 'isviçre frangı kuru',
  ),
  const Asset(
    id: 'eurusd',
    name: 'Euro / Dolar',
    icon: '💱',
    group: AssetGroup.doviz,
    symbol: 'EURUSD=X',
    unit: '\$',
    decimals: 4,
    newsQuery: 'euro dolar paritesi',
  ),
  const Asset(
    id: 'usdjpy',
    name: 'Dolar / Yen',
    icon: '💴',
    group: AssetGroup.doviz,
    symbol: 'USDJPY=X',
    unit: '¥',
    newsQuery: 'japon yeni kuru',
  ),
  const Asset(
    id: 'dxy',
    name: 'Dolar Endeksi (DXY)',
    icon: '🏛️',
    group: AssetGroup.doviz,
    symbol: 'DX-Y.NYB',
    unit: '',
    newsQuery: 'dolar endeksi',
  ),
  const Asset(
    id: 'us10y',
    name: 'ABD 10 Yıllık Tahvil',
    icon: '📜',
    group: AssetGroup.doviz,
    symbol: '^TNX',
    unit: '',
    decimals: 3,
    suffix: '%',
    newsQuery: 'abd 10 yıllık tahvil faizi',
  ),

  // -------------------------------- Kripto ----------------------------------
  const Asset(
    id: 'btcusd',
    name: 'Bitcoin',
    icon: '₿',
    group: AssetGroup.kripto,
    symbol: 'BTC-USD',
    unit: '\$',
    newsQuery: 'bitcoin',
  ),
  Asset(
    id: 'btctry',
    name: 'Bitcoin / TL',
    icon: '₿',
    group: AssetGroup.kripto,
    unit: '₺',
    derive: _inTry('BTC-USD'),
    deps: const ['BTC-USD', 'TRY=X'],
    chartSymbol: 'BTC-USD',
    chartFxSymbol: 'TRY=X',
    newsQuery: 'bitcoin',
  ),
  const Asset(
    id: 'ethusd',
    name: 'Ethereum',
    icon: 'Ξ',
    group: AssetGroup.kripto,
    symbol: 'ETH-USD',
    unit: '\$',
    newsQuery: 'ethereum',
  ),
  const Asset(
    id: 'solusd',
    name: 'Solana',
    icon: '◎',
    group: AssetGroup.kripto,
    symbol: 'SOL-USD',
    unit: '\$',
    newsQuery: 'solana kripto',
  ),
  const Asset(
    id: 'xrpusd',
    name: 'XRP',
    icon: '✕',
    group: AssetGroup.kripto,
    symbol: 'XRP-USD',
    unit: '\$',
    decimals: 4,
    newsQuery: 'xrp ripple',
  ),
  const Asset(
    id: 'bnbusd',
    name: 'BNB',
    icon: '🅑',
    group: AssetGroup.kripto,
    symbol: 'BNB-USD',
    unit: '\$',
    newsQuery: 'binance coin bnb',
  ),
  const Asset(
    id: 'dogeusd',
    name: 'Dogecoin',
    icon: '🐕',
    group: AssetGroup.kripto,
    symbol: 'DOGE-USD',
    unit: '\$',
    decimals: 4,
    newsQuery: 'dogecoin',
  ),

  // -------------------------------- Endeks ----------------------------------
  const Asset(
    id: 'bist100',
    name: 'BIST 100',
    icon: '📊',
    group: AssetGroup.endeks,
    symbol: 'XU100.IS',
    unit: '',
    newsQuery: 'borsa istanbul bist 100',
  ),
  const Asset(
    id: 'bist30',
    name: 'BIST 30',
    icon: '📊',
    group: AssetGroup.endeks,
    symbol: 'XU030.IS',
    unit: '',
    newsQuery: 'bist 30 endeksi',
  ),
  const Asset(
    id: 'xbank',
    name: 'BIST Banka',
    icon: '🏦',
    group: AssetGroup.endeks,
    symbol: 'XBANK.IS',
    unit: '',
    newsQuery: 'bankacılık endeksi borsa istanbul',
  ),
  const Asset(
    id: 'sp500',
    name: 'S&P 500',
    icon: '📈',
    group: AssetGroup.endeks,
    symbol: '^GSPC',
    unit: '',
    newsQuery: 's&p 500 endeksi',
  ),
  const Asset(
    id: 'nasdaq',
    name: 'Nasdaq Composite',
    icon: '📈',
    group: AssetGroup.endeks,
    symbol: '^IXIC',
    unit: '',
    newsQuery: 'nasdaq endeksi',
  ),
  const Asset(
    id: 'dowjones',
    name: 'Dow Jones',
    icon: '📈',
    group: AssetGroup.endeks,
    symbol: '^DJI',
    unit: '',
    newsQuery: 'dow jones endeksi',
  ),
  const Asset(
    id: 'dax',
    name: 'DAX',
    icon: '🇩🇪',
    group: AssetGroup.endeks,
    symbol: '^GDAXI',
    unit: '',
    newsQuery: 'dax endeksi almanya borsası',
  ),
  const Asset(
    id: 'ftse',
    name: 'FTSE 100',
    icon: '🇬🇧',
    group: AssetGroup.endeks,
    symbol: '^FTSE',
    unit: '',
    newsQuery: 'ftse 100 londra borsası',
  ),
  const Asset(
    id: 'nikkei',
    name: 'Nikkei 225',
    icon: '🇯🇵',
    group: AssetGroup.endeks,
    symbol: '^N225',
    unit: '',
    newsQuery: 'nikkei japonya borsası',
  ),
  const Asset(
    id: 'vix',
    name: 'VIX (Korku Endeksi)',
    icon: '😨',
    group: AssetGroup.endeks,
    symbol: '^VIX',
    unit: '',
    newsQuery: 'vix korku endeksi',
  ),
];

/// Verilen varlıkları gösterebilmek için çekilmesi gereken semboller.
///
/// Yalnızca ekranda görünen varlıklar için istek atalım diye ayrı duruyor.
List<String> symbolsFor(Iterable<Asset> assets) =>
    {for (final a in assets) ...a.requiredSymbols}.toList();

/// Katalogdaki tüm semboller.
List<String> get kAllSymbols => symbolsFor(kAssets);

/// Bir TEFAS fonunu listede gösterilebilir varlığa çevirir.
///
/// Kimlikler 'fon:' önekiyle ayrılır; izleme listesi ve sıralama aynı kimlik
/// alanını piyasa varlıklarıyla paylaşır.
Asset fundAsset(Fund fund) => Asset(
  id: 'fon:${fund.code}',
  name: '${fund.code} · ${fund.shortName}',
  icon: '🏦',
  group: AssetGroup.fon,
  unit: '₺',
  decimals: 6,
  fundCode: fund.code,
  newsQuery: '${fund.shortName} fonu',
);
