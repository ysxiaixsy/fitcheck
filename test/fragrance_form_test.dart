import 'dart:async';
import 'dart:typed_data';

import 'package:fitcheck/fragrance/fragrance.dart';
import 'package:fitcheck/fragrance/fragrance_collection.dart';
import 'package:fitcheck/fragrance/fragrance_form.dart';
import 'package:fitcheck/fragrance/fragrance_repository.dart';
import 'package:fitcheck/theme/fitcheck_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _Repository extends Fake implements FragranceRepository {
  final changes = StreamController<List<Fragrance>>.broadcast();
  List<Fragrance> items = [];
  Completer<void>? pending;
  Fragrance? saved;
  bool failSave = false, failDelete = false;
  int saves = 0, deletes = 0, ids = 0;

  @override
  String createId() => 'fragrance-${++ids}';

  @override
  Stream<List<Fragrance>> watchAll() async* {
    yield List.of(items);
    yield* changes.stream;
  }

  @override
  Future<void> upsert(
    Fragrance fragrance, {
    Uint8List? photo,
    String? mimeType,
  }) async {
    saves++;
    if (pending != null) await pending!.future;
    if (failSave) {
      throw const FragranceFailure('Could not save this fragrance. Try again.');
    }
    saved = fragrance;
    items = [...items.where((item) => item.id != fragrance.id), fragrance];
    changes.add(List.of(items));
  }

  @override
  Future<void> delete(String id) async {
    deletes++;
    if (failDelete) {
      throw const FragranceFailure(
        'Could not delete this fragrance. Try again.',
      );
    }
    items = items.where((item) => item.id != id).toList();
    changes.add(List.of(items));
  }
}

Fragrance _fragrance() => Fragrance(
  id: 'existing',
  name: 'A long citrus fragrance name that must remain complete in detail',
  scentNotes: 'Bergamot, jasmine, and cedar.',
  temperatureBand: TemperatureBand.mild,
  humidityBand: HumidityBand.balanced,
  photoUrl: 'https://example.test/photo.png',
);

void main() {
  void size(WidgetTester tester, {Size value = const Size(360, 800)}) {
    tester.view.physicalSize = value;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Future<void> openForm(
    WidgetTester tester,
    _Repository repository, {
    Fragrance? fragrance,
  }) async {
    size(tester);
    await tester.pumpWidget(
      MaterialApp(
        theme: FitCheckTheme.light,
        home: Builder(
          builder: (context) => Scaffold(
            body: FilledButton(
              onPressed: () => Navigator.push<Fragrance>(
                context,
                MaterialPageRoute(
                  builder: (_) => FragranceFormScreen(
                    repository: repository,
                    fragrance: fragrance,
                  ),
                ),
              ),
              child: const Text('Open form'),
            ),
          ),
        ),
      ),
    );
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await repository.changes.close();
    });
    await tester.tap(find.text('Open form'));
    await tester.pumpAndSettle();
  }

  Future<void> select(WidgetTester tester, String label) async {
    final target = find.text(label);
    await tester.scrollUntilVisible(
      target,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(target);
    await tester.pumpAndSettle();
    await tester.tap(target);
    await tester.pumpAndSettle();
  }

  Future<void> fillNew(WidgetTester tester) async {
    await tester.enterText(
      find.byKey(const Key('fragrance-name')),
      'Citrus morning',
    );
    await tester.enterText(
      find.byKey(const Key('fragrance-notes')),
      'Lemon and cedar',
    );
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await select(tester, 'Warm · above 27°C');
    await select(tester, 'Humid · above 70%');
  }

  testWidgets('new fragrance requires a name and explicit weather ranges', (
    tester,
  ) async {
    final repository = _Repository();
    await openForm(tester, repository);
    await tester.tap(find.byKey(const Key('save-fragrance')));
    await tester.pumpAndSettle();
    expect(find.text('Enter a fragrance name.'), findsOneWidget);
    expect(find.text('Choose a temperature range.'), findsOneWidget);
    expect(find.text('Choose a humidity range.'), findsOneWidget);
    expect(repository.saves, 0);
    await tester.enterText(
      find.byKey(const Key('fragrance-name')),
      'Citrus morning',
    );
    await tester.pumpAndSettle();
    expect(find.text('Enter a fragrance name.'), findsNothing);
    await select(tester, 'Warm · above 27°C');
    expect(find.text('Choose a temperature range.'), findsNothing);
    expect(find.text('Choose a humidity range.'), findsOneWidget);
    await select(tester, 'Humid · above 70%');
    await tester.tap(find.byKey(const Key('save-fragrance')));
    await tester.pumpAndSettle();
    expect(repository.saved?.name, 'Citrus morning');
    expect(repository.saved?.temperatureBand, TemperatureBand.warm);
    expect(repository.saved?.humidityBand, HumidityBand.humid);
    expect(repository.saved?.scentNotes, isNull);
    expect(find.text('Open form'), findsOneWidget);
  });

  testWidgets(
    'editing preserves identity, photo and existing weather preferences',
    (tester) async {
      final repository = _Repository();
      final original = _fragrance();
      await openForm(tester, repository, fragrance: original);
      expect(find.text(original.name), findsOneWidget);
      await tester.enterText(
        find.byKey(const Key('fragrance-name')),
        'Citrus evening',
      );
      await tester.tap(find.byKey(const Key('save-fragrance')));
      await tester.pumpAndSettle();
      expect(repository.ids, 0);
      expect(repository.saved?.id, original.id);
      expect(repository.saved?.name, 'Citrus evening');
      expect(repository.saved?.scentNotes, original.scentNotes);
      expect(repository.saved?.temperatureBand, TemperatureBand.mild);
      expect(repository.saved?.humidityBand, HumidityBand.balanced);
      expect(repository.saved?.photoUrl, original.photoUrl);
    },
  );

  testWidgets(
    'failed save preserves details and retries with the same identity',
    (tester) async {
      final repository = _Repository()..failSave = true;
      await openForm(tester, repository);
      await fillNew(tester);
      await tester.tap(find.byKey(const Key('save-fragrance')));
      await tester.pumpAndSettle();
      expect(
        find.text('Could not save this fragrance. Try again.'),
        findsOneWidget,
      );
      expect(find.text('Citrus morning'), findsOneWidget);
      expect(find.text('Lemon and cedar'), findsOneWidget);
      repository.failSave = false;
      await tester.tap(find.byKey(const Key('save-fragrance')));
      await tester.pumpAndSettle();
      expect(repository.saved?.id, 'fragrance-1');
      expect(repository.ids, 1);
      expect(repository.saved?.scentNotes, 'Lemon and cedar');
      expect(repository.saves, 2);
    },
  );

  testWidgets('pending save blocks duplicate submissions and closing', (
    tester,
  ) async {
    final repository = _Repository()..pending = Completer<void>();
    await openForm(tester, repository);
    await fillNew(tester);
    await tester.tap(find.byKey(const Key('save-fragrance')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('save-fragrance')));
    await Navigator.of(tester.element(find.byType(FragranceFormScreen)))
        .maybePop();
    await tester.pump();
    expect(find.byType(FragranceFormScreen), findsOneWidget);
    expect(repository.saves, 1);
    repository.pending!.complete();
    await tester.pumpAndSettle();
    expect(find.text('Open form'), findsOneWidget);
    expect(repository.saves, 1);
  });

  testWidgets('form stays usable with enlarged text and an open keyboard', (
    tester,
  ) async {
    final repository = _Repository();
    await openForm(tester, repository);
    tester.view.physicalSize = const Size(320, 640);
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    tester.view.viewInsets = const FakeViewPadding(bottom: 260);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpAndSettle();
    await fillNew(tester);
    expect(tester.takeException(), isNull);
    await tester.tap(find.byKey(const Key('save-fragrance')));
    await tester.pumpAndSettle();
    expect(repository.saved?.name, 'Citrus morning');
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'detail shows full text and delete requires an inline confirmation',
    (tester) async {
      size(tester);
      final original = _fragrance();
      final repository = _Repository()..items = [original];
      await tester.pumpWidget(
        MaterialApp(
          theme: FitCheckTheme.dark,
          home: Scaffold(
            body: FragranceCollection(
              items: [original],
              repository: repository,
              query: '',
              onAdd: () {},
            ),
          ),
        ),
      );
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        await repository.changes.close();
      });
      await tester.tap(find.text(original.name));
      await tester.pumpAndSettle();
      expect(find.text(original.name), findsOneWidget);
      expect(find.text(original.scentNotes!), findsOneWidget);
      expect(find.text('Mild · 20–27°C'), findsOneWidget);
      expect(find.text('Balanced · 40–70%'), findsOneWidget);
      await tester.tap(find.text('Delete fragrance'));
      await tester.pumpAndSettle();
      expect(repository.deletes, 0);
      expect(
        find.text('Delete this fragrance from your collection?'),
        findsOneWidget,
      );
      await tester.tap(find.text('Keep fragrance'));
      await tester.pumpAndSettle();
      expect(repository.deletes, 0);
      await tester.tap(find.text('Delete fragrance'));
      await tester.pumpAndSettle();
      repository.failDelete = true;
      await tester.tap(find.text('Confirm delete fragrance'));
      await tester.pumpAndSettle();
      expect(
        find.text('Could not delete this fragrance. Try again.'),
        findsOneWidget,
      );
      repository.failDelete = false;
      await tester.tap(find.text('Confirm delete fragrance'));
      await tester.pumpAndSettle();
      expect(repository.items, isEmpty);
      expect(repository.deletes, 2);
    },
  );
}
