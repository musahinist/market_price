import 'package:intl/intl.dart';

/// Paylaşılan sayı biçimlendiricileri.
///
/// `NumberFormat` kurulumu pahalıdır (yerel veri + kalıp ayrıştırma); liste
/// satırlarında her çizimde yeniden yaratmak kaydırmayı takıyordu.
final NumberFormat percentFormat = NumberFormat('+0.00;-0.00', 'tr_TR');
final NumberFormat shortPercentFormat = NumberFormat('0.0', 'tr_TR');
final NumberFormat integerFormat = NumberFormat.decimalPattern('tr_TR');

final Map<int, NumberFormat> _decimalFormats = {};

/// [digits] ondalıklı, binlik ayraçlı biçimlendirici.
NumberFormat decimalFormat(int digits) => _decimalFormats.putIfAbsent(
  digits,
  () =>
      NumberFormat.decimalPatternDigits(locale: 'tr_TR', decimalDigits: digits),
);
