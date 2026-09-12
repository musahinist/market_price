import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:market_price/data/asset_catalog.dart';
import 'package:market_price/models/quote.dart';
import 'package:market_price/ui/focus_cards.dart';

/// Odak kartları kaydırma listesinin içinde yaşıyor; orada yükseklik sınırsız
/// olduğu için yanlış bir çapraz hizalama tüm sekmeyi boş bırakıyordu.
void main() {
  final asset = kAssets.firstWhere((a) => a.id == 'gold_gram');
  final quote = Quote(
    price: 6798.5,
    changePercent: 0.15,
    currency: 'TRY',
    time: DateTime(2026, 9, 12),
    dayLow: 6750,
    dayHigh: 6820,
    weekLow: 4100,
    weekHigh: 7000,
    previousClose: 6788,
  );

  Widget wrap(Widget child) => MaterialApp(
    home: Scaffold(
      body: CustomScrollView(slivers: [SliverToBoxAdapter(child: child)]),
    ),
  );

  testWidgets('ikincil kart satırı sınırsız yükseklikte taşmaz', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        SecondaryFocusRow(
          slots: [
            SecondaryFocusCard(
              asset: asset,
              quote: quote,
              onTap: () {},
              onChange: () {},
            ),
            SecondaryFocusCard(
              asset: asset,
              quote: null,
              onTap: () {},
              onChange: () {},
            ),
          ],
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('Gram Altın'), findsNWidgets(2));

    // İki kart eşit ve kare olmalı.
    final cards = tester.widgetList<AspectRatio>(find.byType(AspectRatio));
    expect(cards.length, 2);
    final sizes = find
        .byType(SecondaryFocusCard)
        .evaluate()
        .map((e) => tester.getSize(find.byWidget(e.widget)))
        .toList();
    expect(sizes[0], sizes[1]);
    expect(sizes[0].width, closeTo(sizes[0].height, 0.5));
  });

  testWidgets('odak kartı gün ve 52 hafta aralığını gösterir', (tester) async {
    await tester.pumpWidget(
      wrap(
        PrimaryFocusCard(
          asset: asset,
          quote: quote,
          onTap: () {},
          onChange: () {},
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('Gün'), findsOneWidget);
    expect(find.text('52h'), findsOneWidget);
    expect(find.textContaining('6.798,50'), findsOneWidget);
    expect(find.text('%+0,15'), findsOneWidget);
  });

  testWidgets('fiyat yoksa kart çökmez', (tester) async {
    await tester.pumpWidget(
      wrap(
        PrimaryFocusCard(
          asset: asset,
          quote: null,
          onTap: () {},
          onChange: () {},
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('—'), findsOneWidget);
  });
}
