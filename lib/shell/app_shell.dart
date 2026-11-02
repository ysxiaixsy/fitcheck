import 'package:flutter/material.dart';

import '../auth/auth_gateway.dart';
import '../settings/app_preferences.dart';
import '../theme/fitcheck_theme.dart';
import '../widgets/common.dart';
import '../today/today_screen.dart';
import '../wardrobe/wardrobe_screen.dart';
import '../planner/planner_screen.dart';

class AppShell extends StatefulWidget {
  const AppShell({
    super.key,
    required this.user,
    required this.auth,
    required this.preferences,
  });
  final AuthUser user;
  final AuthGateway auth;
  final AppPreferences preferences;
  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;
  String _filter = 'All';
  void _wardrobe({bool scents = false}) => setState(() {
    _filter = scents ? 'Scents' : 'All';
    _index = 1;
  });
  Future<void> _account() => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _AccountSheet(
      user: widget.user,
      auth: widget.auth,
      preferences: widget.preferences,
    ),
  );
  @override
  Widget build(BuildContext context) {
    final c = FitCheckColors.of(context);
    final text = Theme.of(context).textTheme;
    final pages = [
      TodayScreen(
        onAddClothes: () => _wardrobe(),
        onAddFragrance: () => _wardrobe(scents: true),
      ),
      WardrobeScreen(
        filter: _filter,
        onFilterChanged: (value) => setState(() => _filter = value),
      ),
      const PlannerScreen(),
    ];
    const labels = ['Today', 'Wardrobe', 'Planner'];
    const icons = ['home', 'wardrobe', 'calendar'];
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: AppSize.contentWidth),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpace.lg),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      minHeight: AppSize.header,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Semantics(
                            header: true,
                            child: Text(
                              labels[_index],
                              key: const Key('screen-title'),
                              style: text.displayLarge,
                            ),
                          ),
                        ),
                        IconButton(
                          key: const Key('account-menu'),
                          tooltip: 'Account and appearance',
                          onPressed: _account,
                          icon: const Icon(Icons.account_circle_outlined),
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: IndexedStack(index: _index, children: pages),
                ),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: c.surface,
                    border: Border(top: BorderSide(color: c.border)),
                  ),
                  child: SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpace.sm,
                        AppSpace.sm,
                        AppSpace.sm,
                        AppSpace.sm,
                      ),
                      child: Row(
                        children: List.generate(labels.length, (i) {
                          final selected = _index == i;
                          return Expanded(
                            child: Semantics(
                              selected: selected,
                              button: true,
                              label: labels[i],
                              child: ExcludeSemantics(
                                child: InkWell(
                                  key: Key('nav-${labels[i].toLowerCase()}'),
                                  borderRadius: BorderRadius.circular(
                                    AppRadius.lg,
                                  ),
                                  onTap: () => setState(() => _index = i),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: AppSpace.xs,
                                    ),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Container(
                                          width: AppSize.navPillWidth,
                                          height: AppSize.navPillHeight,
                                          decoration: BoxDecoration(
                                            color: selected
                                                ? c.accentSubtle
                                                : null,
                                            borderRadius: BorderRadius.circular(
                                              AppRadius.full,
                                            ),
                                          ),
                                          alignment: Alignment.center,
                                          child: AppSvg(
                                            icons[i],
                                            color: selected
                                                ? c.primary
                                                : c.secondary,
                                          ),
                                        ),
                                        const SizedBox(height: AppSpace.xs),
                                        Text(
                                          labels[i],
                                          style: text.labelSmall?.copyWith(
                                            color: selected
                                                ? c.primary
                                                : c.secondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
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

class _AccountSheet extends StatefulWidget {
  const _AccountSheet({
    required this.user,
    required this.auth,
    required this.preferences,
  });
  final AuthUser user;
  final AuthGateway auth;
  final AppPreferences preferences;
  @override
  State<_AccountSheet> createState() => _AccountSheetState();
}

class _AccountSheetState extends State<_AccountSheet> {
  String? _error;
  bool _busy = false;
  Future<void> _theme(ThemeMode? value) async {
    if (value == null) return;
    try {
      await widget.preferences.setThemeMode(value);
      if (mounted) setState(() => _error = null);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Could not save your appearance. Try again.');
      }
    }
  }

  Future<void> _signOut() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.auth.signOut();
      if (mounted) Navigator.of(context).pop();
    } on AuthFailure catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.preferences,
    builder: (context, _) => SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpace.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Your account',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  tooltip: 'Close account',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            Text(widget.user.email),
            const SizedBox(height: AppSpace.xxl),
            Text('Appearance', style: Theme.of(context).textTheme.titleLarge),
            RadioGroup<ThemeMode>(
              groupValue: widget.preferences.themeMode,
              onChanged: _theme,
              child: Column(
                children: [
                  for (final item in [
                    (ThemeMode.system, 'Use device setting'),
                    (ThemeMode.light, 'Light'),
                    (ThemeMode.dark, 'Dark'),
                  ])
                    RadioListTile<ThemeMode>(
                      value: item.$1,
                      title: Text(item.$2),
                      contentPadding: EdgeInsets.zero,
                    ),
                ],
              ),
            ),
            if (_error != null) InlineMessage(_error!, isError: true),
            const SizedBox(height: AppSpace.lg),
            OutlinedButton(
              onPressed: _busy ? null : _signOut,
              child: Text(_busy ? 'Signing out…' : 'Sign out'),
            ),
          ],
        ),
      ),
    ),
  );
}
