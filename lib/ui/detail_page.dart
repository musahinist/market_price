import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/asset.dart';
import '../models/fund.dart';
import '../models/news_item.dart';
import '../models/price_series.dart';
import '../models/quote.dart';
import '../services/market_service.dart';
import '../services/fund_service.dart';
import '../services/news_service.dart';
import '../services/range_store.dart';
import '../services/url_opener.dart';
import 'formats.dart';
import 'price_chart.dart';
import 'range_bar.dart';

const _up = Color(0xFF16C784);
const _down = Color(0xFFEA3943);

/// Açık detay sayfasında fiyat ve grafiğin tazelenme aralığı.
const _refreshInterval = Duration(seconds: 60);

class DetailPage extends StatefulWidget {
  const DetailPage({
    super.key,
    required this.asset,
    required this.quote,
    this.fund,
  });

  final Asset asset;
  final Quote? quote;

  /// Fon varlıklarında dönem getirileri; piyasa varlıklarında null.
  final Fund? fund;

  @override
  State<DetailPage> createState() => _DetailPageState();
}

class _DetailPageState extends State<DetailPage> {
  final _market = MarketService();
  final _news = NewsService();
  final _fundService = FundService();

  FundInfo? _fundInfo;

  /// Güncel fiyat; açılışta listedeki değer, sonra dakikada bir tazelenir.
  late Quote? _quote = widget.quote;
  Timer? _timer;

  /// Bugün verilecek alış / satış emrinin valör tarihi.
  DateTime? _buyValue;
  DateTime? _sellValue;

  ChartRange _range = ChartRangeSetting.value.value;
  PriceSeries? _series;
  bool _chartLoading = true;
  String? _chartError;

  List<NewsItem> _items = const [];
  bool _newsLoading = true;

  /// Grafikte parmakla seçilen nokta; boşsa güncel fiyat gösterilir.
  int? _selected;

  @override
  void initState() {
    super.initState();
    ChartRangeSetting.value.addListener(_onRangeChanged);
    if (widget.asset.isFund) {
      _loadFund();
    } else {
      _loadChart();
      _timer = Timer.periodic(_refreshInterval, (_) => _refreshLive());
    }
    _loadNews();
  }

  @override
  void dispose() {
    ChartRangeSetting.value.removeListener(_onRangeChanged);
    _timer?.cancel();
    _market.dispose();
    _news.dispose();
    _fundService.dispose();
    super.dispose();
  }

  Future<void> _loadChart() async {
    final symbol = widget.asset.effectiveChartSymbol;
    if (symbol == null) {
      setState(() => _chartLoading = false);
      return;
    }

    setState(() {
      _chartLoading = true;
      _chartError = null;
      _selected = null;
    });

    try {
      final range = _range;
      final series = await _market.fetchAssetSeries(widget.asset, range);
      // Bu arada aralık değiştiyse eski cevabı yazma.
      if (!mounted || range != _range) return;
      setState(() {
        _series = series;
        _chartLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _series = null;
        _chartError = e is MarketException ? e.message : 'Grafik yüklenemedi.';
        _chartLoading = false;
      });
    }
  }

  /// Fiyatı ve grafiği sessizce tazeler; hata olursa eldekiler kalır.
  Future<void> _refreshLive() async {
    // Parmak grafiğin üzerindeyken seri altından değişmesin.
    if (_chartLoading || _selected != null) return;
    final range = _range;
    try {
      final results = await Future.wait([
        _market.fetchQuotes(widget.asset.requiredSymbols.toList()),
        _market.fetchAssetSeries(widget.asset, range),
      ]);
      if (!mounted || range != _range || _chartLoading || _selected != null) {
        return;
      }
      setState(() {
        _quote =
            widget.asset.quoteFrom(results[0] as Map<String, Quote>) ?? _quote;
        _series = results[1] as PriceSeries;
      });
    } catch (_) {}
  }

  Future<void> _loadFund() async {
    setState(() => _chartLoading = false);
    final code = widget.asset.fundCode!;
    try {
      final results = await Future.wait([
        _fundService.fetchFundInfo(code),
        // Valör TEFAS'ın kendi tatil/saat hesabıyla geliyor.
        _fundService
            .fetchSettlementDate(code, buy: true)
            .catchError((_) => null),
        _fundService
            .fetchSettlementDate(code, buy: false)
            .catchError((_) => null),
      ]);
      if (!mounted) return;
      setState(() {
        _fundInfo = results[0] as FundInfo;
        _buyValue = results[1] as DateTime?;
        _sellValue = results[2] as DateTime?;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _chartError = e is MarketException
            ? e.message
            : 'Fon bilgisi alınamadı.';
      });
    }
  }

  Future<void> _loadNews() async {
    try {
      final items = await _news.fetch(widget.asset.newsQuery);
      if (!mounted) return;
      setState(() {
        _items = items;
        _newsLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _newsLoading = false);
    }
  }

  void _selectRange(ChartRange range) => ChartRangeSetting.set(range);

  void _onRangeChanged() {
    final range = ChartRangeSetting.value.value;
    if (!mounted || range == _range) return;
    setState(() => _range = range);
    _loadChart();
  }

  Future<void> _open(NewsItem item) async {
    if (item.link.isEmpty) return;
    final opened = await UrlOpener.open(item.link);
    if (!opened && mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Bağlantı açılamadı.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final series = _series;

    // Parmak grafiğin üzerindeyken o noktanın değerini göster.
    final picked = (_selected != null && series != null)
        ? series.values[_selected!]
        : null;
    // Canlı fiyat serinin son barından tazedir; başlık da yüzde de onu kullansın
    // ki listedeki değerle birebir tutsun.
    final live = _fundInfo?.quote.price ?? _quote?.price ?? series?.values.last;
    final headline = picked ?? live;

    final changePercent = widget.asset.isFund
        ? (_fundInfo?.quote.changePercent ?? _quote?.changePercent)
        : _changePercent(series, live);
    final color = (changePercent ?? 0) >= 0 ? _up : _down;

    return Scaffold(
      appBar: AppBar(title: Text(widget.asset.name)),
      body: ListView(
        padding: EdgeInsets.only(
          bottom: 24 + MediaQuery.paddingOf(context).bottom,
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  headline == null ? '—' : _price(headline),
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _subtitle(series, changePercent, live),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (widget.asset.isFund) ...[
            if (widget.fund != null) _FundReturns(fund: widget.fund!),
            if (_fundInfo != null)
              _FundFacts(
                info: _fundInfo!,
                risk: widget.fund?.risk,
                onTefas: widget.fund?.onTefas,
                buyValue: _buyValue,
                sellValue: _sellValue,
              ),
            if (_fundInfo == null && _chartError != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  _chartError!,
                  style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                ),
              ),
          ] else ...[
            SizedBox(
              height: 200,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: _buildChart(color),
              ),
            ),
            const SizedBox(height: 10),
            RangeBar(selected: _range, onSelected: _selectRange),
          ],
          const Divider(height: 28),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              'Haberler',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (_newsLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_items.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Haber bulunamadı.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            )
          else
            for (final item in _items)
              _NewsRow(item: item, onTap: () => _open(item)),
        ],
      ),
    );
  }

  /// Aralık değişimi: başlıktaki fiyatın, aralık öncesi kapanışa göre farkı.
  double? _changePercent(PriceSeries? series, double? live) {
    if (series == null || live == null) return _quote?.changePercent;
    final base = series.previousClose != 0
        ? series.previousClose
        : series.values.first;
    if (base == 0) return null;
    return (live - base) / base * 100;
  }

  double? _change(PriceSeries? series, double? live) {
    if (series == null || live == null) return null;
    final base = series.previousClose != 0
        ? series.previousClose
        : series.values.first;
    return live - base;
  }

  Widget _buildChart(Color color) {
    if (_chartLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    final series = _series;
    if (series == null || series.isEmpty) {
      return Center(
        child: Text(
          _chartError ?? 'Bu varlık için grafik yok.',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }
    return PriceChart(
      series: series,
      color: color,
      onSelected: (i) => setState(() => _selected = i),
    );
  }

  String _price(double value) {
    final formatted = decimalFormat(widget.asset.decimals).format(value);
    return '${widget.asset.unit}$formatted${widget.asset.suffix}';
  }

  String _subtitle(PriceSeries? series, double? changePercent, double? live) {
    if (_selected != null && series != null) {
      final t = series.times[_selected!];
      final pattern = _range == ChartRange.d1 || _range == ChartRange.w1
          ? 'd MMM HH:mm'
          : 'd MMM yyyy';
      final date = DateFormat(pattern, 'tr').format(t);
      // Seçilen noktanın da dönem başına göre değişimi görünsün.
      final picked = _changePercent(series, series.values[_selected!]);
      return picked == null
          ? date
          : '%${percentFormat.format(picked)}  ·  $date';
    }

    if (changePercent == null) return '';
    final pct = percentFormat.format(changePercent);

    // Fonlar günde bir fiyatlanır; aralık etiketi yerine 'günlük'.
    if (widget.asset.isFund) return '%$pct  ·  günlük';
    final change = _change(series, live);
    final abs = change == null
        ? ''
        : '${change >= 0 ? '+' : ''}'
              '${decimalFormat(widget.asset.decimals).format(change)}  ';
    return '$abs%$pct  ·  ${_range.label}';
  }
}

class _NewsRow extends StatelessWidget {
  const _NewsRow({required this.item, required this.onTap});

  final NewsItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(item.title, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 3),
            Text(
              [
                item.source,
                if (item.publishedAt != null) _ago(item.publishedAt!),
              ].where((s) => s.isNotEmpty).join(' · '),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _ago(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 60) return '${diff.inMinutes} dk önce';
    if (diff.inHours < 24) return '${diff.inHours} saat önce';
    return '${diff.inDays} gün önce';
  }
}

/// Fonun dönem getirileri.
class _FundReturns extends StatelessWidget {
  const _FundReturns({required this.fund});

  final Fund fund;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rows = [
      for (final period in FundPeriod.values)
        if (fund.periodReturn(period.key) != null)
          (period.label, fund.periodReturn(period.key)!),
    ];
    if (rows.isEmpty) return const SizedBox.shrink();

    final peak = rows.map((r) => r.$2.abs()).reduce((a, b) => a > b ? a : b);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Getiri',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          for (final row in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  SizedBox(
                    width: 64,
                    child: Text(
                      row.$1,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) => Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
                          height: 7,
                          width: peak == 0
                              ? 0
                              : constraints.maxWidth * (row.$2.abs() / peak),
                          decoration: BoxDecoration(
                            color: (row.$2 >= 0 ? _up : _down).withValues(
                              alpha: 0.55,
                            ),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 66,
                    child: Text(
                      '%${percentFormat.format(row.$2)}',
                      textAlign: TextAlign.right,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: row.$2 >= 0 ? _up : _down,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Fonun künyesi: kategori, büyüklük, yatırımcı sayısı.
class _FundFacts extends StatelessWidget {
  const _FundFacts({
    required this.info,
    this.risk,
    this.onTefas,
    this.buyValue,
    this.sellValue,
  });

  final FundInfo info;
  final int? risk;
  final bool? onTefas;
  final DateTime? buyValue;
  final DateTime? sellValue;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final compact = NumberFormat.compactCurrency(
      locale: 'tr_TR',
      symbol: '₺',
      decimalDigits: 1,
    );

    final valueDate = DateFormat('d MMMM EEEE', 'tr');

    final facts = <(String, String)>[
      if (info.category != null) ('Kategori', info.category!),
      if (risk != null) ('Risk değeri', '$risk / 7'),
      if (onTefas == false) ('Platform', 'TEFAS dışı · kurucu kanalları'),
      if (buyValue != null) ('Alış valörü', valueDate.format(buyValue!)),
      if (sellValue != null) ('Satış valörü', valueDate.format(sellValue!)),
      if (info.portfolioSize != null)
        ('Portföy büyüklüğü', compact.format(info.portfolioSize)),
      if (info.investors != null)
        ('Yatırımcı', integerFormat.format(info.investors)),
      if ((info.categoryRank ?? 0) > 0 && info.categoryCount != null)
        ('Kategori sırası', '${info.categoryRank} / ${info.categoryCount}'),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: Column(
        children: [
          for (final fact in facts)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      fact.$1,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  Text(fact.$2, style: theme.textTheme.bodySmall),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
