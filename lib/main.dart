import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'services/range_store.dart';
import 'ui/home_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Grafikteki tarih etiketleri Türkçe olsun.
  initializeDateFormatting('tr');
  // Son seçilen grafik aralığı ilk çizimden önce hazır olsun.
  await ChartRangeSetting.load();

  runApp(const MarketPriceApp());
}

class MarketPriceApp extends StatelessWidget {
  const MarketPriceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Piyasa',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF16C784),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}
