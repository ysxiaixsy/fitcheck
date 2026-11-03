import 'dart:async';
import 'dart:typed_data';

import 'package:fitcheck/theme/fitcheck_theme.dart';
import 'package:fitcheck/wardrobe/add_item_screen.dart';
import 'package:fitcheck/wardrobe/wardrobe_models.dart';
import 'package:fitcheck/wardrobe/wardrobe_repository.dart';
import 'package:fitcheck/wardrobe/wardrobe_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/memory_wardrobe_repository.dart';

class _ControlledRepository extends MemoryWardrobeRepository {
  Completer<void>? pending;
  bool fail = false;
  int saves = 0;

  @override
  Future<void> addItem(
    ClothingDraft draft, {
    Uint8List? photo,
    String? mimeType,
  }) async {
    saves++;
    if (pending != null) await pending!.future;
    if (fail) {
      throw const WardrobeFailure(
        'Could not save this item. Please try again.',
      );
    }
    await super.addItem(draft, photo: photo, mimeType: mimeType);
  }
}

void main() {
  Future<void> openForm(
    WidgetTester tester,
    _ControlledRepository repository,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final store = WardrobeStore(repository);
    await tester.pumpWidget(
      MaterialApp(
        theme: FitCheckTheme.light,
        home: Builder(
          builder: (context) => Scaffold(
            body: FilledButton(
              onPressed: () => Navigator.push<void>(
                context,
                MaterialPageRoute(builder: (_) => AddItemScreen(store: store)),
              ),
              child: const Text('Open form'),
            ),
          ),
        ),
      ),
    );
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      store.dispose();
      await repository.dispose();
    });
    await tester.tap(find.text('Open form'));
    await tester.pumpAndSettle();
  }

  testWidgets('saving requires a name and a named color', (tester) async {
    final repository = _ControlledRepository();
    await openForm(tester, repository);
    await tester.drag(
      find.byType(SingleChildScrollView).first,
      const Offset(0, -1000),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('save-item')));
    await tester.pumpAndSettle();
    expect(find.text('Enter an item name.'), findsOneWidget);
    expect(find.text('Enter a color name.'), findsOneWidget);
    expect(repository.saves, 0);
  });

  testWidgets('required errors clear as each field is corrected', (
    tester,
  ) async {
    final repository = _ControlledRepository();
    await openForm(tester, repository);
    await tester.tap(find.byKey(const Key('save-item')));
    await tester.pumpAndSettle();
    expect(find.text('Enter an item name.'), findsOneWidget);
    expect(find.text('Enter a color name.'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('item-name')), 'Navy polo');
    await tester.pumpAndSettle();
    expect(find.text('Enter an item name.'), findsNothing);
    expect(find.text('Enter a color name.'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('item-color')), 'Navy blue');
    await tester.pumpAndSettle();
    expect(find.text('Enter a color name.'), findsNothing);
    expect(repository.saves, 0);
  });

  testWidgets('failed save preserves entered details for retry', (
    tester,
  ) async {
    final repository = _ControlledRepository()..fail = true;
    await openForm(tester, repository);
    await tester.enterText(find.byKey(const Key('item-name')), 'Navy polo');
    await tester.enterText(find.byKey(const Key('item-color')), 'Navy blue');
    await tester.tap(find.byKey(const Key('save-item')));
    await tester.pumpAndSettle();
    expect(
      find.text('Could not save this item. Please try again.'),
      findsOneWidget,
    );
    expect(find.text('Navy polo'), findsOneWidget);
    expect(find.text('Navy blue'), findsOneWidget);
    repository.fail = false;
    await tester.tap(find.byKey(const Key('save-item')));
    await tester.pumpAndSettle();
    expect(repository.items.single.name, 'Navy polo');
    expect(repository.items.single.colorName, 'Navy blue');
    expect(find.text('Open form'), findsOneWidget);
  });

  testWidgets('pending save blocks duplicate submissions and back navigation', (
    tester,
  ) async {
    final repository = _ControlledRepository()..pending = Completer<void>();
    await openForm(tester, repository);
    await tester.enterText(find.byKey(const Key('item-name')), 'Navy polo');
    await tester.enterText(find.byKey(const Key('item-color')), 'Navy blue');
    await tester.tap(find.byKey(const Key('save-item')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('save-item')));
    await tester.pump();
    await Navigator.of(tester.element(find.byType(AddItemScreen))).maybePop();
    await tester.pump();
    expect(find.byType(AddItemScreen), findsOneWidget);
    expect(repository.saves, 1);
    repository.pending!.complete();
    await tester.pumpAndSettle();
    expect(repository.items, hasLength(1));
    expect(find.text('Open form'), findsOneWidget);
  });

  testWidgets('new occasion stays usable with a keyboard and enlarged text', (
    tester,
  ) async {
    final repository = _ControlledRepository();
    await openForm(tester, repository);
    tester.view.physicalSize = const Size(320, 640);
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('+ New'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(find.text('+ New'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('+ New'));
    await tester.pumpAndSettle();
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final field = find.byWidgetPredicate(
      (widget) =>
          widget is TextField &&
          widget.decoration?.labelText == 'Occasion name',
    );
    await tester.enterText(field, 'Gallery opening');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(repository.occasions.last.name, 'Gallery opening');
    expect(tester.takeException(), isNull);
  });
}
