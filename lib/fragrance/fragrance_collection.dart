import 'package:flutter/material.dart';

import '../theme/fitcheck_theme.dart';
import '../widgets/common.dart';
import 'fragrance.dart';
import 'fragrance_form.dart';
import 'fragrance_repository.dart';

class FragranceCollection extends StatelessWidget {
  const FragranceCollection({
    super.key,
    required this.items,
    required this.repository,
    required this.query,
    required this.onAdd,
  });
  final List<Fragrance> items;
  final FragranceRepository repository;
  final String query;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final colors = FitCheckColors.of(context);
    final text = Theme.of(context).textTheme;
    final search = query.trim().toLowerCase();
    final visible = items
        .where(
          (item) =>
              '${item.name} ${item.scentNotes ?? ''} ${item.temperatureBand.label} ${item.humidityBand.label}'
                  .toLowerCase()
                  .contains(search),
        )
        .toList();
    return Stack(
      children: [
        Positioned.fill(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              AppSpace.lg,
              AppSpace.sm,
              AppSpace.lg,
              AppSpace.touch + AppSpace.xxxl,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '${visible.length} ${visible.length == 1 ? 'fragrance' : 'fragrances'}',
                  style: text.bodySmall?.copyWith(color: colors.secondary),
                ),
                const SizedBox(height: AppSpace.md),
                if (visible.isEmpty)
                  SurfaceCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          items.isEmpty
                              ? 'Add your first fragrance'
                              : 'No fragrances match your search.',
                          style: text.titleLarge,
                        ),
                        const SizedBox(height: AppSpace.sm),
                        Text(
                          items.isEmpty
                              ? 'Choose the temperature and humidity you like for each scent. FitCheck can match it to the weather.'
                              : 'Try another name, scent note, or weather preference.',
                          style: text.bodyMedium?.copyWith(
                            color: colors.secondary,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final singleColumn =
                          constraints.maxWidth < 300 ||
                          MediaQuery.textScalerOf(context).scale(16) > 24;
                      final width = singleColumn
                          ? constraints.maxWidth
                          : (constraints.maxWidth - AppSpace.md) / 2;
                      return Wrap(
                        spacing: AppSpace.md,
                        runSpacing: AppSpace.md,
                        children: [
                          for (final item in visible)
                            SizedBox(
                              width: width,
                              child: Semantics(
                                button: true,
                                label:
                                    '${item.name}, ${item.temperatureBand.label}, ${item.humidityBand.label}',
                                excludeSemantics: true,
                                onTap: () => _openDetail(context, item),
                                child: Card(
                                  child: InkWell(
                                    onTap: () => _openDetail(context, item),
                                    borderRadius: BorderRadius.circular(
                                      AppRadius.lg,
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.all(
                                        AppSpace.sm,
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: [
                                          _FragranceImage(fragrance: item),
                                          const SizedBox(height: AppSpace.sm),
                                          Text(
                                            item.name,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: text.labelMedium,
                                          ),
                                          const SizedBox(height: AppSpace.xs),
                                          Text(
                                            item.temperatureBand.label,
                                            style: text.bodySmall?.copyWith(
                                              color: colors.secondary,
                                            ),
                                          ),
                                          Text(
                                            item.humidityBand.label,
                                            style: text.bodySmall?.copyWith(
                                              color: colors.secondary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
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
        Positioned(
          right: AppSpace.lg,
          bottom: AppSpace.lg,
          left: MediaQuery.textScalerOf(context).scale(16) > 24
              ? AppSpace.lg
              : null,
          child: FilledButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add),
            label: const Text('Add fragrance'),
          ),
        ),
      ],
    );
  }

  void _openDetail(BuildContext context, Fragrance fragrance) {
    Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => _FragranceDetailScreen(
          fragrance: fragrance,
          repository: repository,
        ),
      ),
    );
  }
}

class _FragranceImage extends StatelessWidget {
  const _FragranceImage({required this.fragrance, this.height = 120});
  final Fragrance fragrance;
  final double height;

  @override
  Widget build(BuildContext context) {
    final colors = FitCheckColors.of(context);
    Widget placeholder() => const Center(
      child: AppSvg('scent', illustration: true, size: AppSize.touch),
    );
    return Container(
      height: height,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: colors.subtle,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: fragrance.photoUrl == null
          ? placeholder()
          : Image.network(
              fragrance.photoUrl!,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => placeholder(),
            ),
    );
  }
}

class _FragranceDetailScreen extends StatefulWidget {
  const _FragranceDetailScreen({
    required this.fragrance,
    required this.repository,
  });
  final Fragrance fragrance;
  final FragranceRepository repository;

  @override
  State<_FragranceDetailScreen> createState() => _FragranceDetailScreenState();
}

class _FragranceDetailScreenState extends State<_FragranceDetailScreen> {
  late Stream<List<Fragrance>> _stream;
  bool _confirming = false, _deleting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _stream = widget.repository.watchAll();
  }

  Future<void> _delete() async {
    if (_deleting) return;
    setState(() {
      _deleting = true;
      _error = null;
    });
    try {
      await widget.repository.delete(widget.fragrance.id);
      if (mounted) Navigator.pop(context);
    } on FragranceFailure catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Could not delete this fragrance. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = FitCheckColors.of(context);
    final text = Theme.of(context).textTheme;
    return PopScope(
      canPop: !_deleting,
      child: StreamBuilder<List<Fragrance>>(
        stream: _stream,
        initialData: [widget.fragrance],
        builder: (context, snapshot) {
          final item = snapshot.data
              ?.where((value) => value.id == widget.fragrance.id)
              .firstOrNull;
          return Scaffold(
            appBar: AppBar(
              backgroundColor: colors.canvas,
              surfaceTintColor: colors.canvas,
              title: Text('Fragrance', style: text.titleLarge),
              leading: IconButton(
                tooltip: 'Close fragrance',
                onPressed: _deleting ? null : () => Navigator.pop(context),
                icon: AppSvg('close', color: colors.primary),
              ),
            ),
            body: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: AppSize.contentWidth,
                ),
                child: ListView(
                  padding: const EdgeInsets.all(AppSpace.lg),
                  children: [
                    if (snapshot.hasError) ...[
                      const InlineMessage(
                        'Could not refresh this fragrance. Please try again.',
                        isError: true,
                      ),
                      TextButton(
                        onPressed: () => setState(
                          () => _stream = widget.repository.watchAll(),
                        ),
                        child: const Text('Try again'),
                      ),
                      const SizedBox(height: AppSpace.lg),
                    ],
                    if (item == null)
                      Text(
                        'This fragrance is no longer in your collection.',
                        style: text.bodyMedium,
                      )
                    else ...[
                      _FragranceImage(fragrance: item, height: 200),
                      const SizedBox(height: AppSpace.lg),
                      Text(item.name, style: text.headlineSmall),
                      const SizedBox(height: AppSpace.lg),
                      Text('Temperature', style: text.labelLarge),
                      Text(
                        '${item.temperatureBand.label} · ${item.temperatureBand.rangeLabel}',
                        style: text.bodyMedium,
                      ),
                      const SizedBox(height: AppSpace.lg),
                      Text('Humidity', style: text.labelLarge),
                      Text(
                        '${item.humidityBand.label} · ${item.humidityBand.rangeLabel}',
                        style: text.bodyMedium,
                      ),
                      if (item.scentNotes != null) ...[
                        const SizedBox(height: AppSpace.lg),
                        Text('Scent notes', style: text.labelLarge),
                        const SizedBox(height: AppSpace.xs),
                        Text(item.scentNotes!, style: text.bodyMedium),
                      ],
                    ],
                  ],
                ),
              ),
            ),
            bottomNavigationBar: item == null
                ? null
                : DecoratedBox(
                    decoration: BoxDecoration(
                      color: colors.surface,
                      border: Border(top: BorderSide(color: colors.border)),
                    ),
                    child: SafeArea(
                      top: false,
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpace.lg),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (_error != null) ...[
                              InlineMessage(_error!, isError: true),
                              const SizedBox(height: AppSpace.sm),
                            ],
                            if (_confirming) ...[
                              Text(
                                'Delete this fragrance from your collection?',
                                style: text.bodyMedium,
                              ),
                              const SizedBox(height: AppSpace.sm),
                              OutlinedButton(
                                onPressed: _deleting ? null : _delete,
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: colors.danger,
                                  side: BorderSide(color: colors.danger),
                                ),
                                child: Text(
                                  _deleting
                                      ? 'Deleting fragrance…'
                                      : 'Confirm delete fragrance',
                                ),
                              ),
                              TextButton(
                                onPressed: _deleting
                                    ? null
                                    : () => setState(() => _confirming = false),
                                child: const Text('Keep fragrance'),
                              ),
                            ] else ...[
                              FilledButton(
                                onPressed: _deleting
                                    ? null
                                    : () => Navigator.push<Fragrance>(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => FragranceFormScreen(
                                            repository: widget.repository,
                                            fragrance: item,
                                          ),
                                        ),
                                      ),
                                child: const Text('Edit fragrance'),
                              ),
                              TextButton(
                                onPressed: _deleting
                                    ? null
                                    : () => setState(() => _confirming = true),
                                child: const Text('Delete fragrance'),
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
    );
  }
}
