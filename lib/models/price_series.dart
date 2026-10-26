/// Bir zaman aralığındaki fiyat serisi.
class PriceSeries {
  const PriceSeries({
    required this.times,
    required this.values,
    required this.currency,
    required this.previousClose,
  });

  final List<DateTime> times;
  final List<double> values;
  final String currency;

  /// Aralığın başlangıç referansı; yüzde değişim bundan hesaplanır.
  final double previousClose;

  bool get isEmpty => values.isEmpty;

  double get min => values.reduce((a, b) => a < b ? a : b);
  double get max => values.reduce((a, b) => a > b ? a : b);

  double get changePercent {
    final base = previousClose != 0 ? previousClose : values.first;
    if (base == 0) return 0;
    return (values.last - base) / base * 100;
  }

  /// Bu seriyi [fx] kuruyla noktası noktasına çarpıp [divisor]'e böler.
  ///
  /// Ons USD serisini gram TL'ye çevirmek için kullanılır. Tek bir güncel kurla
  /// çarpmak geçmişi bozar; her noktaya o tarihteki kur uygulanır.
  PriceSeries convertedWith(PriceSeries fx, {double divisor = 1}) =>
      PriceSeries(
        times: times,
        values: [
          for (var i = 0; i < values.length; i++)
            values[i] * fx.rateAt(times[i]) / divisor,
        ],
        currency: fx.currency,
        previousClose: previousClose * fx.previousClose / divisor,
      );

  /// Bu serinin kapsamadığı baş kısmı [older]'dan tamamlar.
  ///
  /// Vadeli kontratın kendi geçmişi pencereden kısa kaldığında kullanılır:
  /// [older]'ın bu serinin ilk noktasından önceki kısmı, ek yerinde iki seri
  /// buluşacak şekilde oranlanıp başa eklenir. Ek yerindeki sıçrama
  /// kontrat devrinden geldiği için gerçek değil, oranlama onu siler.
  PriceSeries extendedWith(PriceSeries older) {
    if (isEmpty || older.isEmpty) return this;
    final start = times.first;
    final head = [
      for (var i = 0; i < older.times.length; i++)
        if (older.times[i].isBefore(start)) i,
    ];
    if (head.isEmpty) return this;

    final junction = older.rateAt(start);
    if (junction == 0) return this;
    final ratio = values.first / junction;

    return PriceSeries(
      times: [for (final i in head) older.times[i], ...times],
      values: [for (final i in head) older.values[i] * ratio, ...values],
      currency: currency,
      previousClose: older.previousClose * ratio,
    );
  }

  /// [time] anındaki kur: o ana kadarki son bilinen değer.
  double rateAt(DateTime time) {
    if (values.isEmpty) return 0;
    if (!time.isAfter(times.first)) return values.first;

    // Zaman damgaları artan sırada; son (<= time) noktayı ikili aramayla bul.
    var low = 0;
    var high = times.length - 1;
    while (low < high) {
      final mid = (low + high + 1) ~/ 2;
      if (times[mid].isAfter(time)) {
        high = mid - 1;
      } else {
        low = mid;
      }
    }
    return values[low];
  }
}

/// Grafikte seçilebilen zaman aralıkları.
enum ChartRange {
  d1('1G', '1d', '5m'),
  w1('1H', '5d', '15m'),
  m1('1A', '1mo', '1d'),
  m6('6A', '6mo', '1d'),
  y1('1Y', '1y', '1d'),
  y5('5Y', '5y', '1wk');

  const ChartRange(this.label, this.range, this.interval);

  final String label;
  final String range;
  final String interval;
}
