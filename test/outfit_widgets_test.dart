import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:fitcheck/outfits/outfit_picker.dart';
import 'package:fitcheck/theme/fitcheck_theme.dart';
import 'package:fitcheck/today/outfit_card.dart';
import 'package:fitcheck/today/outfit_sheets.dart';
import 'package:fitcheck/wardrobe/wardrobe_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const top = ClothingItem(
  id: 'top',
  name: 'Navy polo',
  colorName: 'Navy blue',
  category: ClothingCategory.top,
  formality: Formality.smartCasual,
  occasionIds: ['school'],
);
const bottom = ClothingItem(
  id: 'bottom',
  name: 'Beige chinos',
  colorName: 'Beige',
  category: ClothingCategory.bottom,
  formality: Formality.smartCasual,
  occasionIds: ['school'],
);
const shoes = ClothingItem(
  id: 'shoes',
  name: 'White sneakers',
  colorName: 'White',
  category: ClothingCategory.shoes,
  formality: Formality.casual,
  occasionIds: ['school'],
);
const alternate = ClothingItem(
  id: 'alternate',
  name: 'Gray henley',
  colorName: 'Gray',
  category: ClothingCategory.top,
  formality: Formality.smartCasual,
  occasionIds: ['school'],
);
final suggestion = OutfitSuggestion(
  date: DateTime(2026, 11, 2),
  occasion: const Occasion('school', 'School'),
  top: top,
  bottom: bottom,
  shoes: shoes,
  reason: 'Fits your School plan.',
);

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final loader = FontLoader('Plus Jakarta Sans')
      ..addFont(rootBundle.load('assets/fonts/PlusJakartaSans.ttf'));
    await loader.load();
  });
  void viewport(WidgetTester tester, {Size size = const Size(360, 800)}) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Widget app(Widget home, {double scale = 1, ThemeData? theme}) => MaterialApp(
    theme: theme ?? FitCheckTheme.light,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context)
          .copyWith(textScaler: TextScaler.linear(scale)),
      child: child!,
    ),
    home: home,
  );

  testWidgets('card callbacks stay reachable with enlarged text', (
    tester,
  ) async {
    viewport(tester, size: const Size(320, 800));
    final semantics = tester.ensureSemantics();
    try {
      final actions = <String>[];
      await tester.pumpWidget(
        app(
          Scaffold(
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpace.lg),
              child: OutfitCard(
                outfit: suggestion,
                onWear: () => actions.add('wear'),
                onSwapAll: () => actions.add('all'),
                onSwapItem: (item) => actions.add(item.id),
                onViewOutfit: () => actions.add('view'),
              ),
            ),
          ),
          scale: 2,
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(
        find.bySemanticsLabel('Swap top: Navy polo, Navy blue, Clean'),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('outfit-item-top')));
      await tester.ensureVisible(find.text('Swap all'));
      await tester.tap(find.text('Swap all'));
      await tester.tap(find.text('View outfit'));
      await tester.tap(find.text('Wear this'));
      expect(actions, ['top', 'all', 'view', 'wear']);
      expect(
        tester.getSize(find.byKey(const ValueKey('outfit-item-top'))).height,
        greaterThanOrEqualTo(AppSize.touch),
      );
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('swap selection waits for confirmation and keeps current first', (
    tester,
  ) async {
    viewport(tester);
    ClothingItem? confirmed;
    await tester.pumpWidget(
      app(
        Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                confirmed = await showSwapItemSheet(
                  context,
                  category: ClothingCategory.top,
                  occasion: suggestion.occasion,
                  candidates: [alternate, top],
                  currentItemId: top.id,
                );
              },
              child: const Text('Open swap'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open swap'));
    await tester.pumpAndSettle();
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('swap-option-top'))).dy,
      lessThan(
        tester
            .getTopLeft(find.byKey(const ValueKey('swap-option-alternate')))
            .dy,
      ),
    );
    await tester.tap(find.byKey(const ValueKey('swap-option-alternate')));
    await tester.pumpAndSettle();
    expect(confirmed, isNull);
    expect(find.text('Current pick'), findsOneWidget);
    await tester.tap(find.text('Use this top'));
    await tester.pumpAndSettle();
    expect(confirmed?.id, alternate.id);
  });

  testWidgets(
    'swap sheet closes without selection through close or outside tap',
    (tester) async {
      viewport(tester);
      ClothingItem? confirmed;
      var completed = 0;
      await tester.pumpWidget(
        app(
          Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  confirmed = await showSwapItemSheet(
                    context,
                    category: ClothingCategory.top,
                    occasion: suggestion.occasion,
                    candidates: [top, alternate],
                    currentItemId: top.id,
                  );
                  completed++;
                },
                child: const Text('Open swap'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open swap'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Close swap item'));
      await tester.pumpAndSettle();
      expect(confirmed, isNull);
      expect(completed, 1);
      await tester.tap(find.text('Open swap'));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(2, 2));
      await tester.pumpAndSettle();
      expect(confirmed, isNull);
      expect(completed, 2);
    },
  );

  testWidgets(
    'full outfit names remain untruncated and failed wear is retryable',
    (tester) async {
      viewport(tester, size: const Size(320, 640));
      const longName =
          'Dark navy blue long-sleeve Oxford shirt with a very long wardrobe name';
      final outfit = OutfitSuggestion(
        date: suggestion.date,
        occasion: suggestion.occasion,
        top: const ClothingItem(
          id: 'long',
          name: longName,
          colorName: 'Dark navy blue',
          category: ClothingCategory.top,
          formality: Formality.formal,
          occasionIds: ['school'],
        ),
        bottom: bottom,
        shoes: shoes,
        reason: suggestion.reason,
      );
      final request = Completer<void>();
      var calls = 0;
      await tester.pumpWidget(
        app(
          ViewOutfitScreen(
            outfit: outfit,
            onWear: () {
              calls++;
              return calls == 1 ? request.future : Future.value();
            },
          ),
          scale: 2,
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.widget<Text>(find.text(longName)).maxLines, isNull);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Wear this'));
      await tester.pump();
      expect(find.text('Saving outfit…'), findsOneWidget);
      request.completeError(
        const OutfitWearFailure('The selected top needs washing.'),
      );
      await tester.pumpAndSettle();
      expect(find.text('The selected top needs washing.'), findsOneWidget);
      expect(find.text('Wear this'), findsOneWidget);
      await tester.tap(find.text('Wear this'));
      await tester.pumpAndSettle();
      expect(find.text('Worn today'), findsOneWidget);
      expect(calls, 2);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('busy and worn cards prevent another wear or swap', (
    tester,
  ) async {
    viewport(tester);
    var changes = 0;
    var views = 0;
    for (final worn in [false, true]) {
      await tester.pumpWidget(
        app(
          Scaffold(
            body: SingleChildScrollView(
              child: OutfitCard(
                outfit: suggestion,
                busy: !worn,
                worn: worn,
                onWear: () => changes++,
                onSwapAll: () => changes++,
                onSwapItem: (_) => changes++,
                onViewOutfit: () => views++,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('outfit-item-top')));
      await tester.tap(find.text('Swap all'));
      await tester.tap(find.text(worn ? 'Worn today' : 'Saving outfit…'));
      await tester.tap(find.text('View outfit'));
      expect(changes, 0);
      expect(views, worn ? 2 : 1);
    }
  });

  testWidgets('view refreshes laundry from updates after successful wear', (
    tester,
  ) async {
    viewport(tester);
    final latest = ValueNotifier<OutfitSuggestion?>(null);
    addTearDown(latest.dispose);
    await tester.pumpWidget(
      app(
        ViewOutfitScreen(
          outfit: suggestion,
          updates: latest,
          resolveOutfit: () => latest.value,
          onWear: () async {
            latest.value = OutfitSuggestion(
              date: suggestion.date,
              occasion: suggestion.occasion,
              top: ClothingItem(
                id: top.id,
                name: top.name,
                colorName: top.colorName,
                category: top.category,
                formality: top.formality,
                occasionIds: top.occasionIds,
                // The repository may have observed a newer count than the route.
                wearsSinceWash: 2,
              ),
              bottom: bottom,
              shoes: shoes,
              reason: suggestion.reason,
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('To wash'), findsNothing);
    expect(find.text(top.name), findsOneWidget);
    await tester.tap(find.text('Wear this'));
    await tester.pumpAndSettle();
    expect(find.text('Worn today'), findsOneWidget);
    expect(find.text('To wash'), findsOneWidget);
    // Lost references keep the original outfit visible and do not crash.
    latest.value = null;
    await tester.pump();
    expect(find.text(top.name), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('empty swap remains dismissible with enlarged dark text', (
    tester,
  ) async {
    viewport(tester, size: const Size(320, 640));
    await tester.pumpWidget(
      app(
        Scaffold(
          body: SwapItemsSheet(
            category: ClothingCategory.shoes,
            occasion: const Occasion(
              'custom',
              'A special occasion with a long name',
            ),
            candidates: const [],
            currentItemId: 'missing',
          ),
        ),
        scale: 2,
        theme: FitCheckTheme.dark,
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byTooltip('Close swap item'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Use these shoes'),
          )
          .onPressed,
      isNull,
    );
  });

  testWidgets('render outfit surfaces with local Figma assets', (tester) async {
    viewport(tester);
    final boundary = GlobalKey();
    Future<void> capture(String name) async {
      final render =
          boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      await tester.runAsync(() async {
        final image = await render.toImage(pixelRatio: 1);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        final file = File('artifacts/$name.png');
        await file.parent.create(recursive: true);
        await file.writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }

    await tester.pumpWidget(
      app(
        RepaintBoundary(
          key: boundary,
          child: Scaffold(
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpace.lg),
              child: OutfitCard(
                outfit: suggestion,
                onWear: () {},
                onSwapAll: () {},
                onSwapItem: (_) {},
                onViewOutfit: () {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await capture('outfit-card-light');
    await tester.pumpWidget(
      app(
        RepaintBoundary(
          key: boundary,
          child: ViewOutfitScreen(outfit: suggestion, onWear: () async {}),
        ),
        theme: FitCheckTheme.dark,
      ),
    );
    await tester.pumpAndSettle();
    await capture('outfit-detail-dark');
  }, skip: !const bool.fromEnvironment('CAPTURE_OUTFIT_WIDGETS'));
}
