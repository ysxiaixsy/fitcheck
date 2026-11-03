import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../theme/fitcheck_theme.dart';
import '../widgets/common.dart';
import 'wardrobe_models.dart';
import 'wardrobe_repository.dart';
import 'wardrobe_store.dart';

class AddItemScreen extends StatefulWidget {
  const AddItemScreen({super.key, required this.store});
  final WardrobeStore store;
  @override
  State<AddItemScreen> createState() => _AddItemScreenState();
}

class _AddItemScreenState extends State<AddItemScreen> {
  final _form = GlobalKey<FormState>();
  final _scroll = ScrollController();
  final _name = TextEditingController(), _color = TextEditingController();
  ClothingCategory _category = ClothingCategory.top;
  Formality _formality = Formality.casual;
  final Set<String> _occasions = {'school'};
  bool _tracks = true, _saving = false, _pickingPhoto = false;
  int _washAfter = 2;
  Uint8List? _photo;
  String? _mime, _error;
  @override
  void dispose() {
    _name.dispose();
    _color.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _showError(String message) {
    if (!mounted) return;
    setState(() => _error = message);
    _scrollToStart();
  }

  void _scrollToStart() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _scroll.hasClients) {
        _scroll.animateTo(
          0,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _pickPhoto() async {
    if (_saving || _pickingPhoto) return;
    setState(() => _pickingPhoto = true);
    try {
      final file = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1200,
        imageQuality: 85,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      final name = file.name.toLowerCase();
      final mime =
          file.mimeType ??
          (name.endsWith('.png')
              ? 'image/png'
              : name.endsWith('.webp')
              ? 'image/webp'
              : name.endsWith('.jpg') || name.endsWith('.jpeg')
              ? 'image/jpeg'
              : '');
      if (bytes.length > 5 * 1024 * 1024 ||
          !['image/jpeg', 'image/png', 'image/webp'].contains(mime)) {
        throw const WardrobeFailure(
          'Choose a JPG, PNG, or WebP photo smaller than 5 MB.',
        );
      }
      if (mounted) {
        setState(() {
          _photo = bytes;
          _mime = mime;
          _error = null;
        });
      }
    } on WardrobeFailure catch (error) {
      _showError(error.message);
    } catch (_) {
      _showError('Could not open this photo. Please try another.');
    } finally {
      if (mounted) setState(() => _pickingPhoto = false);
    }
  }

  Future<void> _newOccasion() async {
    final value = await showModalBottomSheet<Occasion>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _NewOccasion(repository: widget.store.repository),
    );
    if (value != null && mounted) setState(() => _occasions.add(value.id));
  }

  Future<void> _save() async {
    if (_saving || _pickingPhoto) return;
    if (!_form.currentState!.validate()) {
      _scrollToStart();
      return;
    }
    if (_occasions.isEmpty) {
      _showError('Choose at least one occasion.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.store.repository.addItem(
        ClothingDraft(
          name: _name.text,
          colorName: _color.text,
          category: _category,
          formality: _formality,
          occasionIds: _occasions.toList(),
          tracksLaundry: _tracks,
          washAfterWears: _washAfter,
        ),
        photo: _photo,
        mimeType: _mime,
      );
      if (mounted) Navigator.pop(context);
    } on WardrobeFailure catch (error) {
      _showError(error.message);
    } catch (_) {
      _showError('Could not save this item. Please try again.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _label(BuildContext context, String value) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpace.sm),
    child: Text(value, style: Theme.of(context).textTheme.labelMedium),
  );
  @override
  Widget build(BuildContext context) {
    final c = FitCheckColors.of(context), text = Theme.of(context).textTheme;
    return PopScope(
      canPop: !_saving,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: c.canvas,
          foregroundColor: c.primary,
          surfaceTintColor: c.canvas,
          title: Text('Add item', style: text.titleLarge),
          leading: IconButton(
            tooltip: 'Close add item',
            onPressed: _saving ? null : () => Navigator.pop(context),
            icon: AppSvg('close', color: c.primary),
          ),
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: AppSize.contentWidth),
            child: ListenableBuilder(
              listenable: widget.store,
              builder: (context, _) => Form(
                key: _form,
                child: SingleChildScrollView(
                  controller: _scroll,
                  padding: const EdgeInsets.all(AppSpace.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_error != null) ...[
                        InlineMessage(_error!, isError: true),
                        const SizedBox(height: AppSpace.lg),
                      ],
                      Semantics(
                        button: true,
                        label: _photo == null ? 'Add photo' : 'Change photo',
                        onTap: _saving || _pickingPhoto ? null : _pickPhoto,
                        excludeSemantics: true,
                        child: InkWell(
                          onTap: _saving || _pickingPhoto ? null : _pickPhoto,
                          borderRadius: BorderRadius.circular(AppRadius.lg),
                          child: CustomPaint(
                            painter: _DashedBorder(c.borderStrong),
                            child: Container(
                              padding: const EdgeInsets.all(AppSpace.lg),
                              child: _photo == null
                                  ? Column(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(
                                            AppSpace.md,
                                          ),
                                          decoration: BoxDecoration(
                                            color: c.subtle,
                                            shape: BoxShape.circle,
                                          ),
                                          child: AppSvg(
                                            'camera',
                                            color: c.primary,
                                          ),
                                        ),
                                        const SizedBox(height: AppSpace.sm),
                                        Text(
                                          'Add photo',
                                          style: text.labelLarge,
                                        ),
                                        const SizedBox(height: AppSpace.sm),
                                        Text(
                                          'Optional. You can add it later.',
                                          style: text.bodySmall?.copyWith(
                                            color: c.secondary,
                                          ),
                                        ),
                                      ],
                                    )
                                  : ClipRRect(
                                      borderRadius: BorderRadius.circular(
                                        AppRadius.md,
                                      ),
                                      child: Image.memory(
                                        _photo!,
                                        height: 136,
                                        fit: BoxFit.contain,
                                        errorBuilder: (_, _, _) => const Text(
                                          'Could not display photo. Choose another.',
                                        ),
                                      ),
                                    ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpace.lg),
                      TextFormField(
                        key: const Key('item-name'),
                        controller: _name,
                        enabled: !_saving,
                        maxLength: 120,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: const InputDecoration(
                          labelText: 'Name',
                          helperText: 'Put the color first, like “Navy polo”.',
                          helperMaxLines: 3,
                          counterText: '',
                        ),
                        validator: (value) =>
                            value == null || value.trim().isEmpty
                            ? 'Enter an item name.'
                            : null,
                      ),
                      const SizedBox(height: AppSpace.lg),
                      TextFormField(
                        key: const Key('item-color'),
                        controller: _color,
                        enabled: !_saving,
                        maxLength: 60,
                        decoration: const InputDecoration(
                          labelText: 'Color',
                          helperText: 'Shown as text on every item.',
                          helperMaxLines: 2,
                          counterText: '',
                        ),
                        validator: (value) =>
                            value == null || value.trim().isEmpty
                            ? 'Enter a color name.'
                            : null,
                      ),
                      const SizedBox(height: AppSpace.lg),
                      _label(context, 'Category'),
                      _FormSegments<ClothingCategory>(
                        options: [
                          for (final value in ClothingCategory.values)
                            (value, value.label),
                        ],
                        value: _category,
                        onChanged: _saving
                            ? null
                            : (value) => setState(() => _category = value),
                      ),
                      const SizedBox(height: AppSpace.lg),
                      _label(context, 'Where do you wear it?'),
                      Wrap(
                        spacing: AppSpace.sm,
                        runSpacing: AppSpace.sm,
                        children: [
                          for (final value in widget.store.occasions)
                            AppChoice(
                              label: value.name,
                              selected: _occasions.contains(value.id),
                              onPressed: _saving
                                  ? null
                                  : () => setState(() {
                                      if (!_occasions.add(value.id)) {
                                        _occasions.remove(value.id);
                                      }
                                    }),
                            ),
                          OutlinedButton(
                            onPressed: _saving ? null : _newOccasion,
                            child: const Text('+ New'),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpace.lg),
                      _label(context, 'How dressy is it?'),
                      _FormSegments<Formality>(
                        options: [
                          for (final value in Formality.values)
                            (value, value.label),
                        ],
                        value: _formality,
                        onChanged: _saving
                            ? null
                            : (value) => setState(() => _formality = value),
                      ),
                      const SizedBox(height: AppSpace.lg),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Track in laundry schedule'),
                        subtitle: const Text(
                          'We remind you before a planned day.',
                        ),
                        value: _tracks,
                        onChanged: _saving
                            ? null
                            : (value) => setState(() => _tracks = value),
                      ),
                      if (_tracks) ...[
                        const SizedBox(height: AppSpace.md),
                        _label(context, 'Wash after'),
                        _FormSegments<int>(
                          options: [
                            for (final value in [1, 2, 3])
                              (
                                value,
                                '$value ${value == 1 ? 'wear' : 'wears'}',
                              ),
                          ],
                          value: _washAfter,
                          onChanged: _saving
                              ? null
                              : (value) => setState(() => _washAfter = value),
                        ),
                      ],
                      const SizedBox(height: AppSpace.xxl),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        bottomNavigationBar: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(AppSpace.lg),
            child: FilledButton(
              key: const Key('save-item'),
              onPressed: _saving || _pickingPhoto ? null : _save,
              child: Text(_saving ? 'Saving item…' : 'Save item'),
            ),
          ),
        ),
      ),
    );
  }
}

class _FormSegments<T> extends StatelessWidget {
  const _FormSegments({
    required this.options,
    required this.value,
    required this.onChanged,
  });
  final List<(T, String)> options;
  final T value;
  final ValueChanged<T>? onChanged;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final c = FitCheckColors.of(context);
      if (constraints.maxWidth < 300 ||
          MediaQuery.textScalerOf(context).scale(14) > 17.5) {
        return Wrap(
          spacing: AppSpace.sm,
          runSpacing: AppSpace.sm,
          children: [
            for (final option in options)
              AppChoice(
                label: option.$2,
                selected: value == option.$1,
                onPressed: onChanged == null
                    ? null
                    : () => onChanged!(option.$1),
              ),
          ],
        );
      }
      return Material(
        color: c.subtle,
        borderRadius: BorderRadius.circular(AppRadius.full),
        child: Row(
          children: [
            for (final option in options)
              Expanded(
                child: Semantics(
                  button: true,
                  selected: value == option.$1,
                  enabled: onChanged != null,
                  label: option.$2,
                  onTap: onChanged == null ? null : () => onChanged!(option.$1),
                  excludeSemantics: true,
                  child: InkWell(
                    onTap: onChanged == null
                        ? null
                        : () => onChanged!(option.$1),
                    borderRadius: BorderRadius.circular(AppRadius.full),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        minHeight: AppSize.touch,
                      ),
                      child: Container(
                        margin: const EdgeInsets.all(AppSpace.xxs),
                        constraints: const BoxConstraints(
                          minHeight: AppSize.touch - AppSpace.xs,
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpace.sm,
                        ),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: value == option.$1 ? c.accentSubtle : c.subtle,
                          borderRadius: BorderRadius.circular(AppRadius.full),
                          border: Border.all(
                            color: value == option.$1 ? c.accent : c.subtle,
                          ),
                        ),
                        child: Text(
                          option.$2,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.labelMedium
                              ?.copyWith(
                                color: value == option.$1
                                    ? c.accent
                                    : c.secondary,
                              ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
    },
  );
}

class AppChoice extends StatelessWidget {
  const AppChoice({
    super.key,
    required this.label,
    required this.selected,
    required this.onPressed,
  });
  final String label;
  final bool selected;
  final VoidCallback? onPressed;
  @override
  Widget build(BuildContext context) {
    final c = FitCheckColors.of(context);
    return Semantics(
      selected: selected,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          backgroundColor: selected ? c.accentSubtle : c.surface,
          foregroundColor: selected ? c.accent : c.primary,
          side: BorderSide(color: selected ? c.accent : c.border),
          textStyle: Theme.of(context).textTheme.labelMedium,
        ),
        onPressed: onPressed,
        child: Text('${selected ? '✓ ' : ''}$label'),
      ),
    );
  }
}

class _DashedBorder extends CustomPainter {
  _DashedBorder(this.color);
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Offset.zero & size,
          const Radius.circular(AppRadius.lg),
        ),
      );
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = AppSize.stroke;
    for (final metric in path.computeMetrics()) {
      for (double offset = 0; offset < metric.length; offset += AppSpace.sm) {
        canvas.drawPath(
          metric.extractPath(
            offset,
            math.min(offset + AppSpace.xs, metric.length),
          ),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorder oldDelegate) => oldDelegate.color != color;
}

class _NewOccasion extends StatefulWidget {
  const _NewOccasion({required this.repository});
  final WardrobeRepository repository;
  @override
  State<_NewOccasion> createState() => _NewOccasionState();
}

class _NewOccasionState extends State<_NewOccasion> {
  final _name = TextEditingController();
  bool _saving = false;
  String? _error;
  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final occasion = await widget.repository.addOccasion(_name.text);
      if (mounted) Navigator.pop(context, occasion);
    } on WardrobeFailure catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Could not save this occasion. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(
      AppSpace.lg,
      AppSpace.lg,
      AppSpace.lg,
      MediaQuery.viewInsetsOf(context).bottom + AppSpace.xxl,
    ),
    child: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'New occasion',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              IconButton(
                tooltip: 'Close new occasion',
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const SizedBox(height: AppSpace.lg),
          TextField(
            controller: _name,
            autofocus: true,
            maxLength: 40,
            enabled: !_saving,
            decoration: const InputDecoration(labelText: 'Occasion name'),
            onSubmitted: (_) => _save(),
          ),
          if (_error != null) InlineMessage(_error!, isError: true),
          const SizedBox(height: AppSpace.lg),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: Text(_saving ? 'Saving…' : 'Save occasion'),
          ),
        ],
      ),
    ),
  );
}
