import 'package:flutter/material.dart';

import '../theme/fitcheck_theme.dart';
import '../widgets/common.dart';

class TodayScreen extends StatelessWidget {
  const TodayScreen({
    super.key,
    required this.onAddClothes,
    required this.onAddFragrance,
    this.now,
  });
  final VoidCallback onAddClothes, onAddFragrance;
  final DateTime? now;
  @override
  Widget build(BuildContext context) {
    final c = FitCheckColors.of(context), text = Theme.of(context).textTheme;
    final today = dateOnly(now ?? DateTime.now());
    final monday = DateTime(
      today.year,
      today.month,
      today.day - today.weekday + 1,
    );
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        AppSpace.lg,
        AppSpace.sm,
        AppSpace.lg,
        AppSpace.xxl,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: List.generate(7, (i) {
              final date = DateTime(monday.year, monday.month, monday.day + i);
              final selected = date == today;
              return Expanded(
                child: Semantics(
                  label: readableDate(date),
                  selected: selected,
                  child: ExcludeSemantics(
                    child: Column(
                      children: [
                        Text(
                          weekdayNames[i],
                          style: text.labelSmall?.copyWith(
                            color: selected ? c.accent : c.secondary,
                          ),
                        ),
                        const SizedBox(height: AppSpace.xs),
                        Container(
                          width: AppSize.dateCircle,
                          height: AppSize.dateCircle,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: selected ? c.accent : null,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            '${date.day}',
                            style:
                                (selected ? text.labelLarge : text.bodyMedium)
                                    ?.copyWith(
                                      color: selected ? c.onAccent : c.primary,
                                    ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: AppSpace.xxl),
          SurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Let’s add your clothes', style: text.titleLarge),
                const SizedBox(height: AppSpace.xs),
                Text(
                  'Add a top, a bottom, and shoes. Then FitCheck can pick your outfit every morning.',
                  style: text.bodyMedium?.copyWith(color: c.secondary),
                ),
                const SizedBox(height: AppSpace.lg),
                for (final entry in [
                  ('top', 'A top'),
                  ('bottom', 'A bottom'),
                  ('shoes', 'Shoes'),
                ]) ...[
                  Row(
                    children: [
                      Container(
                        width: AppSize.touch,
                        height: AppSize.touch,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: c.subtle,
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                        child: AppSvg(entry.$1, illustration: true),
                      ),
                      const SizedBox(width: AppSpace.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(entry.$2, style: text.labelLarge),
                            Text(
                              'Not added yet',
                              style: text.bodySmall?.copyWith(
                                color: c.secondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (entry.$1 != 'shoes') const SizedBox(height: AppSpace.sm),
                ],
                const SizedBox(height: AppSpace.lg),
                FilledButton.icon(
                  onPressed: onAddClothes,
                  icon: AppSvg(
                    'plus',
                    color: c.onAccent,
                    size: AppSize.iconMedium,
                  ),
                  label: const Text('Add clothes'),
                ),
                const SizedBox(height: AppSpace.xs),
                TextButton(
                  onPressed: onAddFragrance,
                  child: const Text('Add a fragrance (optional)'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
