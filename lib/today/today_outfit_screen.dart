import 'dart:async';

import 'package:flutter/material.dart';

import '../outfits/outfit_picker.dart';
import '../outfits/outfit_repository.dart';
import '../theme/fitcheck_theme.dart';
import '../wardrobe/wardrobe_models.dart';
import '../wardrobe/wardrobe_store.dart';
import '../widgets/common.dart';
import 'outfit_card.dart';
import 'outfit_sheets.dart';
import 'today_screen.dart';
import 'week_strip.dart';

class TodayOutfitScreen extends StatefulWidget {
  const TodayOutfitScreen({
    super.key,
    required this.wardrobe,
    required this.outfits,
    required this.onAddClothes,
    required this.onAddFragrance,
    this.now,
    this.fragrance,
    this.showFragranceInEmpty = false,
  });
  final WardrobeStore wardrobe;
  final OutfitRepository outfits;
  final VoidCallback onAddClothes, onAddFragrance;
  final DateTime? now;
  final Widget? fragrance;
  final bool showFragranceInEmpty;
  @override
  State<TodayOutfitScreen> createState() => _TodayOutfitScreenState();
}

class _TodayOutfitScreenState extends State<TodayOutfitScreen>
    with WidgetsBindingObserver {
  final _picker = const OutfitPicker();
  StreamSubscription<SavedOutfit?>? _subscription;
  Timer? _dayTimer;
  late DateTime _date;
  SavedOutfit? _saved;
  OutfitSuggestion? _pendingOutfit;
  bool _waiting = true, _busy = false;
  int _generation = 0;
  String? _readError, _actionError;
  @override
  void initState() {
    super.initState();
    _date = dateOnly(widget.now ?? DateTime.now());
    widget.wardrobe.addListener(_refresh);
    WidgetsBinding.instance.addObserver(this);
    _watch();
    _dayTimer = Timer.periodic(const Duration(minutes: 1), (_) => _checkDay());
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  void _watch() {
    final generation = ++_generation;
    _subscription?.cancel().ignore();
    _waiting = true;
    _saved = null;
    _readError = null;
    _actionError = null;
    _subscription = widget.outfits
        .watchDate(_date)
        .listen(
          (value) {
            if (!mounted || generation != _generation) return;
            setState(() {
              _saved = value;
              _waiting = false;
              _readError = null;
            });
          },
          onError: (Object error) {
            if (!mounted || generation != _generation) return;
            setState(() {
              _waiting = false;
              _readError = error is OutfitFailure
                  ? error.message
                  : 'Could not load your outfit. Please try again.';
            });
          },
        );
  }

  void _checkDay() {
    if (widget.now != null) return;
    final today = dateOnly(DateTime.now());
    if (today != _date && mounted) {
      setState(() {
        _date = today;
        _watch();
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _checkDay();
  }

  @override
  void dispose() {
    _generation++;
    _dayTimer?.cancel();
    _subscription?.cancel().ignore();
    widget.wardrobe.removeListener(_refresh);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Occasion _occasion() {
    final savedOccasion = widget.wardrobe.occasions
        .where((value) => value.id == _saved?.occasionId)
        .firstOrNull;
    if (savedOccasion != null) return savedOccasion;
    final counts = <String, int>{};
    for (final item in widget.wardrobe.items) {
      for (final id in item.occasionIds) {
        counts[id] = (counts[id] ?? 0) + 1;
      }
    }
    return resolveOutfitOccasion(
          occasions: widget.wardrobe.occasions,
          useCounts: counts,
        ) ??
        Occasion.defaults.first;
  }

  OutfitSelection _selection() {
    if (_busy && _pendingOutfit != null) return _pendingOutfit!;
    final saved = _saved?.resolve(
      items: widget.wardrobe.items,
      occasions: widget.wardrobe.occasions,
    );
    if (saved != null &&
        (_saved!.worn ||
            saved.pieces.every(
              (item) =>
                  item.laundryStatus != LaundryStatus.toWash &&
                  item.occasionIds.contains(saved.occasion.id),
            ))) {
      return saved;
    }
    return _picker.pick(
      items: widget.wardrobe.items,
      date: _date,
      occasion: _occasion(),
    );
  }

  Future<void> _save(OutfitSuggestion outfit) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _pendingOutfit = outfit;
      _actionError = null;
    });
    try {
      await widget.outfits.saveSuggestion(outfit);
      if (mounted && outfitDateKey(_date) == outfitDateKey(outfit.date)) {
        setState(() => _saved = SavedOutfit.fromSuggestion(outfit));
      }
    } on OutfitFailure catch (error) {
      if (mounted) setState(() => _actionError = error.message);
    } catch (_) {
      if (mounted) {
        setState(
          () =>
              _actionError = 'Could not change your outfit. Please try again.',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _pendingOutfit = null;
        });
      }
    }
  }

  Future<void> _wear(OutfitSuggestion outfit) async {
    if (_busy) {
      throw const OutfitFailure(
        'Please wait for the current action to finish.',
      );
    }
    setState(() {
      _busy = true;
      _pendingOutfit = outfit;
      _actionError = null;
    });
    try {
      final expected = SavedOutfit.fromSuggestion(outfit);
      if (_saved == null ||
          !_saved!.itemIds.containsAll(expected.itemIds) ||
          _saved!.occasionId != expected.occasionId) {
        await widget.outfits.saveSuggestion(outfit);
      }
      await widget.outfits.wear(outfit);
      if (mounted && outfitDateKey(_date) == outfitDateKey(outfit.date)) {
        setState(() => _saved = SavedOutfit.fromSuggestion(outfit, worn: true));
      }
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _pendingOutfit = null;
        });
      }
    }
  }

  Future<void> _wearFromCard(OutfitSuggestion outfit) async {
    try {
      await _wear(outfit);
    } on OutfitFailure catch (error) {
      if (mounted) setState(() => _actionError = error.message);
    } catch (_) {
      if (mounted) {
        setState(
          () =>
              _actionError = 'Could not record your outfit. Please try again.',
        );
      }
    }
  }

  Future<void> _swapAll(OutfitSuggestion outfit) async {
    final alternative = _picker.pick(
      items: widget.wardrobe.items,
      date: _date,
      occasion: outfit.occasion,
      excludeItemIds: outfit.itemIds,
    );
    if (alternative is OutfitSuggestion) {
      await _save(alternative);
    } else if (mounted) {
      setState(
        () => _actionError = 'There aren’t enough clean alternatives for a full swap. Your current outfit is kept.',
      );
    }
  }

  Future<void> _swapOne(OutfitSuggestion outfit, ClothingItem current) async {
    final candidates = _picker.swapCandidates(
      items: widget.wardrobe.items,
      date: _date,
      occasion: outfit.occasion,
      category: current.category,
      currentItemId: current.id,
      preferredFormality: current.formality,
    );
    final chosen = await showSwapItemSheet(
      context,
      category: current.category,
      occasion: outfit.occasion,
      candidates: candidates,
      currentItemId: current.id,
    );
    if (chosen == null ||
        !mounted ||
        chosen.id == current.id ||
        outfitDateKey(outfit.date) != outfitDateKey(_date)) {
      return;
    }
    final ids = {...outfit.itemIds}
      ..remove(current.id)
      ..add(chosen.id);
    final selection = _picker.pick(
      items: widget.wardrobe.items.where((item) => ids.contains(item.id)),
      date: _date,
      occasion: outfit.occasion,
    );
    if (selection is OutfitSuggestion) {
      await _save(selection);
    } else {
      setState(
        () => _actionError =
            'Your wardrobe changed. Please choose your outfit again.',
      );
    }
  }

  Future<void> _view(OutfitSuggestion outfit) =>
      Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => ViewOutfitScreen(
            outfit: outfit,
            worn: _saved?.worn ?? false,
            updates: widget.wardrobe,
            resolveOutfit: () =>
                _saved?.resolve(
                  items: widget.wardrobe.items,
                  occasions: widget.wardrobe.occasions,
                ) ??
                outfit,
            onWear: _saved?.worn == true
                ? null
                : () async {
                    try {
                      await _wear(outfit);
                    } on OutfitFailure catch (error) {
                      throw OutfitWearFailure(error.message);
                    }
                  },
          ),
        ),
      );
  Future<void> _retry() async {
    setState(_watch);
    await widget.wardrobe.retry();
  }

  @override
  Widget build(BuildContext context) {
    if (_waiting || widget.wardrobe.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    final error = _readError ?? widget.wardrobe.error;
    if (error != null) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpace.lg),
        child: Column(
          children: [
            InlineMessage(error, isError: true),
            TextButton(onPressed: _retry, child: const Text('Try again')),
          ],
        ),
      );
    }
    if (_saved?.worn == true &&
        _saved!.resolve(
              items: widget.wardrobe.items,
              occasions: widget.wardrobe.occasions,
            ) ==
            null) {
      return const Padding(
        padding: EdgeInsets.all(AppSpace.lg),
        child: InlineMessage(
          'This day’s outfit was worn, but some of its pieces are no longer available.',
          isError: true,
        ),
      );
    }
    final selection = _selection();
    if (selection is MissingOutfitItems) {
      return TodayScreen(
        onAddClothes: widget.onAddClothes,
        onAddFragrance: widget.onAddFragrance,
        now: _date,
        occasionName: widget.wardrobe.items.isEmpty
            ? null
            : selection.occasion.name,
        readyCategories: ClothingCategory.values
            .where((value) => !selection.categories.contains(value))
            .toSet(),
        fragrance: widget.showFragranceInEmpty ? widget.fragrance : null,
      );
    }
    final outfit = selection as OutfitSuggestion;
    final worn = _saved?.worn ?? false;
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
          TodayWeekStrip(date: _date),
          const SizedBox(height: AppSpace.xxl),
          OutfitCard(
            outfit: outfit,
            busy: _busy,
            worn: worn,
            error: _actionError,
            onWear: worn ? null : () => _wearFromCard(outfit),
            onSwapAll: worn ? null : () => _swapAll(outfit),
            onSwapItem: worn ? null : (item) => _swapOne(outfit, item),
            onViewOutfit: () => _view(outfit),
          ),
          const SizedBox(height: AppSpace.md),
          if (widget.fragrance != null)
            widget.fragrance!
          else
            TextButton(
              onPressed: widget.onAddFragrance,
              child: const Text('Add a fragrance (optional)'),
            ),
        ],
      ),
    );
  }
}
