import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../theme/fitcheck_theme.dart';
import '../widgets/common.dart';
import 'fragrance.dart';
import 'fragrance_repository.dart';

class FragranceFormScreen extends StatefulWidget {
  const FragranceFormScreen({
    super.key,
    required this.repository,
    this.fragrance,
  });
  final FragranceRepository repository;
  final Fragrance? fragrance;

  @override
  State<FragranceFormScreen> createState() => _FragranceFormScreenState();
}

class _FragranceFormScreenState extends State<FragranceFormScreen> {
  final _form = GlobalKey<FormState>();
  final _scroll = ScrollController();
  late final TextEditingController _name, _notes;
  late final String _id;
  TemperatureBand? _temperature;
  HumidityBand? _humidity;
  Uint8List? _photo;
  String? _mimeType, _error;
  bool _saving = false, _picking = false, _submitted = false;

  @override
  void initState() {
    super.initState();
    final item = widget.fragrance;
    _id = item?.id ?? widget.repository.createId();
    _name = TextEditingController(text: item?.name ?? '');
    _notes = TextEditingController(text: item?.scentNotes ?? '');
    _temperature = item?.temperatureBand;
    _humidity = item?.humidityBand;
  }

  @override
  void dispose() {
    _name.dispose();
    _notes.dispose();
    _scroll.dispose();
    super.dispose();
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

  void _showError(String message) {
    if (!mounted) return;
    setState(() => _error = message);
    _scrollToStart();
  }

  Future<void> _pickPhoto() async {
    if (_saving || _picking) return;
    setState(() => _picking = true);
    try {
      final file = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1200,
        imageQuality: 85,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      final extension = file.name.toLowerCase();
      final mime =
          file.mimeType ??
          (extension.endsWith('.png')
              ? 'image/png'
              : extension.endsWith('.webp')
              ? 'image/webp'
              : extension.endsWith('.jpg') || extension.endsWith('.jpeg')
              ? 'image/jpeg'
              : '');
      if (bytes.length > 5 * 1024 * 1024 ||
          !['image/jpeg', 'image/png', 'image/webp'].contains(mime)) {
        throw const FragranceFailure(
          'Choose a JPG, PNG, or WebP photo smaller than 5 MB.',
        );
      }
      if (mounted) {
        setState(() {
          _photo = bytes;
          _mimeType = mime;
          _error = null;
        });
      }
    } on FragranceFailure catch (error) {
      _showError(error.message);
    } catch (_) {
      _showError('Could not open this photo. Please try another.');
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  Future<void> _save() async {
    if (_saving || _picking) return;
    setState(() => _submitted = true);
    final valid = _form.currentState!.validate();
    if (!valid || _temperature == null || _humidity == null) {
      _scrollToStart();
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final fragrance = Fragrance(
        id: _id,
        name: _name.text,
        scentNotes: _notes.text,
        temperatureBand: _temperature!,
        humidityBand: _humidity!,
        photoUrl: widget.fragrance?.photoUrl,
      );
      await widget.repository.upsert(
        fragrance,
        photo: _photo,
        mimeType: _mimeType,
      );
      if (mounted) Navigator.pop(context, fragrance);
    } on FragranceFailure catch (error) {
      _showError(error.message);
    } catch (_) {
      _showError('Could not save this fragrance. Please try again.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = FitCheckColors.of(context);
    final text = Theme.of(context).textTheme;
    final busy = _saving || _picking;
    final photoUrl = widget.fragrance?.photoUrl;
    return PopScope(
      canPop: !busy,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: colors.canvas,
          surfaceTintColor: colors.canvas,
          title: Text(
            widget.fragrance == null ? 'Add fragrance' : 'Edit fragrance',
            style: text.titleLarge,
          ),
          leading: IconButton(
            tooltip: 'Close fragrance form',
            onPressed: busy ? null : () => Navigator.pop(context),
            icon: AppSvg('close', color: colors.primary),
          ),
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: AppSize.contentWidth),
            child: Form(
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
                    if (_photo != null || photoUrl != null) ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                        child: _photo != null
                            ? Image.memory(
                                _photo!,
                                height: 160,
                                fit: BoxFit.contain,
                                errorBuilder: (_, _, _) => const Text(
                                  'Could not display photo. Choose another.',
                                ),
                              )
                            : Image.network(
                                photoUrl!,
                                height: 160,
                                fit: BoxFit.contain,
                                errorBuilder: (_, _, _) => const Text(
                                  'Could not display photo. Choose another.',
                                ),
                              ),
                      ),
                      const SizedBox(height: AppSpace.sm),
                    ],
                    OutlinedButton.icon(
                      onPressed: busy ? null : _pickPhoto,
                      icon: AppSvg('camera', color: colors.primary),
                      label: Text(
                        _picking
                            ? 'Opening photos…'
                            : _photo != null || photoUrl != null
                            ? 'Change photo'
                            : 'Add photo',
                      ),
                    ),
                    const SizedBox(height: AppSpace.xs),
                    Text(
                      'Optional. Choose a JPG, PNG, or WebP photo smaller than 5 MB.',
                      style: text.bodySmall?.copyWith(color: colors.secondary),
                    ),
                    const SizedBox(height: AppSpace.lg),
                    TextFormField(
                      key: const Key('fragrance-name'),
                      controller: _name,
                      enabled: !busy,
                      maxLength: 120,
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Fragrance name',
                      ),
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                          ? 'Enter a fragrance name.'
                          : value.trim().length > 120
                          ? 'Use a name up to 120 characters.'
                          : null,
                    ),
                    const SizedBox(height: AppSpace.lg),
                    TextFormField(
                      key: const Key('fragrance-notes'),
                      controller: _notes,
                      enabled: !busy,
                      maxLength: 500,
                      minLines: 2,
                      maxLines: 5,
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        labelText: 'Scent notes (optional)',
                        helperText: 'For example, citrus, jasmine, or cedar.',
                        helperMaxLines: 3,
                      ),
                      validator: (value) => (value?.trim().length ?? 0) > 500
                          ? 'Use notes up to 500 characters.'
                          : null,
                    ),
                    const SizedBox(height: AppSpace.lg),
                    Text(
                      'When do you like to wear it?',
                      style: text.titleMedium,
                    ),
                    const SizedBox(height: AppSpace.sm),
                    Text(
                      'Choose the temperature and humidity you prefer for this fragrance.',
                      style: text.bodyMedium?.copyWith(color: colors.secondary),
                    ),
                    const SizedBox(height: AppSpace.lg),
                    Text('Temperature', style: text.labelLarge),
                    const SizedBox(height: AppSpace.sm),
                    for (final band in TemperatureBand.values)
                      _BandChoice(
                        label: '${band.label} · ${band.rangeLabel}',
                        selected: _temperature == band,
                        onPressed: busy
                            ? null
                            : () => setState(() => _temperature = band),
                      ),
                    if (_submitted && _temperature == null)
                      Text(
                        'Choose a temperature range.',
                        style: text.bodySmall?.copyWith(color: colors.danger),
                      ),
                    const SizedBox(height: AppSpace.lg),
                    Text('Humidity', style: text.labelLarge),
                    const SizedBox(height: AppSpace.sm),
                    for (final band in HumidityBand.values)
                      _BandChoice(
                        label: '${band.label} · ${band.rangeLabel}',
                        selected: _humidity == band,
                        onPressed: busy
                            ? null
                            : () => setState(() => _humidity = band),
                      ),
                    if (_submitted && _humidity == null)
                      Text(
                        'Choose a humidity range.',
                        style: text.bodySmall?.copyWith(color: colors.danger),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
        bottomNavigationBar: DecoratedBox(
          decoration: BoxDecoration(
            color: colors.surface,
            border: Border(top: BorderSide(color: colors.border)),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(AppSpace.lg),
              child: FilledButton(
                key: const Key('save-fragrance'),
                onPressed: busy ? null : _save,
                child: Text(_saving ? 'Saving fragrance…' : 'Save fragrance'),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BandChoice extends StatelessWidget {
  const _BandChoice({
    required this.label,
    required this.selected,
    required this.onPressed,
  });
  final String label;
  final bool selected;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = FitCheckColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.sm),
      child: Semantics(
        selected: selected,
        child: OutlinedButton(
          style: OutlinedButton.styleFrom(
            backgroundColor: selected ? colors.accentSubtle : colors.surface,
            foregroundColor: selected ? colors.accent : colors.primary,
            side: BorderSide(
              color: selected ? colors.accent : colors.borderStrong,
            ),
            alignment: Alignment.centerLeft,
          ),
          onPressed: onPressed,
          child: Text('${selected ? '✓ ' : ''}$label'),
        ),
      ),
    );
  }
}
