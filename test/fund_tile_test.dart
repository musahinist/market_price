import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:market_price/models/fund.dart';
import 'package:market_price/ui/fund_tile.dart';

/// Fon satırında kod + risk + şemsiye + TEFAS rozeti yan yana gelebiliyor;
/// dar ekranda taşmamalı.
void main() {
  final crowded = Fund(
    code: 'GUC',
    title: 'GARANTİ PORTFÖY ÜÇÜNCÜ PARA PİYASASI SERBEST (TL) ÖZEL FON',
    returns: {'getiri1a': 3.2794, 'getiriyb': 30.8, 'getiri1y': 48.0},
    risk: 2,
    umbrella: 'Serbest Şemsiye Fonu',
    onTefas: false,
  );

  Future<void> pump(WidgetTester tester, double width) async {
    tester.view.physicalSize = Size(width, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView(
            children: [
              FundTile(
                fund: crowded,
                watched: false,
                onTap: () {},
                onWatchToggle: () {},
              ),
            ],
          ),
        ),
      ),
    );
  }

  testWidgets('rozetler kodla aynı satırda kalır', (tester) async {
    // 360 dp güncel telefonlarda en dar hâli.
    await pump(tester, 360);

    expect(tester.takeException(), isNull);
    expect(find.text('GUC'), findsOneWidget);
    expect(find.text('R2'), findsOneWidget);
    expect(find.text('S'), findsOneWidget);
    expect(find.text('TD'), findsOneWidget);

    // Kısaltmalar kodla aynı satırda kalmalı; uzun etiketler satırı taşırıyordu.
    final codeTop = tester.getTopLeft(find.text('GUC')).dy;
    for (final badge in ['R2', 'S', 'TD']) {
      expect(tester.getTopLeft(find.text(badge)).dy, closeTo(codeTop, 6));
    }
  });

  testWidgets('çok dar ekranda alt satıra iner ama taşmaz', (tester) async {
    await pump(tester, 300);
    expect(tester.takeException(), isNull);
    expect(find.text('TD'), findsOneWidget);
  });

  testWidgets('geniş ekranda da tek satırda durur', (tester) async {
    await pump(tester, 500);
    expect(tester.takeException(), isNull);
    expect(find.text('Garanti Portföy Üçüncü'), findsOneWidget);
    expect(find.text('%+3,28'), findsOneWidget);
  });

  testWidgets('getiri sütunları satırlar arasında aynı hizada', (tester) async {
    final withAll = crowded;
    final missing = Fund(
      code: 'DAP',
      title: 'DESTEK PORTFÖY PARA PİYASASI (TL) FONU',
      returns: {'getiri1a': 3.56},
    );

    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView(
            children: [
              for (final fund in [withAll, missing])
                FundTile(
                  fund: fund,
                  watched: false,
                  onTap: () {},
                  onWatchToggle: () {},
                ),
            ],
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);

    // Veri eksik olan satırda da hücreler yerinde durur.
    expect(find.text('yıl —'), findsOneWidget);
    expect(find.text('1y —'), findsOneWidget);

    // İki satırın yüzde metinleri aynı sağ kenarda bitmeli.
    final rights = [
      '%+3,28',
      '%+3,56',
    ].map((t) => tester.getBottomRight(find.text(t)).dx).toList();
    expect(rights[0], closeTo(rights[1], 0.5));
  });

  testWidgets('risk rozeti seviyeye göre renklenir', (tester) async {
    Color badgeColor(WidgetTester t, String text) {
      final box = t.widget<Container>(
        find
            .ancestor(of: find.text(text), matching: find.byType(Container))
            .first,
      );
      return ((box.decoration as BoxDecoration).color)!;
    }

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView(
            children: [
              for (final (code, risk) in [('AAA', 1), ('BBB', 4), ('CCC', 7)])
                FundTile(
                  fund: Fund(
                    code: code,
                    title: 'X PORTFÖY PARA PİYASASI (TL) FONU',
                    returns: const {'getiri1a': 1},
                    risk: risk,
                  ),
                  watched: false,
                  onTap: () {},
                  onWatchToggle: () {},
                ),
            ],
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    // Üç seviye üç ayrı renk vermeli.
    final colors = ['R1', 'R4', 'R7'].map((t) => badgeColor(tester, t)).toSet();
    expect(colors, hasLength(3));
  });
}
