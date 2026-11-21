import 'dart:async';
import 'dart:typed_data';

import 'package:fitcheck/wardrobe/wardrobe_models.dart';
import 'package:fitcheck/wardrobe/wardrobe_repository.dart';
import 'package:fitcheck/wardrobe/wardrobe_store.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> flushStreams() => Future<void>.delayed(Duration.zero);

class ControlledWardrobeRepository implements WardrobeRepository {
  final itemStreams = <StreamController<List<ClothingItem>>>[];
  final occasionStreams = <StreamController<List<Occasion>>>[];
  Completer<void>? itemCancellation;
  int activeItemSubscriptions = 0;

  @override
  Stream<List<ClothingItem>> watchItems() {
    final controller = StreamController<List<ClothingItem>>(
      onListen: () => activeItemSubscriptions++,
      onCancel: () async {
        await itemCancellation?.future;
        activeItemSubscriptions--;
      },
    );
    itemStreams.add(controller);
    return controller.stream;
  }

  @override
  Stream<List<Occasion>> watchOccasions() {
    final controller = StreamController<List<Occasion>>();
    occasionStreams.add(controller);
    return controller.stream;
  }

  Future<void> close() async {
    if (itemCancellation case final pending? when !pending.isCompleted) {
      pending.complete();
    }
    for (final controller in [...itemStreams, ...occasionStreams]) {
      await controller.close();
    }
  }

  @override
  Future<void> addItem(
    ClothingDraft draft, {
    Uint8List? photo,
    String? mimeType,
  }) => throw UnimplementedError();

  @override
  Future<Occasion> addOccasion(String name) => throw UnimplementedError();

  @override
  Future<void> markWashed(String itemId) => throw UnimplementedError();
}

void main() {
  late ControlledWardrobeRepository repository;
  late WardrobeStore store;
  late bool disposed;

  setUp(() {
    repository = ControlledWardrobeRepository();
    store = WardrobeStore(repository);
    disposed = false;
  });

  tearDown(() async {
    if (!disposed) store.dispose();
    await repository.close();
  });

  test(
    'retry awaiting cancellation cannot resubscribe after sign-out',
    () async {
      repository.itemCancellation = Completer<void>();
      final retry = store.retry();
      await flushStreams();

      store.dispose();
      disposed = true;
      repository.itemCancellation!.complete();

      await expectLater(retry, completes);
      expect(repository.itemStreams, hasLength(1));
      expect(repository.occasionStreams, hasLength(1));
      expect(repository.activeItemSubscriptions, 0);
    },
  );

  test('concurrent retries produce one replacement subscription', () async {
    repository.itemCancellation = Completer<void>();
    final first = store.retry();
    final second = store.retry();
    await flushStreams();
    repository.itemCancellation!.complete();
    await Future.wait([first, second]);

    expect(repository.itemStreams, hasLength(2));
    expect(repository.occasionStreams, hasLength(2));
    expect(repository.activeItemSubscriptions, 1);
  });

  test('clothing success preserves an outstanding occasion error', () async {
    repository.occasionStreams.single.addError(
      StateError('Occasion read failed'),
    );
    await flushStreams();
    expect(store.error, contains('occasions'));

    repository.itemStreams.single.add([]);
    await flushStreams();
    expect(store.error, contains('occasions'));

    repository.occasionStreams.single.add(Occasion.defaults);
    await flushStreams();
    expect(store.error, isNull);
  });

  test('recovering occasions does not hide a clothing read error', () async {
    repository.itemStreams.single.addError(StateError('Clothing read failed'));
    await flushStreams();
    expect(store.error, contains('wardrobe'));

    repository.occasionStreams.single.add(Occasion.defaults);
    await flushStreams();
    expect(store.error, contains('wardrobe'));

    repository.itemStreams.single.add([]);
    await flushStreams();
    expect(store.error, isNull);
  });

  test('retry on an already disposed store is harmless', () async {
    store.dispose();
    disposed = true;

    await expectLater(store.retry(), completes);
    expect(repository.itemStreams, hasLength(1));
    expect(repository.occasionStreams, hasLength(1));
  });
}
