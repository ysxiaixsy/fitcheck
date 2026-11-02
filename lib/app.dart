import 'package:flutter/material.dart';

import 'auth/auth_gateway.dart';
import 'auth/auth_screen.dart';
import 'settings/app_preferences.dart';
import 'shell/app_shell.dart';
import 'theme/fitcheck_theme.dart';

class FitCheckApp extends StatefulWidget {
  const FitCheckApp({super.key, required this.auth, required this.preferences});
  final AuthGateway auth;
  final AppPreferences preferences;
  @override
  State<FitCheckApp> createState() => _FitCheckAppState();
}

class _FitCheckAppState extends State<FitCheckApp> {
  late Stream<AuthUser?> _changes;
  @override
  void initState() {
    super.initState();
    _changes = widget.auth.changes;
  }

  @override
  void didUpdateWidget(covariant FitCheckApp oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.auth != widget.auth) _changes = widget.auth.changes;
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.preferences,
    builder: (context, _) => MaterialApp(
      title: 'FitCheck',
      debugShowCheckedModeBanner: false,
      theme: FitCheckTheme.light,
      darkTheme: FitCheckTheme.dark,
      themeMode: widget.preferences.themeMode,
      home: StreamBuilder<AuthUser?>(
        stream: _changes,
        initialData: widget.auth.currentUser,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Scaffold(
              body: SafeArea(
                child: Center(
                  child: Padding(
                    padding: EdgeInsets.all(AppSpace.xxl),
                    child: Text(
                      'Could not check your account. Reopen FitCheck to try again.',
                    ),
                  ),
                ),
              ),
            );
          }
          if (snapshot.connectionState == ConnectionState.waiting &&
              snapshot.data == null) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          final user = snapshot.data;
          return user == null
              ? AuthScreen(auth: widget.auth)
              : AppShell(
                  key: ValueKey(user.id),
                  user: user,
                  auth: widget.auth,
                  preferences: widget.preferences,
                );
        },
      ),
    ),
  );
}
