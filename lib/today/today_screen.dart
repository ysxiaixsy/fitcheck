import 'package:flutter/material.dart';

import '../theme/fitcheck_theme.dart';
import '../wardrobe/wardrobe_models.dart';
import '../widgets/common.dart';
import 'week_strip.dart';

class TodayScreen extends StatelessWidget {
  const TodayScreen({
    super.key,
    required this.onAddClothes,
    required this.onAddFragrance,
    this.now,
    this.readyCategories = const {},
    this.occasionName,
  });
  final VoidCallback onAddClothes, onAddFragrance;
  final DateTime? now;
  final Set<ClothingCategory> readyCategories;
  final String? occasionName;
  @override
  Widget build(BuildContext context) {
    final colors = FitCheckColors.of(context),
        text = Theme.of(context).textTheme;
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
          TodayWeekStrip(date: now ?? DateTime.now()),
          const SizedBox(height: AppSpace.xxl),
          SurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Let’s add your clothes', style: text.titleLarge),
                const SizedBox(height: AppSpace.xs),
                Text(
                  occasionName == null
                      ? 'Add a top, a bottom, and shoes. Then FitCheck can pick your outfit every morning.'
                      : 'Add or wash the missing pieces for $occasionName. Only clean or worn clothes can be picked.',
                  style: text.bodyMedium?.copyWith(color: colors.secondary),
                ),
                const SizedBox(height: AppSpace.lg),
                for (final category in ClothingCategory.values) ...[
                  Row(
                    children: [
                      Container(
                        width: AppSize.touch,
                        height: AppSize.touch,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: colors.subtle,
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                        child: AppSvg(category.name, illustration: true),
                      ),
                      const SizedBox(width: AppSpace.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              category == ClothingCategory.top
                                  ? 'A top'
                                  : category == ClothingCategory.bottom
                                  ? 'A bottom'
                                  : 'Shoes',
                              style: text.labelLarge,
                            ),
                            Text(
                              readyCategories.contains(category)
                                  ? 'Ready'
                                  : occasionName == null
                                  ? 'Not added yet'
                                  : 'Needs a clean piece',
                              style: text.bodySmall?.copyWith(
                                color: colors.secondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (readyCategories.contains(category))
                        Icon(Icons.check_circle_outline, color: colors.success),
                    ],
                  ),
                  if (category != ClothingCategory.shoes)
                    const SizedBox(height: AppSpace.sm),
                ],
                const SizedBox(height: AppSpace.lg),
                FilledButton.icon(
                  onPressed: onAddClothes,
                  icon: AppSvg(
                    'plus',
                    color: colors.onAccent,
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
