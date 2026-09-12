import 'package:flutter/material.dart';

import '../models/asset.dart';
import '../models/quote.dart';
import 'formats.dart';

const kUp = Color(0xFF16C784);
const kDown = Color(0xFFEA3943);

String formatPrice(Asset asset, double value) {
  var decimals = asset.decimals;
  if (value.abs() < 1 && decimals < 4) decimals = 4;
  final text = decimalFormat(decimals).format(value);
  return '${asset.unit}$text${asset.suffix}';
}

String formatPercent(double value) => '%${percentFormat.format(value)}';

/// İzleme sekmesinin başındaki büyük odak kartı: fiyat + gün/52 hafta verileri.
class PrimaryFocusCard extends StatelessWidget {
  const PrimaryFocusCard({
    super.key,
    required this.asset,
    required this.quote,
    required this.onTap,
    required this.onChange,
  });

  final Asset asset;
  final Quote? quote;
  final VoidCallback onTap;

  /// Kartta gösterilecek varlığı seçtirir.
  final VoidCallback onChange;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final q = quote;
    final color = (q?.changePercent ?? 0) >= 0 ? kUp : kDown;

    return Card(
      margin: const EdgeInsets.fromLTRB(10, 0, 10, 6),
      color: theme.colorScheme.surfaceContainerHigh,
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 10, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(asset.icon, style: const TextStyle(fontSize: 14)),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      asset.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  _ChangeButton(onPressed: onChange),
                  Icon(
                    Icons.chevron_right,
                    size: 18,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
              if (q == null)
                Text('—', style: theme.textTheme.headlineSmall)
              else ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      formatPrice(asset, q.price),
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      formatPercent(q.changePercent),
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: color,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    if (q.previousClose != null)
                      Flexible(
                        child: Text(
                          'Önc. ${formatPrice(asset, q.previousClose!)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                _RangeStrip(
                  label: 'Gün',
                  low: q.dayLow,
                  high: q.dayHigh,
                  position: q.dayPosition,
                  asset: asset,
                  color: color,
                ),
                const SizedBox(height: 5),
                _RangeStrip(
                  label: '52h',
                  low: q.weekLow,
                  high: q.weekHigh,
                  position: q.weekPosition,
                  asset: asset,
                  color: theme.colorScheme.primary,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Alt/üst sınırı ve fiyatın aralıktaki yerini gösteren şerit.
class _RangeStrip extends StatelessWidget {
  const _RangeStrip({
    required this.label,
    required this.low,
    required this.high,
    required this.position,
    required this.asset,
    required this.color,
  });

  final String label;
  final double? low;
  final double? high;
  final double? position;
  final Asset asset;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (low == null || high == null) return const SizedBox.shrink();

    final style = theme.textTheme.bodySmall?.copyWith(
      fontSize: 11.5,
      color: theme.colorScheme.onSurfaceVariant,
    );

    return Row(
      children: [
        SizedBox(width: 34, child: Text(label, style: style)),
        Text(formatPrice(asset, low!), style: style),
        const SizedBox(width: 8),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) => SizedBox(
              height: 5,
              child: Stack(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  if (position != null)
                    Positioned(
                      left: (constraints.maxWidth - 5) * position!,
                      child: Container(
                        width: 5,
                        height: 5,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(formatPrice(asset, high!), style: style),
      ],
    );
  }
}

/// Odak altındaki iki kare karttan biri: grafiksiz, listeden daha ayrıntılı.
class SecondaryFocusCard extends StatelessWidget {
  const SecondaryFocusCard({
    super.key,
    required this.asset,
    required this.quote,
    required this.onTap,
    required this.onChange,
  });

  final Asset asset;
  final Quote? quote;
  final VoidCallback onTap;

  /// Kartta gösterilecek varlığı seçtirir.
  final VoidCallback onChange;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final q = quote;
    final color = (q?.changePercent ?? 0) >= 0 ? kUp : kDown;

    final muted = theme.textTheme.bodySmall?.copyWith(
      fontSize: 11,
      color: theme.colorScheme.onSurfaceVariant,
    );

    return Card(
      margin: EdgeInsets.zero,
      color: theme.colorScheme.surfaceContainerHigh,
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(asset.icon, style: const TextStyle(fontSize: 13)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      asset.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  _ChangeButton(onPressed: onChange),
                ],
              ),
              const Spacer(),
              Text(
                q == null ? '—' : formatPrice(asset, q.price),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              if (q != null)
                Text(
                  formatPercent(q.changePercent),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              const Spacer(),
              if (q?.dayLow != null && q?.dayHigh != null) ...[
                Text(
                  'Gün ${formatPrice(asset, q!.dayLow!)} — '
                  '${formatPrice(asset, q.dayHigh!)}',
                  style: muted,
                ),
              ],
              if (q?.weekLow != null && q?.weekHigh != null)
                Text(
                  '52h ${formatPrice(asset, q!.weekLow!)} — '
                  '${formatPrice(asset, q.weekHigh!)}',
                  style: muted,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Karttaki varlığı değiştirmek için küçük düğme.
class _ChangeButton extends StatelessWidget {
  const _ChangeButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
      tooltip: 'Varlığı değiştir',
      icon: Icon(
        Icons.swap_horiz,
        size: 18,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }
}

/// Yan yana iki ikincil kart.
///
/// Kaydırma listesinde yükseklik sınırsız olduğu için satırın çapraz eksende
/// esnememesi şart; kartların boyunu [AspectRatio] belirler.
class SecondaryFocusRow extends StatelessWidget {
  const SecondaryFocusRow({super.key, required this.slots});

  /// Her yuva için kart ya da boş yuva widget'ı.
  final List<Widget> slots;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 0, 10, 6),
      child: Row(
        children: [
          for (var i = 0; i < slots.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            Expanded(child: AspectRatio(aspectRatio: 1, child: slots[i])),
          ],
        ],
      ),
    );
  }
}

/// TEFAS risk değerinin (1-7) rengi: düşükten yükseğe.
Color riskColor(int risk) => switch (risk) {
  <= 2 => kUp,
  <= 4 => const Color(0xFFF0B90B),
  <= 6 => const Color(0xFFFF8A34),
  _ => kDown,
};
