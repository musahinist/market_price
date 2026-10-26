import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/asset_catalog.dart';
import '../models/asset.dart';
import '../models/fund.dart';
import '../models/price_series.dart';
import '../models/quote.dart';
import '../services/market_service.dart';
import '../services/focus_store.dart';
import '../services/fund_cache.dart';
import '../services/fund_service.dart';
import '../services/order_store.dart';
import '../services/range_store.dart';
import '../services/watch_store.dart';
import 'asset_tile.dart';
import 'detail_page.dart';
import 'focus_cards.dart';
import 'fund_tile.dart';
import 'price_chart.dart';
import 'range_bar.dart';

/// Fiyatların kendiliğinden tazelenme aralığı.
const _refreshInterval = Duration(seconds: 60);

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  final _service = MarketService();
  final _orderStore = OrderStore();
  final _watchStore = WatchStore();
  final _focusStore = FocusStore();
  final _fundService = FundService();
  final _fundCache = FundCache();

  late final TabController _tabs;

  List<Asset> _assets = List.of(kAssets);

  /// TEFAS para piyasası fonları, getiriye göre sıralı.
  List<Fund> _funds = const [];
  bool _fundsLoading = true;
  String? _fundsError;

  /// Fon kodu -> son fiyat. Yalnızca izlenen fonlar için çekilir.
  final Map<String, Quote> _fundQuotes = {};

  /// Fon kodu -> varlık. Satır çiziminde yeniden üretmemek için önbellek.
  final Map<String, Asset> _fundAssets = {};

  /// Fon sekmesindeki arama metni.
  String _fundQuery = '';
  final _fundSearch = TextEditingController();
  Set<String> _watched = {};
  FocusConfig _focus = const FocusConfig();

  /// Odak kartının altındaki grafik.
  ChartRange _focusRange = ChartRangeSetting.value.value;
  PriceSeries? _focusSeries;

  /// Yüklü serinin kimliği: 'varlık|aralık'. İstenenle uyuşmuyorsa yeniden çekilir.
  String? _focusChartKey;
  String? _focusChartError;
  bool _focusChartLoading = false;
  Map<String, Quote> _quotes = {};

  Timer? _timer;
  DateTime? _updatedAt;
  String? _error;
  bool _loading = true;

  /// Açıkken satırlarda sürükleme tutamacı ve listeden çıkarma yıldızı görünür.
  bool _editMode = false;

  bool get _onWatchlist => _tabs.index == 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _tabs = TabController(length: 3, vsync: this)..addListener(_onTabChanged);
    ChartRangeSetting.value.addListener(_onRangeChanged);
    _restore();
    _timer = Timer.periodic(_refreshInterval, (_) => _refresh());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    ChartRangeSetting.value.removeListener(_onRangeChanged);
    _tabs.dispose();
    _fundSearch.dispose();
    _service.dispose();
    _fundService.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Uygulama öne geldiğinde fiyatlar bayat olmasın.
    if (state == AppLifecycleState.resumed) _refresh();
  }

  /// Kayıtlı sıra ve izleme listesini yükleyip ilk isteği atar.
  Future<void> _restore() async {
    final watched = await _watchStore.load();
    final focus = await _focusStore.load();
    final order = await _orderStore.load(_catalog);
    if (!mounted) return;

    setState(() {
      _assets = order;
      _watched = watched;
      _focus = focus;
    });

    await _refresh();
    await _loadFunds();
  }

  /// Piyasa varlıkları + TEFAS fonları.
  List<Asset> get _catalog => [...kAssets, ..._fundAssets.values];

  void _showFundLegend() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        final theme = Theme.of(context);
        final rows = <(Widget, String)>[
          (
            const _LegendBadge(text: 'R1', risk: 1),
            'Risk değeri 1-7. Düşükten yükseğe renklenir: '
                'yeşil 1-2, sarı 3-4, turuncu 5-6, kırmızı 7.',
          ),
          (const _LegendBadge(text: 'K'), 'Katılım şemsiye fonu'),
          (const _LegendBadge(text: 'S'), 'Serbest şemsiye fonu'),
          (
            const _LegendBadge(text: 'TD'),
            'TEFAS dışı: platformda alınıp satılamaz, yalnızca kurucunun '
                'kendi kanallarından alınır',
          ),
        ];

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Kısaltmalar',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                for (final row in rows)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(width: 42, child: row.$1),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(row.$2, style: theme.textTheme.bodySmall),
                        ),
                      ],
                    ),
                  ),
                const Divider(height: 20),
                Text(
                  'Büyük yüzde son 1 ayın getirisi. Yanındaki hücreler '
                  'yılbaşından itibaren (yıl) ve son 1 yılın (1y) getirisi.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Aramaya uyan fonlar.
  List<Fund> get _visibleFunds {
    final query = normalizeForSearch(_fundQuery.trim());
    if (query.isEmpty) return _funds;
    return _funds.where((f) => f.searchText.contains(query)).toList();
  }

  /// [force] true ise önbellek atlanır (aşağı çekerek yenileme).
  Future<void> _loadFunds({bool force = false}) async {
    try {
      var funds = force ? null : await _fundCache.load();
      if (funds == null) {
        funds = await _fundService.fetchMoneyMarketFunds();
        await _fundCache.save(funds);
      }
      final loaded = funds;
      if (!mounted) return;
      setState(() {
        _funds = loaded;
        _fundAssets
          ..clear()
          ..addEntries(loaded.map((f) => MapEntry(f.code, fundAsset(f))));
        _fundsLoading = false;
        _fundsError = null;
        // Yeni gelen fonlar kayıtlı sıranın sonuna eklensin.
        _assets = applyOrder(_assets.map((a) => a.id).toList(), _catalog);
      });
      await _refreshFundQuotes();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _fundsLoading = false;
        _fundsError = e is MarketException ? e.message : 'Fonlar alınamadı.';
      });
    }
  }

  /// İzlenen fonların son fiyatlarını çeker; TEFAS toplu fiyat vermiyor.
  Future<void> _refreshFundQuotes() async {
    final codes = _watchlist
        .map((a) => a.fundCode)
        .whereType<String>()
        .toList();
    if (codes.isEmpty) return;

    final infos = await Future.wait(
      codes.map((code) async {
        try {
          return await _fundService.fetchFundInfo(code);
        } catch (_) {
          return null;
        }
      }),
    );
    if (!mounted) return;

    setState(() {
      for (final info in infos) {
        if (info != null) _fundQuotes[info.code] = info.quote;
      }
    });
  }

  void _onTabChanged() {
    if (_tabs.indexIsChanging) return;
    setState(() {});
    // Yeni sekmede henüz fiyatı olmayan varlıklar varsa onları çek.
    if (_missingSymbols.isNotEmpty) _refresh();
  }

  /// Görünen sekmedeki varlıklar.
  List<Asset> get _visible => _onWatchlist
      ? _assets.where((a) => _watched.contains(a.id)).toList()
      : _assets;

  List<String> get _neededSymbols => symbolsFor(_visible);

  List<String> get _missingSymbols =>
      _neededSymbols.where((s) => !_quotes.containsKey(s)).toList();

  Future<void> _refresh() async {
    // Sürükleme sırasında liste altından değişmesin.
    if (_editMode) return;

    final symbols = _neededSymbols;
    if (symbols.isEmpty) {
      setState(() => _loading = false);
      return;
    }

    try {
      final quotes = await _service.fetchQuotes(symbols);
      if (!mounted) return;
      setState(() {
        // Diğer sekmede çekilmiş fiyatlar kaybolmasın.
        _quotes = {..._quotes, ...quotes};
        _updatedAt = DateTime.now();
        _error = null;
        _loading = false;
      });
      // Grafiğin son noktası da yeni fiyata yetişsin.
      _syncFocusChart(refresh: true);
      unawaited(_refreshFundQuotes());
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e is MarketException ? e.message : 'Bir hata oluştu.';
        _loading = false;
      });
    }
  }

  /// İzleme listesindeki varlıklar, kayıtlı sırayla.
  List<Asset> get _watchlist =>
      _assets.where((a) => _watched.contains(a.id)).toList();

  /// Odak yuvalarına oturmuş varlıklar.
  FocusSlots get _slots => resolveFocus(_focus, _watchlist);

  Asset? get _primaryAsset => _slots.primary;

  void _onRangeChanged() {
    final range = ChartRangeSetting.value.value;
    if (!mounted || range == _focusRange) return;
    setState(() => _focusRange = range);
    _syncFocusChart();
  }

  /// İstenen odak grafiğinin kimliği: 'varlık|aralık'.
  String? get _wantedFocusChartKey {
    final asset = _primaryAsset;
    return asset == null ? null : '${asset.id}|${_focusRange.name}';
  }

  /// Gereken grafik yüklü değilse çeker. Her durum değişiminden sonra çağrılır.
  ///
  /// [refresh] verilirse yüklü grafik de sessizce yeniden çekilir; yoksa
  /// liste fiyatı tazelenirken grafik açıldığı andaki fiyatta kalır.
  void _syncFocusChart({bool refresh = false}) {
    final asset = _primaryAsset;
    if (asset == null || !_focus.primaryOpen || !_focus.chartOpen) return;

    final key = _wantedFocusChartKey!;
    if (_focusChartLoading) return;
    if (key == _focusChartKey) {
      if (refresh) _loadFocusChart(asset, key, silent: true);
      return;
    }
    _loadFocusChart(asset, key);
  }

  Future<void> _loadFocusChart(
    Asset asset,
    String key, {
    bool silent = false,
  }) async {
    if (!silent) {
      setState(() {
        _focusChartLoading = true;
        _focusChartError = null;
      });
    }

    try {
      final series = await _service.fetchAssetSeries(asset, _focusRange);
      // Bu arada aralık ya da varlık değiştiyse eski cevabı yazma.
      if (!mounted || key != _wantedFocusChartKey) return;
      setState(() {
        _focusSeries = series;
        _focusChartKey = key;
        _focusChartLoading = false;
      });
    } catch (_) {
      if (!mounted || key != _wantedFocusChartKey) return;
      // Sessiz tazelemede hata olursa eldeki grafik kalsın.
      if (silent) return;
      setState(() {
        _focusSeries = null;
        _focusChartKey = null;
        _focusChartError = 'Grafik yüklenemedi.';
        _focusChartLoading = false;
      });
    } finally {
      if (mounted && !silent && _focusChartLoading) {
        setState(() => _focusChartLoading = false);
        _syncFocusChart();
      }
    }
  }

  void _saveFocus(FocusConfig config) {
    setState(() => _focus = config);
    _focusStore.save(config);
    _syncFocusChart();
  }

  /// Bir odak yuvasına izleme listesinden varlık seçtirir.
  ///
  /// [slot] 0 = büyük kart, 1 ve 2 = küçük kartlar.
  Future<void> _pickFocusAsset({required int slot}) async {
    final options = _watchlist;
    if (options.isEmpty) return;

    final slots = _slots;
    final current = slot == 0
        ? slots.primary?.id
        : slots.secondary[slot - 1]?.id;

    final picked = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final asset in options)
              ListTile(
                leading: Text(asset.icon, style: const TextStyle(fontSize: 18)),
                title: Text(asset.name),
                trailing: asset.id == current
                    ? const Icon(Icons.check, color: kUp)
                    : null,
                onTap: () => Navigator.of(context).pop(asset.id),
              ),
          ],
        ),
      ),
    );
    if (picked == null || !mounted) return;

    _saveFocus(assignFocus(_focus, _watchlist, slot: slot, id: picked));
  }

  void _toggleWatch(Asset asset) {
    setState(() {
      if (!_watched.remove(asset.id)) _watched.add(asset.id);
    });
    _watchStore.save(_watched);
    _syncFocusChart();
    if (asset.isFund) _refreshFundQuotes();
  }

  /// [newIndex] Flutter tarafından zaten kaydırılmış olarak gelir.
  void _onReorder(int oldIndex, int newIndex) {
    setState(() {
      if (!_onWatchlist) {
        _assets.insert(newIndex, _assets.removeAt(oldIndex));
        return;
      }

      // İzleme listesinde sürüklenince yeni sırayı ana listedeki izlenen
      // konumlara geri yazıyoruz ki tek bir sıra kalsın.
      final watched = _visible;
      watched.insert(newIndex, watched.removeAt(oldIndex));

      final slots = [
        for (var i = 0; i < _assets.length; i++)
          if (_watched.contains(_assets[i].id)) i,
      ];
      for (var i = 0; i < slots.length; i++) {
        _assets[slots[i]] = watched[i];
      }
    });
    _orderStore.save(_assets);
    _syncFocusChart();
  }

  Future<void> _resetOrder() async {
    final assets = await _orderStore.reset(_catalog);
    if (!mounted) return;
    setState(() => _assets = assets);
  }

  void _toggleEditMode() {
    setState(() => _editMode = !_editMode);
    if (!_editMode) _refresh();
  }

  void _openDetail(Asset asset) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DetailPage(
          asset: asset,
          quote: _quoteFor(asset),
          fund: _fundFor(asset),
        ),
      ),
    );
  }

  Fund? _fundFor(Asset asset) {
    final code = asset.fundCode;
    if (code == null) return null;
    for (final fund in _funds) {
      if (fund.code == code) return fund;
    }
    return null;
  }

  /// Bir varlığın fiyatı: doğrudan sembolden ya da türetilerek.
  Quote? _quoteFor(Asset asset) {
    if (asset.fundCode != null) return _fundQuotes[asset.fundCode];
    return asset.quoteFrom(_quotes);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        titleSpacing: 0,
        leading: Icon(
          Icons.candlestick_chart_rounded,
          color: theme.colorScheme.primary,
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.schedule,
              size: 15,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 5),
            Text(
              _updatedAt == null
                  ? '--:--:--'
                  : DateFormat('HH:mm:ss').format(_updatedAt!),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
        actions: [
          // Yenileme ikonuna benzemesin diye metinli menü.
          // Fon sekmesindeki kısaltmaların anlamı.
          if (!_editMode && _tabs.index == 2)
            IconButton(
              onPressed: _showFundLegend,
              icon: const Icon(Icons.info_outline),
              tooltip: 'Kısaltmalar',
            ),
          if (_editMode)
            PopupMenuButton<void>(
              tooltip: 'Diğer',
              itemBuilder: (context) => [
                PopupMenuItem<void>(
                  onTap: _resetOrder,
                  child: const Text('Varsayılan sıraya dön'),
                ),
              ],
            ),
          IconButton(
            onPressed: _toggleEditMode,
            icon: Icon(_editMode ? Icons.check : Icons.edit_outlined),
            tooltip: _editMode ? 'Bitti' : 'Listeyi düzenle',
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          tabs: const [
            Tab(text: 'İzleme'),
            Tab(text: 'Tüm Liste'),
            Tab(text: 'Fonlar'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabs,
              // Sıralarken yatay kaydırma sürüklemeyle çakışmasın.
              physics: _editMode ? const NeverScrollableScrollPhysics() : null,
              children: [
                _buildTab(all: false),
                _buildTab(all: true),
                _buildFundTab(),
              ],
            ),
    );
  }

  Widget _buildTab({required bool all}) {
    final assets = all ? _assets.where((a) => !a.isFund).toList() : _watchlist;

    if (!all && assets.isEmpty) return const _EmptyWatchlist();
    if (_editMode) return _buildReorderable(assets);
    if (!all) return _buildWatchTab();

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView.builder(
        addAutomaticKeepAlives: false,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: _listPadding,
        itemCount: assets.length + (_error != null ? 1 : 0),
        itemBuilder: (context, index) {
          if (_error != null) {
            if (index == 0) return _ErrorBanner(message: _error!);
            index -= 1;
          }
          final asset = assets[index];
          return AssetTile(
            asset: asset,
            quote: _quoteFor(asset),
            onTap: () => _openDetail(asset),
            // İzleme listesinde yıldız yalnızca düzenleme modunda çıkar.
            watched: all ? _watched.contains(asset.id) : null,
            onWatchToggle: () => _toggleWatch(asset),
          );
        },
      ),
    );
  }

  /// İzleme sekmesi: odak kartı + grafik, iki ikincil kart, sonra liste.
  ///
  /// Bölümler farklı yapıda olduğu için ListView yerine sliver kullanıyoruz;
  /// böylece liste tembel kalır ve kartlar kaydırma içinde doğru ölçülenir.
  Widget _buildWatchTab() {
    final watchlist = _watchlist;
    final slots = resolveFocus(_focus, watchlist);
    final primary = slots.primary;
    final secondary = slots.secondary;
    final theme = Theme.of(context);

    return RefreshIndicator(
      onRefresh: _refresh,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          const SliverToBoxAdapter(child: SizedBox(height: 6)),
          if (_error != null)
            SliverToBoxAdapter(child: _ErrorBanner(message: _error!)),

          SliverToBoxAdapter(
            child: _SectionDivider(
              open: _focus.primaryOpen,
              onToggle: () =>
                  _saveFocus(_focus.copyWith(primaryOpen: !_focus.primaryOpen)),
              trailing: _focus.primaryOpen && primary != null
                  ? IconButton(
                      onPressed: () => _saveFocus(
                        _focus.copyWith(chartOpen: !_focus.chartOpen),
                      ),
                      visualDensity: VisualDensity.compact,
                      tooltip: _focus.chartOpen
                          ? 'Grafiği gizle'
                          : 'Grafiği göster',
                      icon: Icon(
                        _focus.chartOpen
                            ? Icons.show_chart
                            : Icons.stacked_line_chart,
                        size: 19,
                        color: _focus.chartOpen
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                    )
                  : null,
            ),
          ),
          if (_focus.primaryOpen && primary != null) ...[
            SliverToBoxAdapter(
              child: PrimaryFocusCard(
                asset: primary,
                quote: _quoteFor(primary),
                onTap: () => _openDetail(primary),
                onChange: () => _pickFocusAsset(slot: 0),
              ),
            ),
            if (_focus.chartOpen)
              SliverToBoxAdapter(child: _buildFocusChart(primary)),
          ],

          SliverToBoxAdapter(
            child: _SectionDivider(
              open: _focus.secondaryOpen,
              onToggle: () => _saveFocus(
                _focus.copyWith(secondaryOpen: !_focus.secondaryOpen),
              ),
            ),
          ),
          if (_focus.secondaryOpen)
            SliverToBoxAdapter(
              child: SecondaryFocusRow(
                slots: [
                  for (var slot = 0; slot < 2; slot++)
                    if (secondary[slot] == null)
                      _EmptySlot(onTap: () => _pickFocusAsset(slot: slot + 1))
                    else
                      SecondaryFocusCard(
                        asset: secondary[slot]!,
                        quote: _quoteFor(secondary[slot]!),
                        onTap: () => _openDetail(secondary[slot]!),
                        onChange: () => _pickFocusAsset(slot: slot + 1),
                      ),
                ],
              ),
            ),

          SliverToBoxAdapter(
            child: _SectionDivider(
              open: _focus.listOpen,
              onToggle: () =>
                  _saveFocus(_focus.copyWith(listOpen: !_focus.listOpen)),
            ),
          ),
          if (_focus.listOpen)
            SliverList.builder(
              addAutomaticKeepAlives: false,
              itemCount: watchlist.length,
              itemBuilder: (context, index) {
                final asset = watchlist[index];
                return AssetTile(
                  asset: asset,
                  quote: _quoteFor(asset),
                  onTap: () => _openDetail(asset),
                );
              },
            ),

          SliverToBoxAdapter(
            child: SizedBox(height: 24 + MediaQuery.paddingOf(context).bottom),
          ),
        ],
      ),
    );
  }

  Widget _buildFocusChart(Asset asset) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 0, 0, 8),
      child: Column(
        children: [
          SizedBox(
            height: 150,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: _focusChartLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _focusSeries == null
                  ? Center(
                      child: Text(
                        _focusChartError ?? '',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    )
                  : RepaintBoundary(
                      child: PriceChart(
                        series: _focusSeries!,
                        color: _focusSeries!.changePercent >= 0 ? kUp : kDown,
                        onSelected: (_) {},
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 8),
          RangeBar(selected: _focusRange, onSelected: ChartRangeSetting.set),
        ],
      ),
    );
  }

  /// Fon sekmesi: TEFAS para piyasası fonları, aylık getiriye göre sıralı.
  Widget _buildFundTab() {
    final theme = Theme.of(context);
    final visible = _visibleFunds;

    if (_fundsLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_funds.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            _fundsError ?? 'Fon bulunamadı.',
            textAlign: TextAlign.center,
            style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _loadFunds(force: true),
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 6),
              child: TextField(
                controller: _fundSearch,
                onChanged: (value) => setState(() => _fundQuery = value),
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  isDense: true,
                  hintText: 'Fon kodu veya adı ara',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  suffixIcon: _fundQuery.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.close, size: 18),
                          onPressed: () {
                            _fundSearch.clear();
                            setState(() => _fundQuery = '');
                          },
                        ),
                  filled: true,
                  fillColor: theme.colorScheme.surfaceContainerHigh,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 6),
              child: Text(
                _fundQuery.isEmpty
                    ? 'Para piyasası fonları · son 1 ayın getirisine göre'
                    : '${visible.length} fon bulundu',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
          SliverList.builder(
            addAutomaticKeepAlives: false,
            itemCount: visible.length,
            itemBuilder: (context, index) {
              final fund = visible[index];
              final asset = _fundAssets[fund.code]!;
              return FundTile(
                fund: fund,
                watched: _watched.contains(asset.id),
                onTap: () => _openDetail(asset),
                onWatchToggle: () => _toggleWatch(asset),
              );
            },
          ),
          SliverToBoxAdapter(
            child: SizedBox(height: 24 + MediaQuery.paddingOf(context).bottom),
          ),
        ],
      ),
    );
  }

  Widget _buildReorderable(List<Asset> assets) {
    return ReorderableListView.builder(
      padding: _listPadding,
      itemCount: assets.length,
      onReorderItem: _onReorder,
      proxyDecorator: (child, index, animation) =>
          Material(color: Colors.transparent, elevation: 6, child: child),
      itemBuilder: (context, index) {
        final asset = assets[index];
        return AssetTile(
          key: ValueKey(asset.id),
          asset: asset,
          quote: _quoteFor(asset),
          dragIndex: index,
          watched: _watched.contains(asset.id),
          onWatchToggle: () => _toggleWatch(asset),
        );
      },
    );
  }

  EdgeInsets get _listPadding => EdgeInsets.only(
    top: 6,
    bottom: 24 + MediaQuery.paddingOf(context).bottom,
  );
}

/// Açılıp kapanan bölüm ayırıcısı: başlık yok, yalnızca ok ve varsa eylem.
class _SectionDivider extends StatelessWidget {
  const _SectionDivider({
    required this.open,
    required this.onToggle,
    this.trailing,
  });

  final bool open;
  final VoidCallback onToggle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 2, 10, 2),
      child: Row(
        children: [
          InkWell(
            onTap: onToggle,
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Icon(
                open ? Icons.expand_more : Icons.chevron_right,
                size: 18,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Divider(
              height: 1,
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// Henüz varlık seçilmemiş ikincil kart.
class _EmptySlot extends StatelessWidget {
  const _EmptySlot({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: DottedBorderBox(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.add, color: theme.colorScheme.onSurfaceVariant),
              const SizedBox(height: 4),
              Text(
                'Varlık seç',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Boş yuva için kesik çizgili çerçeve yerine yumuşak dolgu.
class DottedBorderBox extends StatelessWidget {
  const DottedBorderBox({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: child,
    );
  }
}

/// Kısaltma listesindeki örnek rozet.
class _LegendBadge extends StatelessWidget {
  const _LegendBadge({required this.text, this.risk});

  final String text;
  final int? risk;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = risk == null ? null : riskColor(risk!);

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: color == null
              ? theme.colorScheme.surfaceContainerHighest
              : color.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          text,
          style: theme.textTheme.labelSmall?.copyWith(
            fontSize: 10.5,
            fontWeight: color == null ? null : FontWeight.w700,
            color: color ?? theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

class _EmptyWatchlist extends StatelessWidget {
  const _EmptyWatchlist();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.star_border,
              size: 44,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 12),
            Text(
              'İzleme listen boş.\nTüm Liste sekmesinden yıldıza dokunarak ekle.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.fromLTRB(10, 8, 10, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(Icons.cloud_off, color: scheme.onErrorContainer, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: scheme.onErrorContainer),
            ),
          ),
        ],
      ),
    );
  }
}
