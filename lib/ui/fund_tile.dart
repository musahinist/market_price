import 'package:flutter/material.dart';

import '../models/fund.dart';
import 'focus_cards.dart';
import 'formats.dart';

/// Getiri hücrelerinin genişliği; satırların hizalı görünmesini sağlar.
const double _valueColumn = 58;

/// Fon sekmesindeki satır: kod, kısa ad, dönem getirileri.
///
/// Fonlar günde bir fiyatlandığı için anlık fiyat yerine getiriyi öne alıyoruz.
class FundTile extends StatelessWidget {
  const FundTile({
    super.key,
    required this.fund,
    required this.watched,
    required this.onTap,
    required this.onWatchToggle,
  });

  final Fund fund;
  final bool watched;
  final VoidCallback onTap;
  final VoidCallback onWatchToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final monthly = fund.periodReturn(FundPeriod.m1.key);
    final ytd = fund.periodReturn(FundPeriod.ytd.key);
    final yearly = fund.periodReturn(FundPeriod.y1.key);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      child: Material(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 7, 6, 7),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Rozetler dar ekranda alt satıra insin; Row taşardı.
                      Wrap(
                        spacing: 5,
                        runSpacing: 2,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            fund.code,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                          // Kısaltmalar tek satıra sığsın; anlamları AppBar'daki
                          // bilgi düğmesinde ve dokununca ipucunda.
                          if (fund.risk != null)
                            _Badge(
                              text: 'R${fund.risk}',
                              tooltip: 'Risk ${fund.risk} / 7',
                              color: riskColor(fund.risk!),
                            ),
                          if (fund.umbrellaLabel != null)
                            _Badge(
                              text: fund.umbrellaLabel!,
                              tooltip: fund.umbrella,
                            ),
                          if (!fund.onTefas)
                            const _Badge(
                              text: 'TD',
                              tooltip: 'TEFAS dışı · yalnızca kurucu kanalları',
                            ),
                        ],
                      ),
                      Text(
                        fund.shortName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Getiriler sabit genişlikte: satırlar arasında sütun gibi hizalansın.
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    SizedBox(
                      width: _valueColumn * 2,
                      child: Text(
                        monthly == null ? '—' : formatPercent(monthly),
                        textAlign: TextAlign.right,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          height: 1.1,
                          color: (monthly ?? 0) >= 0 ? kUp : kDown,
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        _Metric(label: 'yıl', value: ytd),
                        _Metric(label: '1y', value: yearly),
                      ],
                    ),
                  ],
                ),
                const SizedBox(width: 2),
                IconButton(
                  onPressed: onWatchToggle,
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 30,
                    minHeight: 30,
                  ),
                  icon: Icon(
                    watched ? Icons.star_rounded : Icons.star_border_rounded,
                    size: 20,
                    color: watched
                        ? const Color(0xFFF0B90B)
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                  tooltip: watched ? 'İzlemeden çıkar' : 'İzlemeye ekle',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Sabit genişlikte, sağa yaslı getiri hücresi.
class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});

  final String label;
  final double? value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: _valueColumn,
      child: Text(
        value == null
            ? '$label —'
            : '$label %${shortPercentFormat.format(value)}',
        textAlign: TextAlign.right,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodySmall?.copyWith(
          fontSize: 11,
          height: 1.2,
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.text, this.tooltip, this.color});

  final String text;
  final String? tooltip;

  /// Doluysa rozet bu renge boyanır (risk seviyesi).
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tint = color;
    final badge = Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: tint == null
            ? theme.colorScheme.surfaceContainerHighest
            : tint.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: theme.textTheme.labelSmall?.copyWith(
          fontSize: 9.5,
          fontWeight: tint == null ? null : FontWeight.w700,
          color: tint ?? theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );

    return tooltip == null ? badge : Tooltip(message: tooltip!, child: badge);
  }
}
