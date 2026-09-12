import 'package:flutter/material.dart';

import '../models/asset.dart';
import '../models/quote.dart';
import 'formats.dart';

class AssetTile extends StatelessWidget {
  const AssetTile({
    super.key,
    required this.asset,
    required this.quote,
    this.dragIndex,
    this.onTap,
    this.watched,
    this.onWatchToggle,
  });

  final Asset asset;
  final Quote? quote;

  /// Doluysa satırın sağında sürükleme tutamacı gösterilir (sıralama modu).
  final int? dragIndex;

  final VoidCallback? onTap;

  /// Doluysa satırın sağında izleme listesi yıldızı gösterilir.
  final bool? watched;
  final VoidCallback? onWatchToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final q = quote;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      child: Material(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            child: Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    shape: BoxShape.circle,
                  ),
                  child: Text(asset.icon, style: const TextStyle(fontSize: 14)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    asset.name,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (q == null)
                  Text(
                    '—',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.disabledColor,
                    ),
                  )
                else
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        _formatPrice(q.price, asset),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          height: 1.1,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                      _ChangeChip(changePercent: q.changePercent),
                    ],
                  ),
                if (watched != null) ...[
                  const SizedBox(width: 2),
                  IconButton(
                    onPressed: onWatchToggle,
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 34,
                      minHeight: 34,
                    ),
                    icon: Icon(
                      watched! ? Icons.star_rounded : Icons.star_border_rounded,
                      size: 21,
                      color: watched!
                          ? const Color(0xFFF0B90B)
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                    tooltip: watched! ? 'İzlemeden çıkar' : 'İzlemeye ekle',
                  ),
                ],
                if (dragIndex != null) ...[
                  const SizedBox(width: 6),
                  ReorderableDragStartListener(
                    index: dragIndex!,
                    child: Icon(
                      Icons.drag_handle,
                      size: 20,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatPrice(double price, Asset asset) {
    // Çok küçük fiyatlarda daha fazla basamak göster.
    var decimals = asset.decimals;
    if (price < 1 && decimals < 4) decimals = 4;

    final formatted = decimalFormat(decimals).format(price);

    return '${asset.unit}$formatted${asset.suffix}';
  }
}

class _ChangeChip extends StatelessWidget {
  const _ChangeChip({required this.changePercent});

  final double changePercent;

  @override
  Widget build(BuildContext context) {
    final up = changePercent >= 0;
    final color = up ? const Color(0xFF16C784) : const Color(0xFFEA3943);
    final text = percentFormat.format(changePercent);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          up ? Icons.arrow_drop_up : Icons.arrow_drop_down,
          size: 14,
          color: color,
        ),
        Text(
          '%$text',
          style: TextStyle(
            color: color,
            fontSize: 11.5,
            height: 1.1,
            fontWeight: FontWeight.w600,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}
