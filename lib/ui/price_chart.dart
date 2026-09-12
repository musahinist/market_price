import 'package:flutter/material.dart';

import '../models/price_series.dart';

/// Dokunarak nokta seçilebilen basit çizgi grafiği.
class PriceChart extends StatefulWidget {
  const PriceChart({
    super.key,
    required this.series,
    required this.color,
    required this.onSelected,
  });

  final PriceSeries series;
  final Color color;

  /// Parmak grafiğin üzerindeyken seçilen indeks; bırakınca null.
  final ValueChanged<int?> onSelected;

  @override
  State<PriceChart> createState() => _PriceChartState();
}

class _PriceChartState extends State<PriceChart> {
  int? _selected;

  void _select(Offset position, double width) {
    final count = widget.series.values.length;
    if (count < 2) return;

    final ratio = (position.dx / width).clamp(0.0, 1.0);
    final index = (ratio * (count - 1)).round();
    if (index == _selected) return;

    setState(() => _selected = index);
    widget.onSelected(index);
  }

  void _clear() {
    if (_selected == null) return;
    setState(() => _selected = null);
    widget.onSelected(null);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (d) => _select(d.localPosition, constraints.maxWidth),
        onTapUp: (_) => _clear(),
        onTapCancel: _clear,
        onHorizontalDragStart: (d) =>
            _select(d.localPosition, constraints.maxWidth),
        onHorizontalDragUpdate: (d) =>
            _select(d.localPosition, constraints.maxWidth),
        onHorizontalDragEnd: (_) => _clear(),
        onHorizontalDragCancel: _clear,
        child: CustomPaint(
          size: Size.infinite,
          painter: _ChartPainter(
            series: widget.series,
            color: widget.color,
            selected: _selected,
            baselineColor: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
      ),
    );
  }
}

class _ChartPainter extends CustomPainter {
  _ChartPainter({
    required this.series,
    required this.color,
    required this.selected,
    required this.baselineColor,
  });

  final PriceSeries series;
  final Color color;
  final int? selected;
  final Color baselineColor;

  @override
  void paint(Canvas canvas, Size size) {
    final values = series.values;
    if (values.length < 2) return;

    // Serinin tamamı ve referans kapanış görünecek şekilde ölçekle.
    var low = series.min;
    var high = series.max;
    final base = series.previousClose;
    if (base > 0 && base < low) low = base;
    if (base > high) high = base;

    final span = (high - low) == 0 ? 1.0 : (high - low);
    final pad = span * 0.08;
    low -= pad;
    high += pad;

    double dx(int i) => i / (values.length - 1) * size.width;
    double dy(double v) => size.height - (v - low) / (high - low) * size.height;

    // Referans çizgisi (önceki kapanış).
    if (base > 0) {
      final y = dy(base);
      final dash = Paint()
        ..color = baselineColor
        ..strokeWidth = 1;
      for (var x = 0.0; x < size.width; x += 8) {
        canvas.drawLine(Offset(x, y), Offset(x + 4, y), dash);
      }
    }

    final path = Path()..moveTo(dx(0), dy(values[0]));
    for (var i = 1; i < values.length; i++) {
      path.lineTo(dx(i), dy(values[i]));
    }

    // Çizginin altını yumuşak bir dolguyla kapat.
    final fill = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
      fill,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color.withValues(alpha: 0.28), color.withValues(alpha: 0)],
        ).createShader(Offset.zero & size),
    );

    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeJoin = StrokeJoin.round,
    );

    final index = selected;
    if (index != null && index < values.length) {
      final x = dx(index);
      final y = dy(values[index]);
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        Paint()
          ..color = color.withValues(alpha: 0.5)
          ..strokeWidth = 1,
      );
      canvas.drawCircle(Offset(x, y), 4, Paint()..color = color);
    }
  }

  @override
  bool shouldRepaint(_ChartPainter old) =>
      old.series != series || old.selected != selected || old.color != color;
}
