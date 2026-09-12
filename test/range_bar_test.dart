import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:market_price/models/price_series.dart';
import 'package:market_price/ui/range_bar.dart';

void main() {
  testWidgets('seçili aralık belirgin, diğerleri soluk', (tester) async {
    ChartRange? tapped;

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF16C784),
            brightness: Brightness.dark,
          ),
        ),
        home: Scaffold(
          body: RangeBar(
            selected: ChartRange.y1,
            onSelected: (range) => tapped = range,
          ),
        ),
      ),
    );

    Color colorOf(String label) =>
        tester.widget<Text>(find.text(label)).style!.color!;
    FontWeight weightOf(String label) =>
        tester.widget<Text>(find.text(label)).style!.fontWeight!;

    final primary = Theme.of(tester.element(find.text('1Y')))
        .colorScheme
        .primary;

    expect(colorOf('1Y'), primary);
    expect(weightOf('1Y'), FontWeight.w800);

    // Seçili olmayanlar hem soluk hem ince.
    expect(colorOf('1G').a, lessThan(0.6));
    expect(weightOf('1G'), FontWeight.w500);
    expect(colorOf('1G'), isNot(primary));

    await tester.tap(find.text('6A'));
    expect(tapped, ChartRange.m6);
  });
}
