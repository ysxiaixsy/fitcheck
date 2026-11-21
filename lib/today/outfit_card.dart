import 'package:flutter/material.dart';

import '../outfits/outfit_picker.dart';
import '../theme/fitcheck_theme.dart';
import '../wardrobe/wardrobe_models.dart';
import '../widgets/common.dart';

abstract final class OutfitMetrics {
  static const double tileImageHeight = 64;
  static const double tileIllustration = 48;
  static const double swapGlyph = 14;
  static const double optionImage = 56;
  static const double optionIllustration = 44;
  static const double detailImage = 112;
  static const double detailIllustration = 80;
}

/// A controlled card: the caller owns the suggested/worn state and mutations.
class OutfitCard extends StatelessWidget {
  const OutfitCard({
    super.key,
    required this.outfit,
    required this.onWear,
    required this.onSwapAll,
    required this.onSwapItem,
    required this.onViewOutfit,
    this.busy = false,
    this.worn = false,
    this.error,
  });

  final OutfitSuggestion outfit;
  final VoidCallback? onWear, onSwapAll;
  final ValueChanged<ClothingItem>? onSwapItem;
  final VoidCallback onViewOutfit;
  final bool busy, worn;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final c = FitCheckColors.of(context);
    final text = Theme.of(context).textTheme;
    final canChange = !busy && !worn;
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.xl),
        side: BorderSide(color: c.border),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpace.lg,
          AppSpace.lg,
          AppSpace.lg,
          AppSpace.xs,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Outfit of the day', style: text.titleLarge),
            const SizedBox(height: AppSpace.xs),
            OutfitReason(outfit.reason),
            const SizedBox(height: AppSpace.md),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < outfit.pieces.length; i++) ...[
                  if (i != 0) const SizedBox(width: AppSpace.sm),
                  Expanded(
                    child: _PieceTile(
                      item: outfit.pieces[i],
                      onPressed: canChange && onSwapItem != null
                          ? () => onSwapItem!(outfit.pieces[i])
                          : null,
                    ),
                  ),
                ],
              ],
            ),
            if (error != null) ...[
              const SizedBox(height: AppSpace.md),
              InlineMessage(error!, isError: true),
            ],
            const SizedBox(height: AppSpace.md),
            FilledButton.icon(
              onPressed: canChange ? onWear : null,
              icon: AppSvg(
                'outfit_check',
                color: c.onAccent,
                size: AppSize.iconMedium,
              ),
              label: Text(
                busy
                    ? 'Saving outfit…'
                    : worn
                    ? 'Worn today'
                    : 'Wear this',
              ),
            ),
            const SizedBox(height: AppSpace.xs),
            Row(
              children: [
                Expanded(
                  child: TextButton.icon(
                    onPressed: canChange ? onSwapAll : null,
                    icon: AppSvg(
                      'outfit_shuffle',
                      color: c.accent,
                      size: AppSize.iconMedium,
                    ),
                    label: const Text('Swap all'),
                  ),
                ),
                const SizedBox(width: AppSpace.sm),
                Expanded(
                  child: TextButton(
                    onPressed: onViewOutfit,
                    child: const Text('View outfit'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class OutfitReason extends StatelessWidget {
  const OutfitReason(this.reason, {super.key});
  final String reason;

  @override
  Widget build(BuildContext context) {
    final c = FitCheckColors.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: AppSpace.xxs),
          child: AppSvg(
            'outfit_sparkles',
            color: c.accent,
            size: AppSize.iconSmall,
          ),
        ),
        const SizedBox(width: AppSpace.xs),
        Expanded(
          child: Text(
            reason,
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: c.secondary),
          ),
        ),
      ],
    );
  }
}

class _PieceTile extends StatelessWidget {
  const _PieceTile({required this.item, required this.onPressed});
  final ClothingItem item;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final c = FitCheckColors.of(context);
    final text = Theme.of(context).textTheme;
    return Semantics(
      button: onPressed != null,
      label:
          '${onPressed == null ? '' : 'Swap ${item.category.label.toLowerCase()}: '}${item.name}, ${item.colorName}, ${item.laundryStatus.label}',
      onTap: onPressed,
      excludeSemantics: true,
      child: InkWell(
        key: ValueKey('outfit-item-${item.id}'),
        onTap: onPressed,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Stack(
              children: [
                OutfitPieceImage(
                  item: item,
                  height: OutfitMetrics.tileImageHeight,
                  illustrationSize: OutfitMetrics.tileIllustration,
                ),
                if (onPressed != null)
                  Positioned(
                    top: AppSpace.xs,
                    right: AppSpace.xs,
                    child: Container(
                      width: AppSize.icon,
                      height: AppSize.icon,
                      decoration: BoxDecoration(
                        color: c.surface,
                        border: Border.all(color: c.border),
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                      alignment: Alignment.center,
                      child: AppSvg(
                        'outfit_badge_shuffle',
                        color: c.primary,
                        size: OutfitMetrics.swapGlyph,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppSpace.sm),
            Text(
              item.category.label,
              style: text.labelSmall?.copyWith(color: c.secondary),
            ),
            const SizedBox(height: AppSpace.xxs),
            Text(
              item.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: text.labelMedium,
            ),
            const SizedBox(height: AppSpace.xxs),
            Text(
              item.colorName,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: text.bodySmall?.copyWith(color: c.secondary),
            ),
          ],
        ),
      ),
    );
  }
}

/// A dynamic photo or the existing Figma category illustration.
class OutfitPieceImage extends StatelessWidget {
  const OutfitPieceImage({
    super.key,
    required this.item,
    required this.height,
    required this.illustrationSize,
    this.width = double.infinity,
    this.radius = AppRadius.md,
  });
  final ClothingItem item;
  final double width, height, illustrationSize, radius;

  @override
  Widget build(BuildContext context) {
    Widget placeholder() => Center(
      child: AppSvg(
        item.category.name,
        illustration: true,
        size: illustrationSize,
      ),
    );
    return ExcludeSemantics(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: SizedBox(
          width: width,
          height: height,
          child: ColoredBox(
            color: FitCheckColors.of(context).subtle,
            child: item.photoUrl == null
                ? placeholder()
                : Image.network(
                    item.photoUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => placeholder(),
                  ),
          ),
        ),
      ),
    );
  }
}
