import 'package:firebase_auth/firebase_auth.dart';
import 'package:fitcheck/main.dart' as app;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('emulator account creation, reset, sign-out, and sign-in', (
    tester,
  ) async {
    const emulators = bool.fromEnvironment('USE_FIREBASE_EMULATORS');
    expect(
      emulators,
      isTrue,
      reason: 'This test must only run against demo-fitcheck.',
    );
    app.main();
    await tester.pumpAndSettle();
    final auth = FirebaseAuth.instance;
    expect(auth.app.options.projectId, 'demo-fitcheck');
    if (auth.currentUser != null) await auth.signOut();
    await tester.pumpAndSettle();
    final email =
        'fitcheck-${DateTime.now().microsecondsSinceEpoch}@example.test';
    const password = 'FitCheck-test-2026!';
    await tester.tap(find.text('Create an account'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('auth-email')), email);
    await tester.enterText(find.byKey(const Key('auth-password')), password);
    await tester.tap(find.byKey(const Key('auth-submit')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('nav-today')), findsOneWidget);
    await tester.tap(find.byKey(const Key('account-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sign out'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('auth-email')), email);
    await tester.tap(find.text('Reset password'));
    await tester.pumpAndSettle();
    expect(find.textContaining('password reset link'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('auth-password')), password);
    await tester.tap(find.byKey(const Key('auth-submit')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('nav-today')), findsOneWidget);
    await auth.currentUser!.delete();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('auth-submit')), findsOneWidget);
  });
}
