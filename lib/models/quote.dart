/// Bir varlığın anlık fiyat bilgisi.
class Quote {
  const Quote({
    required this.price,
    required this.changePercent,
    required this.currency,
    required this.time,
    this.dayLow,
    this.dayHigh,
    this.weekLow,
    this.weekHigh,
    this.previousClose,
  });

  final double price;
  final double changePercent;
  final String currency;
  final DateTime time;

  final double? dayLow;
  final double? dayHigh;
  final double? weekLow;
  final double? weekHigh;
  final double? previousClose;

  bool get isUp => changePercent >= 0;

  /// Fiyatın gün aralığındaki yeri (0 = dip, 1 = tepe). Aralık yoksa null.
  double? get dayPosition => _positionIn(dayLow, dayHigh);

  /// Fiyatın 52 haftalık aralıktaki yeri.
  double? get weekPosition => _positionIn(weekLow, weekHigh);

  double? _positionIn(double? low, double? high) {
    if (low == null || high == null || high <= low) return null;
    return ((price - low) / (high - low)).clamp(0.0, 1.0);
  }

  /// Fiyat alanlarını [factor] ile çarpar (ör. USD -> TL).
  ///
  /// [previousClose] verilirse ölçeklenmiş değerin yerine o kullanılır.
  ///
  /// [keepWeekRange] false verilirse 52 haftalık aralık düşürülür: uzun vadeli
  /// bir aralığı bugünkü kurla çevirmek yanıltıcı olur.
  Quote scaledBy(
    double factor, {
    double? changePercent,
    String? currency,
    bool keepWeekRange = true,
    double? previousClose,
  }) {
    double? scale(double? v) => v == null ? null : v * factor;
    return Quote(
      price: price * factor,
      changePercent: changePercent ?? this.changePercent,
      currency: currency ?? this.currency,
      time: time,
      dayLow: scale(dayLow),
      dayHigh: scale(dayHigh),
      weekLow: keepWeekRange ? scale(weekLow) : null,
      weekHigh: keepWeekRange ? scale(weekHigh) : null,
      previousClose: previousClose ?? scale(this.previousClose),
    );
  }
}
