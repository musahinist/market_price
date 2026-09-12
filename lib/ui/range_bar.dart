import 'package:flutter/material.dart';

import '../models/price_series.dart';

/// Grafik zaman aralığı seçici.
class RangeBar extends StatelessWidget {
  const RangeBar({super.key, required this.selected, required this.onSelected});

  final ChartRange selected;
  final ValueChanged<ChartRange> onSelected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          for (final range in ChartRange.values)
            Expanded(
              child: GestureDetector(
                onTap: () => onSelected(range),
                behavior: HitTestBehavior.opaque,
                child: _RangeChip(
                  label: range.label,
                  selected: range == selected,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Tek bir aralık düğmesi.
///
/// Seçili olan belirgin dursun diye seçili olmayanlar soluklaştırılıyor.
class _RangeChip extends StatelessWidget {
  const _RangeChip({required this.label, required this.selected});

  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 140),
      margin: const EdgeInsets.symmetric(horizontal: 3),
      padding: const EdgeInsets.symmetric(vertical: 8),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: selected
            ? scheme.primary.withValues(alpha: 0.22)
            : scheme.surfaceContainerHigh.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: selected
              ? scheme.primary.withValues(alpha: 0.75)
              : Colors.transparent,
        ),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
          color: selected
              ? scheme.primary
              : scheme.onSurfaceVariant.withValues(alpha: 0.5),
        ),
      ),
    );
  }
}
