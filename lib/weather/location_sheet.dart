import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/fitcheck_theme.dart';
import '../widgets/common.dart';
import 'weather_service.dart';
import 'weather_store.dart';

Future<void> showLocationSheet(BuildContext context, WeatherStore weather) =>
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (_) => LocationSheet(weather: weather),
    );

class LocationSheet extends StatefulWidget {
  const LocationSheet({super.key, required this.weather});
  final WeatherStore weather;
  @override
  State<LocationSheet> createState() => _LocationSheetState();
}

class _LocationSheetState extends State<LocationSheet> {
  final _query = TextEditingController();
  List<WeatherLocation> _results = const [];
  bool _searching = false, _saving = false, _searched = false;
  String? _error;
  int _generation = 0;

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    if (_saving) return;
    final query = _query.text.trim();
    if (query.length < 2) {
      setState(() => _error = 'Enter at least two letters of your city.');
      return;
    }
    final generation = ++_generation;
    FocusScope.of(context).unfocus();
    setState(() {
      _searching = true;
      _error = null;
      _results = const [];
    });
    try {
      final results = await widget.weather.searchLocations(query);
      if (!mounted || generation != _generation) return;
      setState(() {
        _results = results;
        _searched = true;
      });
    } on WeatherFailure catch (error) {
      if (mounted && generation == _generation) {
        setState(() => _error = error.message);
      }
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _searching = false);
      }
    }
  }

  Future<void> _select(WeatherLocation location) async {
    if (_saving || _searching) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.weather.setLocation(location);
      if (mounted) Navigator.pop(context);
    } on WeatherFailure catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return PopScope(
      canPop: !_saving,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * .9,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpace.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text('Weather location', style: text.titleLarge),
                    ),
                    IconButton(
                      tooltip: 'Close weather location',
                      onPressed: _saving ? null : () => Navigator.pop(context),
                      icon: const AppSvg('close'),
                    ),
                  ],
                ),
                const Text('Choose a city for your fragrance recommendations.'),
                const SizedBox(height: AppSpace.lg),
                TextField(
                  controller: _query,
                  enabled: !_saving,
                  maxLength: 200,
                  decoration: const InputDecoration(labelText: 'City name'),
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => _search(),
                  onChanged: (_) {
                    ++_generation;
                    setState(() {
                      _results = const [];
                      _searched = false;
                      _searching = false;
                    });
                  },
                ),
                const SizedBox(height: AppSpace.sm),
                FilledButton(
                  onPressed: _saving || _searching ? null : _search,
                  child: Text(_searching ? 'Searching…' : 'Search cities'),
                ),
                if (_saving)
                  const Padding(
                    padding: EdgeInsets.all(AppSpace.lg),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                if (_error != null) InlineMessage(_error!, isError: true),
                if (_searched && _results.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: AppSpace.lg),
                    child: Text(
                      'No cities found. Try a nearby city or another spelling.',
                    ),
                  ),
                for (final location in _results)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(location.name),
                    subtitle: Text(
                      [
                        if (location.country != null) location.country!,
                        '${location.latitude.toStringAsFixed(2)}, ${location.longitude.toStringAsFixed(2)}',
                      ].join(' · '),
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: _saving || _searching
                        ? null
                        : () => _select(location),
                  ),
                const WeatherAttribution(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class WeatherAttribution extends StatelessWidget {
  const WeatherAttribution({super.key});
  @override
  Widget build(BuildContext context) => Wrap(
    alignment: WrapAlignment.center,
    children: [
      TextButton(
        onPressed: () => launchUrl(Uri.parse('https://open-meteo.com/')),
        child: const Text('Weather by Open-Meteo'),
      ),
      TextButton(
        onPressed: () => launchUrl(
          Uri.parse('https://creativecommons.org/licenses/by/4.0/'),
        ),
        child: const Text('CC BY 4.0'),
      ),
    ],
  );
}
