import 'package:flutter/material.dart';

import '../outfits/outfit_picker.dart';
import '../theme/fitcheck_theme.dart';
import '../wardrobe/wardrobe_models.dart';
import '../wardrobe/wardrobe_screen.dart';
import '../widgets/common.dart';
import 'outfit_card.dart';

/// The caller supplies candidates filtered by the outfit picker's eligibility
/// rules. Dismissing the sheet returns null; confirming returns the selected item.
Future<ClothingItem?> showSwapItemSheet(
  BuildContext context, {
  required ClothingCategory category,
  required Occasion occasion,
  required List<ClothingItem> candidates,
  required String currentItemId,
}) => showModalBottomSheet<ClothingItem>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (_) => SwapItemsSheet(
    category: category,
    occasion: occasion,
    candidates: candidates,
    currentItemId: currentItemId,
  ),
);

class SwapItemsSheet extends StatefulWidget {
  const SwapItemsSheet({
    super.key,
    required this.category,
    required this.occasion,
    required this.candidates,
    required this.currentItemId,
  });
  final ClothingCategory category;
  final Occasion occasion;
  final List<ClothingItem> candidates;
  final String currentItemId;

  @override
  State<SwapItemsSheet> createState() => _SwapItemsSheetState();
}

class _SwapItemsSheetState extends State<SwapItemsSheet> {
  String? _selectedId;

  @override
  void initState() {
    super.initState();
    _selectInitial();
  }

  void _selectInitial() {
    _selectedId =
        widget.candidates.any((item) => item.id == widget.currentItemId)
        ? widget.currentItemId
        : null;
  }

  @override
  void didUpdateWidget(covariant SwapItemsSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.candidates.any((item) => item.id == _selectedId)) {
      _selectInitial();
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = FitCheckColors.of(context);
    final text = Theme.of(context).textTheme;
    final candidates = [
      ...widget.candidates.where((item) => item.id == widget.currentItemId),
      ...widget.candidates.where((item) => item.id != widget.currentItemId),
    ];
    final selected = candidates
        .where((item) => item.id == _selectedId)
        .firstOrNull;
    final confirmLabel = widget.category == ClothingCategory.shoes
        ? 'Use these shoes'
        : 'Use this ${widget.category.label.toLowerCase()}';
    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * .9,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpace.lg,
            AppSpace.sm,
            AppSpace.lg,
            AppSpace.xxxl,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: AppSize.illustration,
                  height: AppSpace.xs,
                  decoration: BoxDecoration(
                    color: c.borderStrong,
                    borderRadius: BorderRadius.circular(AppSpace.xxs),
                  ),
                ),
              ),
              const SizedBox(height: AppSpace.md),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Swap ${widget.category.label.toLowerCase()}',
                          style: text.titleLarge,
                        ),
                        const SizedBox(height: AppSpace.xxs),
                        Text(
                          'Available ${widget.category.plural.toLowerCase()} for ${widget.occasion.name}.',
                          style: text.bodySmall?.copyWith(color: c.secondary),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpace.sm),
                  IconButton(
                    tooltip: 'Close swap item',
                    onPressed: () => Navigator.pop(context),
                    icon: AppSvg('close', color: c.primary),
                  ),
                ],
              ),
              const SizedBox(height: AppSpace.md),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: candidates.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: AppSpace.sm),
                  itemBuilder: (context, index) {
                    final item = candidates[index];
                    final isSelected = item.id == _selectedId;
                    final current = item.id == widget.currentItemId;
                    void select() => setState(() => _selectedId = item.id);
                    return Semantics(
                      button: true,
                      selected: isSelected,
                      onTap: select,
                      excludeSemantics: true,
                      label:
                          '${item.name}, ${item.colorName}, ${item.laundryStatus.label}${current ? ', current pick' : ''}',
                      child: Material(
                        color: isSelected ? c.accentSubtle : c.surface,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          side: BorderSide(
                            color: isSelected ? c.accent : c.border,
                            width: isSelected ? AppSize.focus : AppSize.stroke,
                          ),
                        ),
                        child: InkWell(
                          key: ValueKey('swap-option-${item.id}'),
                          onTap: select,
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpace.md,
                              vertical: AppSpace.md,
                            ),
                            child: Row(
                              children: [
                                OutfitPieceImage(
                                  item: item,
                                  width: OutfitMetrics.optionImage,
                                  height: OutfitMetrics.optionImage,
                                  illustrationSize:
                                      OutfitMetrics.optionIllustration,
                                ),
                                const SizedBox(width: AppSpace.md),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.name,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: text.labelLarge,
                                      ),
                                      const SizedBox(height: AppSpace.xxs),
                                      Text(
                                        '${item.colorName} · ${item.laundryStatus.label} · ${item.formality.label}',
                                        style: text.bodySmall?.copyWith(
                                          color: c.secondary,
                                        ),
                                      ),
                                      if (current)
                                        Text(
                                          'Current pick',
                                          style: text.bodySmall?.copyWith(
                                            color: c.secondary,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                if (isSelected) ...[
                                  const SizedBox(width: AppSpace.sm),
                                  AppSvg(
                                    'outfit_selected_check',
                                    color: c.accent,
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              if (candidates.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpace.lg),
                  child: Text(
                    'No available ${widget.category.plural.toLowerCase()} for this occasion.',
                    style: text.bodyMedium?.copyWith(color: c.secondary),
                  ),
                ),
              const SizedBox(height: AppSpace.md),
              FilledButton(
                onPressed: selected == null
                    ? null
                    : () => Navigator.pop(context, selected),
                child: Text(confirmLabel),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class OutfitWearFailure implements Exception {
  const OutfitWearFailure(this.message);
  final String message;
}

/// The callback completes only when wear was recorded; throw on failure.
/// The screen then keeps the action retryable and explains the failure inline.
class ViewOutfitScreen extends StatefulWidget {
  const ViewOutfitScreen({
    super.key,
    required this.outfit,
    required this.onWear,
    this.worn = false,
    this.updates,
    this.resolveOutfit,
  });
  final OutfitSuggestion outfit;
  final Future<void> Function()? onWear;
  final bool worn;
  final Listenable? updates;

  /// Resolves current wardrobe data for display without guessing wear counts.
  /// The original outfit remains visible if its references are unavailable.
  final OutfitSuggestion? Function()? resolveOutfit;

  @override
  State<ViewOutfitScreen> createState() => _ViewOutfitScreenState();
}

class _ViewOutfitScreenState extends State<ViewOutfitScreen> {
  bool _busy = false;
  late bool _worn;
  String? _error;

  @override
  void initState() {
    super.initState();
    _worn = widget.worn;
  }

  @override
  void didUpdateWidget(covariant ViewOutfitScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.worn) _worn = true;
  }

  Future<void> _wear() async {
    if (_busy || _worn || widget.onWear == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.onWear!();
      if (mounted) setState(() => _worn = true);
    } on OutfitWearFailure catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Could not record this outfit. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final updates = widget.updates;
    return updates == null
        ? _buildScreen(context)
        : ListenableBuilder(
            listenable: updates,
            builder: (context, _) => _buildScreen(context),
          );
  }

  Widget _buildScreen(BuildContext context) {
    final c = FitCheckColors.of(context);
    final text = Theme.of(context).textTheme;
    final outfit = widget.resolveOutfit?.call() ?? widget.outfit;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: c.canvas,
        surfaceTintColor: c.canvas,
        title: Text('Today’s outfit', style: text.titleLarge),
        leading: IconButton(
          tooltip: 'Close outfit',
          onPressed: () => Navigator.pop(context),
          icon: AppSvg('close', color: c.primary),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: AppSize.contentWidth),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpace.lg,
              AppSpace.sm,
              AppSpace.lg,
              AppSpace.lg,
            ),
            children: [
              OutfitReason(outfit.reason),
              const SizedBox(height: AppSpace.md),
              for (final item in outfit.pieces) ...[
                _OutfitDetail(item: item),
                const SizedBox(height: AppSpace.md),
              ],
            ],
          ),
        ),
      ),
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(
          color: c.surface,
          border: Border(top: BorderSide(color: c.border)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpace.lg,
              vertical: AppSpace.md,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_error != null) ...[
                  InlineMessage(_error!, isError: true),
                  const SizedBox(height: AppSpace.md),
                ],
                FilledButton.icon(
                  onPressed: _busy || _worn || widget.onWear == null
                      ? null
                      : _wear,
                  icon: AppSvg(
                    'outfit_check',
                    color: c.onAccent,
                    size: AppSize.iconMedium,
                  ),
                  label: Text(
                    _busy
                        ? 'Saving outfit…'
                        : _worn
                        ? 'Worn today'
                        : 'Wear this',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OutfitDetail extends StatelessWidget {
  const _OutfitDetail({required this.item});
  final ClothingItem item;

  @override
  Widget build(BuildContext context) {
    final c = FitCheckColors.of(context);
    final text = Theme.of(context).textTheme;
    final image = OutfitPieceImage(
      item: item,
      width: OutfitMetrics.detailImage,
      height: OutfitMetrics.detailImage,
      illustrationSize: OutfitMetrics.detailIllustration,
      radius: AppRadius.lg,
    );
    final details = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          item.category.label,
          style: text.labelSmall?.copyWith(color: c.secondary),
        ),
        const SizedBox(height: AppSpace.xs),
        Text(item.name, style: text.titleLarge),
        const SizedBox(height: AppSpace.xs),
        Text(
          '${item.colorName} · ${item.formality.label}',
          style: text.bodySmall?.copyWith(color: c.secondary),
        ),
        const SizedBox(height: AppSpace.xs),
        Align(
          alignment: Alignment.centerLeft,
          child: LaundryBadge(status: item.laundryStatus),
        ),
      ],
    );
    return Semantics(
      label:
          '${item.category.label}: ${item.name}, ${item.colorName}, ${item.formality.label}, ${item.laundryStatus.label}',
      excludeSemantics: true,
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 300 ||
              MediaQuery.textScalerOf(context).scale(16) > 24) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                image,
                const SizedBox(height: AppSpace.md),
                details,
              ],
            );
          }
          return Row(
            children: [
              image,
              const SizedBox(width: AppSpace.lg),
              Expanded(child: details),
            ],
          );
        },
      ),
    );
  }
}
