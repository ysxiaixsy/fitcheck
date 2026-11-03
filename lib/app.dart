import 'dart:async';

import 'package:flutter/material.dart';

import 'auth/auth_gateway.dart';
import 'auth/auth_screen.dart';
import 'settings/app_preferences.dart';
import 'shell/app_shell.dart';
import 'theme/fitcheck_theme.dart';
import 'wardrobe/wardrobe_repository.dart';
import 'outfits/outfit_repository.dart';
import 'fragrance/fragrance_repository.dart';
import 'weather/weather_service.dart';

class FitCheckApp extends StatefulWidget {
  const FitCheckApp({
    super.key,
    required this.auth,
    required this.preferences,
    this.repositoryFactory,
    this.outfitRepositoryFactory,
    this.fragranceRepositoryFactory,
    this.weatherServiceFactory,
  });
  final AuthGateway auth;
  final AppPreferences preferences;
  final WardrobeRepository Function(String userId)? repositoryFactory;
  final OutfitRepository Function(String userId)? outfitRepositoryFactory;
  final FragranceRepository Function(String userId)? fragranceRepositoryFactory;
  final WeatherService Function()? weatherServiceFactory;
  @override
  State<FitCheckApp> createState() => _FitCheckAppState();
}

class _FitCheckAppState extends State<FitCheckApp> {
  final _navigator = GlobalKey<NavigatorState>();
  StreamSubscription<AuthUser?>? _subscription;
  AuthUser? _user;
  bool _ready = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    _listen();
  }

  void _listen() {
    _user = widget.auth.currentUser;
    _ready = _user != null;
    _error = null;
    _subscription = widget.auth.changes.listen(
      (user) {
        if (!mounted) return;
        if (_user?.id != user?.id) {
          _navigator.currentState?.popUntil((route) => route.isFirst);
        }
        setState(() {
          _user = user;
          _ready = true;
          _error = null;
        });
      },
      onError: (_) {
        if (mounted) {
          setState(
            () => _error = 'Could not check your account. Please try again.',
          );
        }
      },
    );
  }

  Future<void> _retry() async {
    await _subscription?.cancel();
    if (mounted) setState(_listen);
  }

  @override
  void didUpdateWidget(covariant FitCheckApp oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.auth != widget.auth) {
      _subscription?.cancel();
      _listen();
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.preferences,
    builder: (context, _) => MaterialApp(
      navigatorKey: _navigator,
      title: 'FitCheck',
      debugShowCheckedModeBanner: false,
      theme: FitCheckTheme.light,
      darkTheme: FitCheckTheme.dark,
      themeMode: widget.preferences.themeMode,
      home: _error != null
          ? Scaffold(
              body: SafeArea(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpace.xxl),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_error!),
                        const SizedBox(height: AppSpace.lg),
                        FilledButton(
                          onPressed: _retry,
                          child: const Text('Try again'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            )
          : !_ready
          ? const Scaffold(body: Center(child: CircularProgressIndicator()))
          : _user == null
          ? AuthScreen(auth: widget.auth)
          : AppShell(
              key: ValueKey(_user!.id),
              user: _user!,
              auth: widget.auth,
              preferences: widget.preferences,
              repositoryFactory: widget.repositoryFactory,
              outfitRepositoryFactory: widget.outfitRepositoryFactory,
              fragranceRepositoryFactory: widget.fragranceRepositoryFactory,
              weatherServiceFactory: widget.weatherServiceFactory,
            ),
    ),
  );
}
