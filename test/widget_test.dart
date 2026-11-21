import 'package:fitcheck/app.dart';
import 'package:fitcheck/auth/auth_gateway.dart';
import 'package:fitcheck/settings/app_preferences.dart';
import 'package:fitcheck/theme/fitcheck_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_auth_gateway.dart';
import 'support/memory_fragrance_repository.dart';
import 'support/memory_wardrobe_repository.dart';
import 'support/memory_outfit_repository.dart';

void main() {
  late FakeAuthGateway auth;
  late AppPreferences preferences;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    preferences = AppPreferences(await SharedPreferences.getInstance());
    auth = FakeAuthGateway();
  });
  tearDown(() async {
    preferences.dispose();
    await auth.dispose();
  });
  Future<void> pumpApp(WidgetTester tester, {bool signedIn = false}) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    if (signedIn) await auth.signIn('test@example.com', 'password1');
    await tester.pumpWidget(
      FitCheckApp(
        auth: auth,
        preferences: preferences,
        repositoryFactory: (_) => MemoryWardrobeRepository(),
        outfitRepositoryFactory: (_) => MemoryOutfitRepository(),
        fragranceRepositoryFactory: (_) {
          final repository = MemoryFragranceRepository();
          addTearDown(repository.dispose);
          return repository;
        },
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('invalid credentials are validated before calling auth', (
    tester,
  ) async {
    await pumpApp(tester);
    await tester.tap(find.byKey(const Key('auth-submit')));
    await tester.pumpAndSettle();
    expect(find.text('Enter a valid email address.'), findsOneWidget);
    expect(find.text('Enter your password.'), findsOneWidget);
    expect(auth.signInCalls, 0);
  });
  testWidgets('failed sign-in stays inline and can be retried', (tester) async {
    await pumpApp(tester);
    await tester.enterText(
      find.byKey(const Key('auth-email')),
      'test@example.com',
    );
    await tester.enterText(
      find.byKey(const Key('auth-password')),
      'bad-password',
    );
    auth.failure = const AuthFailure(
      'Your email or password did not match. Please try again.',
    );
    await tester.tap(find.byKey(const Key('auth-submit')));
    await tester.pumpAndSettle();
    expect(find.textContaining('did not match'), findsOneWidget);
    auth.failure = null;
    await tester.tap(find.byKey(const Key('auth-submit')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('screen-title')), findsOneWidget);
    expect(find.text('Let’s add your clothes'), findsOneWidget);
  });
  testWidgets('new accounts require eight characters', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('Create an account'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('auth-email')),
      'new@example.com',
    );
    await tester.enterText(find.byKey(const Key('auth-password')), 'short');
    await tester.tap(find.byKey(const Key('auth-submit')));
    await tester.pumpAndSettle();
    expect(find.text('Use at least 8 characters.'), findsOneWidget);
    expect(auth.currentUser, isNull);
  });
  testWidgets('navigation preserves the viewed calendar month', (tester) async {
    await pumpApp(tester, signedIn: true);
    await tester.tap(find.byKey(const Key('nav-planner')));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Next month'));
    await tester.pumpAndSettle();
    final month = tester
        .widget<Text>(find.byKey(const Key('calendar-month')))
        .data;
    await tester.tap(find.byKey(const Key('nav-today')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('nav-planner')));
    await tester.pumpAndSettle();
    expect(
      tester.widget<Text>(find.byKey(const Key('calendar-month'))).data,
      month,
    );
  });
  testWidgets('appearance persists and sign-out clears the shell', (
    tester,
  ) async {
    await pumpApp(tester, signedIn: true);
    await tester.tap(find.byKey(const Key('account-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dark'));
    await tester.pumpAndSettle();
    expect(preferences.themeMode, ThemeMode.dark);
    expect(
      AppPreferences(await SharedPreferences.getInstance()).themeMode,
      ThemeMode.dark,
    );
    expect(
      FitCheckColors.of(tester.element(find.text('Appearance'))).canvas,
      FitCheckColors.dark.canvas,
    );
    await tester.tap(find.text('Sign out'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('auth-submit')), findsOneWidget);
    expect(find.byKey(const Key('nav-today')), findsNothing);
  });
  testWidgets('all destinations fit small screens with enlarged text', (
    tester,
  ) async {
    await pumpApp(tester, signedIn: true);
    tester.view.physicalSize = const Size(320, 640);
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpAndSettle();
    for (final page in ['wardrobe', 'planner', 'today']) {
      await tester.tap(find.byKey(Key('nav-$page')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets(
    'sign-out closes an open item form before another account can use it',
    (tester) async {
      await pumpApp(tester, signedIn: true);
      await tester.tap(find.text('Add clothes'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('save-item')), findsOneWidget);
      await auth.signOut();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('save-item')), findsNothing);
      expect(find.byKey(const Key('auth-submit')), findsOneWidget);
      await auth.signIn('other@example.com', 'password2');
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('save-item')), findsNothing);
      expect(find.byKey(const Key('nav-today')), findsOneWidget);
    },
  );
}
