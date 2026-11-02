import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'auth/auth_gateway.dart';
import 'firebase_options.dart';
import 'settings/app_preferences.dart';
import 'theme/fitcheck_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const FitCheckBootstrap());
}

class FitCheckBootstrap extends StatefulWidget {
  const FitCheckBootstrap({super.key});
  @override
  State<FitCheckBootstrap> createState() => _FitCheckBootstrapState();
}

class _FitCheckBootstrapState extends State<FitCheckBootstrap> {
  late Future<(AuthGateway, AppPreferences)> _startup;
  @override
  void initState() {
    super.initState();
    _startup = _initialize();
  }

  Future<(AuthGateway, AppPreferences)> _initialize() async {
    const emulators = bool.fromEnvironment('USE_FIREBASE_EMULATORS');
    if (emulators && kReleaseMode) {
      throw StateError('Emulators are unavailable in a release build.');
    }
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: emulators
            ? const FirebaseOptions(
                apiKey: 'demo-fitcheck-api-key',
                appId: '1:123456789:web:fitcheck',
                messagingSenderId: '123456789',
                projectId: 'demo-fitcheck',
                authDomain: 'demo-fitcheck.firebaseapp.com',
              )
            : DefaultFirebaseOptions.currentPlatform,
      );
    }
    final auth = FirebaseAuth.instance;
    if (emulators) {
      const overrideHost = String.fromEnvironment('FIREBASE_EMULATOR_HOST');
      final host = overrideHost.isNotEmpty
          ? overrideHost
          : !kIsWeb && defaultTargetPlatform == TargetPlatform.android
          ? '10.0.2.2'
          : '127.0.0.1';
      await auth.useAuthEmulator(host, 9099);
    }
    if (kIsWeb) await auth.setPersistence(Persistence.LOCAL);
    return (
      FirebaseAuthGateway(auth),
      AppPreferences(await SharedPreferences.getInstance()),
    );
  }

  @override
  Widget build(BuildContext context) => FutureBuilder(
    future: _startup,
    builder: (context, snapshot) {
      if (snapshot.hasData) {
        final (auth, preferences) = snapshot.data!;
        return FitCheckApp(auth: auth, preferences: preferences);
      }
      return MaterialApp(
        title: 'FitCheck',
        debugShowCheckedModeBanner: false,
        theme: FitCheckTheme.light,
        darkTheme: FitCheckTheme.dark,
        home: Scaffold(
          body: SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpace.xxl),
                child: snapshot.hasError
                    ? Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'FitCheck could not start. Check your connection and try again.',
                          ),
                          const SizedBox(height: AppSpace.lg),
                          FilledButton(
                            onPressed: () =>
                                setState(() => _startup = _initialize()),
                            child: const Text('Try again'),
                          ),
                        ],
                      )
                    : const CircularProgressIndicator(),
              ),
            ),
          ),
        ),
      );
    },
  );
}
