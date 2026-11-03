import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/fitcheck_theme.dart';
import '../weather/location_sheet.dart';
import '../weather/weather_store.dart';
import '../widgets/common.dart';
import 'fragrance.dart';
import 'fragrance_repository.dart';
import 'fragrance_store.dart';

abstract final class FragranceMetrics {
  static const double image = 64, optionImage = 56, illustration = 44;
}

class FragranceImage extends StatelessWidget {
  const FragranceImage({
    super.key,
    required this.fragrance,
    this.size = FragranceMetrics.image,
  });
  final Fragrance fragrance;
  final double size;
  // Decorative: the fragrance name is always shown beside the image, and an
  // image flag here would otherwise merge into the surrounding card.
  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: FitCheckColors.of(context).subtle,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      clipBehavior: Clip.antiAlias,
      alignment: Alignment.center,
      child: fragrance.photoUrl == null
          ? const AppSvg(
              'scent',
              illustration: true,
              size: FragranceMetrics.illustration,
            )
          : Image.network(
              fragrance.photoUrl!,
              fit: BoxFit.cover,
              width: size,
              height: size,
              errorBuilder: (_, _, _) => const AppSvg(
                'scent',
                illustration: true,
                size: FragranceMetrics.illustration,
              ),
            ),
    ),
  );
}

List<RankedFragrance> _ranked(FragranceStore fragrances, WeatherStore weather) {
  final observation = weather.observation;
  return observation == null
      ? const []
      : rankFragrances(
          fragrances: fragrances.items,
          temperatureC: observation.temperatureC,
          relativeHumidity: observation.relativeHumidity,
        );
}

class TodayFragrance extends StatefulWidget {
  const TodayFragrance({
    super.key,
    required this.fragrances,
    required this.weather,
    required this.onAdd,
  });
  final FragranceStore fragrances;
  final WeatherStore weather;
  final VoidCallback onAdd;
  @override
  State<TodayFragrance> createState() => _TodayFragranceState();
}

class _TodayFragranceState extends State<TodayFragrance>
    with WidgetsBindingObserver {
  Timer? _timer;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _timer = Timer.periodic(const Duration(minutes: 1), (_) => _refresh());
  }

  void _refresh() {
    widget.fragrances.checkDay();
    widget.weather.refresh();
    if (mounted) setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([widget.fragrances, widget.weather]),
    builder: (context, _) {
      final fragrances = widget.fragrances, weather = widget.weather;
      final ranked = _ranked(fragrances, weather);
      final selected =
          ranked
              .where((item) => item.fragrance.id == fragrances.selectedId)
              .firstOrNull ??
          ranked.firstOrNull;
      final c = FitCheckColors.of(context), text = Theme.of(context).textTheme;
      final loading = fragrances.loading || fragrances.pickLoading;
      return SurfaceCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text('Fragrance of the day', style: text.titleLarge),
                if (selected != null && !loading && fragrances.error == null)
                  TextButton(
                    onPressed: () => showModalBottomSheet<void>(
                      context: context,
                      isScrollControlled: true,
                      useSafeArea: true,
                      builder: (_) => ChangeFragranceSheet(
                        fragrances: fragrances,
                        weather: weather,
                      ),
                    ),
                    child: const Text('Change'),
                  ),
              ],
            ),
            if (loading)
              const Center(child: CircularProgressIndicator())
            else if (fragrances.error != null) ...[
              InlineMessage(fragrances.error!, isError: true),
              TextButton(
                onPressed: fragrances.retry,
                child: const Text('Retry fragrances'),
              ),
            ] else if (fragrances.items.isEmpty) ...[
              const Text('Add a fragrance to get a pick for today’s weather.'),
              TextButton(
                onPressed: widget.onAdd,
                child: const Text('Add a fragrance'),
              ),
            ] else if (weather.loading && weather.observation == null)
              const Padding(
                padding: EdgeInsets.all(AppSpace.md),
                child: Text('Loading your weather…'),
              )
            else if (selected == null) ...[
              Text(
                weather.error ??
                    (weather.location == null
                        ? 'Choose your city to match a fragrance to the weather.'
                        : 'Fresh weather is needed for today’s fragrance pick.'),
              ),
              TextButton(
                onPressed: weather.location == null
                    ? () => showLocationSheet(context, weather)
                    : weather.retry,
                child: Text(
                  weather.location == null ? 'Choose city' : 'Retry weather',
                ),
              ),
            ] else ...[
              const SizedBox(height: AppSpace.xs),
              Row(
                children: [
                  FragranceImage(fragrance: selected.fragrance),
                  const SizedBox(width: AppSpace.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          selected.fragrance.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: text.labelLarge,
                        ),
                        const SizedBox(height: AppSpace.xxs),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(top: AppSpace.xxs),
                              child: AppSvg(
                                'droplet',
                                color: c.secondary,
                                size: AppSize.iconSmall,
                              ),
                            ),
                            const SizedBox(width: AppSpace.xs),
                            Expanded(
                              child: Text(
                                selected.reason,
                                style: text.bodySmall?.copyWith(
                                  color: c.secondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (weather.error != null) ...[
                const SizedBox(height: AppSpace.sm),
                Text(
                  'Using recent weather. ${weather.error}',
                  style: text.bodySmall?.copyWith(color: c.secondary),
                ),
                TextButton(
                  onPressed: weather.retry,
                  child: const Text('Retry weather'),
                ),
              ],
            ],
          ],
        ),
      );
    },
  );
}

class ChangeFragranceSheet extends StatefulWidget {
  const ChangeFragranceSheet({
    super.key,
    required this.fragrances,
    required this.weather,
  });
  final FragranceStore fragrances;
  final WeatherStore weather;
  @override
  State<ChangeFragranceSheet> createState() => _ChangeFragranceSheetState();
}

class _ChangeFragranceSheetState extends State<ChangeFragranceSheet> {
  String? _selected, _error;
  bool _busy = false;
  late final String _dateKey;
  @override
  void initState() {
    super.initState();
    _dateKey = widget.fragrances.dateKey;
    _selected =
        widget.fragrances.selectedId ??
        _ranked(widget.fragrances, widget.weather).firstOrNull?.fragrance.id;
  }

  Future<void> _save(Fragrance fragrance) async {
    widget.fragrances.checkDay();
    if (_busy) return;
    if (widget.fragrances.dateKey != _dateKey ||
        widget.weather.observation == null) {
      setState(
        () => _error =
            'The day or weather changed. Close this sheet and try again.',
      );
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.fragrances.choose(fragrance);
      if (mounted) Navigator.pop(context);
    } on FragranceFailure catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Could not save your fragrance choice. Try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([widget.fragrances, widget.weather]),
    builder: (context, _) {
      final c = FitCheckColors.of(context), text = Theme.of(context).textTheme;
      final ranked = _ranked(widget.fragrances, widget.weather);
      final selected = ranked
          .where((item) => item.fragrance.id == _selected)
          .firstOrNull;
      final observation = widget.weather.observation;
      return PopScope(
        canPop: !_busy,
        child: SafeArea(
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
                            Text('Change fragrance', style: text.titleLarge),
                            const SizedBox(height: AppSpace.xxs),
                            Text(
                              observation == null
                                  ? 'Fresh weather is needed to sort your fragrances.'
                                  : 'Sorted for ${observation.temperatureC.toStringAsFixed(1)}°C and ${observation.relativeHumidity.round()}% humidity.',
                              style: text.bodySmall?.copyWith(
                                color: c.secondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Close change fragrance',
                        onPressed: _busy ? null : () => Navigator.pop(context),
                        icon: AppSvg('close', color: c.primary),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpace.md),
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: ranked.length,
                      separatorBuilder: (_, _) =>
                          const SizedBox(height: AppSpace.sm),
                      itemBuilder: (context, index) {
                        final item = ranked[index],
                            isSelected = item.fragrance.id == _selected;
                        void select() {
                          if (!_busy) {
                            setState(() => _selected = item.fragrance.id);
                          }
                        }

                        return Semantics(
                          button: true,
                          selected: isSelected,
                          excludeSemantics: true,
                          label: '${item.fragrance.name}. ${item.reason}',
                          onTap: _busy ? null : select,
                          child: Material(
                            color: isSelected ? c.accentSubtle : c.surface,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(AppRadius.md),
                              side: BorderSide(
                                color: isSelected ? c.accent : c.border,
                                width: isSelected
                                    ? AppSize.focus
                                    : AppSize.stroke,
                              ),
                            ),
                            child: InkWell(
                              key: ValueKey(
                                'fragrance-option-${item.fragrance.id}',
                              ),
                              onTap: _busy ? null : select,
                              borderRadius: BorderRadius.circular(AppRadius.md),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpace.md,
                                  vertical: AppSpace.md,
                                ),
                                child: Row(
                                  children: [
                                    FragranceImage(
                                      fragrance: item.fragrance,
                                      size: FragranceMetrics.optionImage,
                                    ),
                                    const SizedBox(width: AppSpace.md),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            item.fragrance.name,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: text.labelLarge,
                                          ),
                                          const SizedBox(height: AppSpace.xxs),
                                          Text(
                                            item.reason,
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
                  if (_error != null) InlineMessage(_error!, isError: true),
                  const SizedBox(height: AppSpace.md),
                  FilledButton(
                    onPressed:
                        _busy ||
                            selected == null ||
                            widget.fragrances.error != null
                        ? null
                        : () => _save(selected.fragrance),
                    child: Text(_busy ? 'Saving…' : 'Use this fragrance'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}
