import 'package:flutter/material.dart';

import '../theme/fitcheck_theme.dart';
import '../widgets/common.dart';
import 'add_item_screen.dart';
import 'wardrobe_models.dart';
import 'wardrobe_repository.dart';
import 'wardrobe_store.dart';

class WardrobeScreen extends StatefulWidget {
  const WardrobeScreen({
    super.key,
    required this.filter,
    required this.onFilterChanged,
    required this.store,
    required this.onAdd,
  });
  final String filter;
  final ValueChanged<String> onFilterChanged;
  final WardrobeStore store;
  final VoidCallback onAdd;
  @override
  State<WardrobeScreen> createState() => _WardrobeScreenState();
}

class _WardrobeScreenState extends State<WardrobeScreen> {
  String _query = '';
  @override
  Widget build(BuildContext context) {
    final c = FitCheckColors.of(context), text = Theme.of(context).textTheme;
    final items = widget.store.items
        .where(
          (item) =>
              (widget.filter == 'All' ||
                  widget.filter == item.category.plural) &&
              '${item.name} ${item.colorName}'.toLowerCase().contains(
                _query.trim().toLowerCase(),
              ),
        )
        .toList();
    final toWash = widget.store.items
        .where((item) => item.laundryStatus == LaundryStatus.toWash)
        .length;
    return Stack(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: AppSpace.lg),
              child: Row(
                children: [
                  for (final value in [
                    'All',
                    'Tops',
                    'Bottoms',
                    'Shoes',
                    'Scents',
                  ])
                    Padding(
                      padding: const EdgeInsets.only(right: AppSpace.sm),
                      child: AppChoice(
                        label: value,
                        selected: widget.filter == value,
                        onPressed: () => widget.onFilterChanged(value),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpace.lg,
                AppSpace.md,
                AppSpace.lg,
                0,
              ),
              child: TextField(
                decoration: InputDecoration(
                  labelText: 'Search your wardrobe',
                  prefixIcon: Padding(
                    padding: const EdgeInsets.all(AppSpace.md),
                    child: AppSvg('search', color: c.secondary),
                  ),
                ),
                onChanged: (value) => setState(() => _query = value),
              ),
            ),
            const SizedBox(height: AppSpace.sm),
            Expanded(
              child: widget.store.loading
                  ? const Center(child: CircularProgressIndicator())
                  : SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpace.lg,
                        AppSpace.sm,
                        AppSpace.lg,
                        AppSpace.touch + AppSpace.xxxl,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (widget.store.error != null) ...[
                            InlineMessage(widget.store.error!, isError: true),
                            TextButton(
                              onPressed: widget.store.retry,
                              child: const Text('Try again'),
                            ),
                          ],
                          Text(
                            '${widget.store.items.length} items${toWash == 0 ? '' : ' · $toWash need washing'}',
                            style: text.bodySmall?.copyWith(color: c.secondary),
                          ),
                          const SizedBox(height: AppSpace.md),
                          if (items.isEmpty)
                            SurfaceCard(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    widget.filter == 'Scents'
                                        ? 'Your fragrances'
                                        : _query.isEmpty
                                        ? 'Your clothes'
                                        : 'No matching clothes',
                                    style: text.titleLarge,
                                  ),
                                  const SizedBox(height: AppSpace.sm),
                                  Text(
                                    widget.filter == 'Scents'
                                        ? 'No fragrances added yet.'
                                        : _query.isNotEmpty
                                        ? 'Try another name or color.'
                                        : 'Add your first top, bottom, or pair of shoes.',
                                    style: text.bodyMedium?.copyWith(
                                      color: c.secondary,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          else
                            LayoutBuilder(
                              builder: (context, constraints) {
                                final columns =
                                    MediaQuery.textScalerOf(context).scale(16) >
                                            24 ||
                                        constraints.maxWidth < 300
                                    ? 1
                                    : 2;
                                final width =
                                    (constraints.maxWidth -
                                        AppSpace.md * (columns - 1)) /
                                    columns;
                                return Wrap(
                                  spacing: AppSpace.md,
                                  runSpacing: AppSpace.md,
                                  children: [
                                    for (final item in items)
                                      SizedBox(
                                        width: width,
                                        child: _ClothingCard(
                                          item: item,
                                          onPressed: () =>
                                              showModalBottomSheet<void>(
                                                context: context,
                                                isScrollControlled: true,
                                                useSafeArea: true,
                                                builder: (_) => _ItemSheet(
                                                  item: item,
                                                  repository:
                                                      widget.store.repository,
                                                ),
                                              ),
                                        ),
                                      ),
                                  ],
                                );
                              },
                            ),
                        ],
                      ),
                    ),
            ),
          ],
        ),
        if (widget.filter != 'Scents')
          Positioned(
            right: AppSpace.lg,
            bottom: AppSpace.lg,
            child: FilledButton.icon(
              onPressed: widget.onAdd,
              icon: AppSvg('plus', color: c.onAccent),
              label: const Text('Add item'),
            ),
          ),
      ],
    );
  }
}

class _ClothingCard extends StatelessWidget {
  const _ClothingCard({required this.item, required this.onPressed});
  final ClothingItem item;
  final VoidCallback onPressed;
  @override
  Widget build(BuildContext context) {
    final c = FitCheckColors.of(context), text = Theme.of(context).textTheme;
    return Semantics(
      button: true,
      label: '${item.name}, ${item.colorName}, ${item.laundryStatus.label}',
      onTap: onPressed,
      excludeSemantics: true,
      child: Card(
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          child: Padding(
            padding: const EdgeInsets.all(AppSpace.sm),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  height: 120,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: c.subtle,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: item.photoUrl == null
                      ? AppSvg(item.category.name, illustration: true)
                      : Image.network(
                          item.photoUrl!,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          errorBuilder: (_, _, _) =>
                              AppSvg(item.category.name, illustration: true),
                        ),
                ),
                const SizedBox(height: AppSpace.sm),
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
                Text(
                  '${item.category.label} · ${item.formality.label}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: text.labelSmall?.copyWith(color: c.secondary),
                ),
                const SizedBox(height: AppSpace.sm),
                Align(
                  alignment: Alignment.centerLeft,
                  child: LaundryBadge(status: item.laundryStatus),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class LaundryBadge extends StatelessWidget {
  const LaundryBadge({super.key, required this.status});
  final LaundryStatus status;
  @override
  Widget build(BuildContext context) {
    final c = FitCheckColors.of(context);
    final (color, background, icon) = switch (status) {
      LaundryStatus.clean => (
        c.success,
        c.successSubtle,
        Icons.check_circle_outline,
      ),
      LaundryStatus.worn => (c.secondary, c.subtle, Icons.history),
      LaundryStatus.toWash => (
        c.warning,
        c.warningSubtle,
        Icons.local_laundry_service_outlined,
      ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpace.sm,
        vertical: AppSpace.xs,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: AppSize.iconSmall, color: color),
          const SizedBox(width: AppSpace.xs),
          Flexible(
            child: Text(
              status.label,
              style: Theme.of(context).textTheme.labelSmall
                  ?.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }
}

class _ItemSheet extends StatefulWidget {
  const _ItemSheet({required this.item, required this.repository});
  final ClothingItem item;
  final WardrobeRepository repository;
  @override
  State<_ItemSheet> createState() => _ItemSheetState();
}

class _ItemSheetState extends State<_ItemSheet> {
  bool _saving = false;
  String? _error;
  Future<void> _wash() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.repository.markWashed(widget.item.id);
      if (mounted) Navigator.pop(context);
    } on WardrobeFailure catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item, text = Theme.of(context).textTheme;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpace.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(child: Text(item.name, style: text.titleLarge)),
                IconButton(
                  tooltip: 'Close item',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: AppSpace.lg),
            Text('Color: ${item.colorName}'),
            Text('${item.category.label} · ${item.formality.label}'),
            const SizedBox(height: AppSpace.sm),
            Align(
              alignment: Alignment.centerLeft,
              child: LaundryBadge(status: item.laundryStatus),
            ),
            if (_error != null) InlineMessage(_error!, isError: true),
            if (item.tracksLaundry) ...[
              const SizedBox(height: AppSpace.lg),
              Text('${item.wearsSinceWash} wears since washing'),
              const SizedBox(height: AppSpace.lg),
              FilledButton(
                onPressed: _saving ? null : _wash,
                child: Text(_saving ? 'Saving…' : 'Mark washed'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
