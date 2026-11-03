import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fitcheck/outfits/firestore_outfit_repository.dart';
import 'package:fitcheck/outfits/outfit_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import 'outfit_repository_test.dart' as fixtures;

/// Exercises the real repository's read/write decisions without Firebase setup.
/// Transactions stage writes, reject reads after writes, and can retry once.
class MemoryFirestore extends Fake implements FirebaseFirestore {
  final documents = <String, Map<String, dynamic>>{};
  void Function()? beforeRetry;
  int commits = 0;

  @override
  CollectionReference<Map<String, dynamic>> collection(String path) =>
      MemoryCollection(path);

  @override
  Future<T> runTransaction<T>(
    TransactionHandler<T> transactionHandler, {
    Duration timeout = const Duration(seconds: 30),
    int maxAttempts = 5,
  }) async {
    var transaction = MemoryTransaction(this);
    var result = await transactionHandler(transaction);
    final retry = beforeRetry;
    if (retry != null) {
      beforeRetry = null;
      retry();
      transaction = MemoryTransaction(this);
      result = await transactionHandler(transaction);
    }
    documents.addAll(transaction.pending);
    commits++;
    return result;
  }
}

// Firestore's sealed interfaces are replaced only at this test boundary.
// ignore: subtype_of_sealed_class
class MemoryCollection extends Fake
    implements CollectionReference<Map<String, dynamic>> {
  MemoryCollection(this.path);
  @override
  final String path;
  @override
  DocumentReference<Map<String, dynamic>> doc([String? path]) =>
      MemoryDocument('${this.path}/$path');
}

// ignore: subtype_of_sealed_class
class MemoryDocument extends Fake
    implements DocumentReference<Map<String, dynamic>> {
  MemoryDocument(this.path);
  @override
  final String path;
  @override
  String get id => path.split('/').last;
  @override
  CollectionReference<Map<String, dynamic>> collection(String collectionPath) =>
      MemoryCollection('$path/$collectionPath');
}

// ignore: subtype_of_sealed_class
class MemorySnapshot<T extends Object?> extends Fake
    implements DocumentSnapshot<T> {
  MemorySnapshot(this.id, this.value);
  @override
  final String id;
  final T? value;
  @override
  T? data() => value;
}

class MemoryTransaction extends Fake implements Transaction {
  MemoryTransaction(this.database);
  final MemoryFirestore database;
  final pending = <String, Map<String, dynamic>>{};

  @override
  Future<DocumentSnapshot<T>> get<T extends Object?>(
    DocumentReference<T> reference,
  ) async {
    if (pending.isNotEmpty) throw StateError('Read after transaction write');
    final value = database.documents[reference.path];
    return MemorySnapshot<T>(
      reference.id,
      value == null ? null : Map<String, dynamic>.from(value) as T,
    );
  }

  @override
  Transaction set<T>(
    DocumentReference<T> reference,
    T data, [
    SetOptions? options,
  ]) {
    pending[reference.path] = Map<String, dynamic>.from(data as Map);
    return this;
  }

  @override
  Transaction update(DocumentReference reference, Map<Object, Object?> data) {
    pending[reference.path] = {
      ...database.documents[reference.path]!,
      for (final entry in data.entries) entry.key as String: entry.value,
    };
    return this;
  }
}

void main() {
  late MemoryFirestore database;
  late FirestoreOutfitRepository repository;
  const root = 'users/owner';
  const outfitPath = '$root/outfits/2026-11-02';
  final now = DateTime(2026, 11, 2, 8);

  setUp(() {
    database = MemoryFirestore();
    repository = FirestoreOutfitRepository(
      'owner',
      database: database,
      clock: () => now,
    );
    for (final piece in fixtures.suggestion().pieces) {
      database.documents['$root/clothes/${piece.id}'] = piece.toMap();
    }
  });

  test(
    'wear reads current clothes, updates all pieces, and is idempotent',
    () async {
      database.documents['$root/clothes/top']!['wearsSinceWash'] = 1;
      await repository.saveSuggestion(fixtures.suggestion());
      await repository.wear(fixtures.suggestion());
      await repository.wear(fixtures.suggestion());
      expect(database.documents[outfitPath]!['worn'], isTrue);
      expect(database.documents['$root/clothes/top']!['wearsSinceWash'], 2);
      expect(database.documents['$root/clothes/bottom']!['wearsSinceWash'], 1);
      expect(
        database.documents['$root/clothes/shoes']!['lastWorn'],
        now.toUtc().toIso8601String(),
      );
      expect(
        database.documents.keys.every((path) => path.startsWith('$root/')),
        isTrue,
      );
    },
  );

  test(
    'a dirty or deleted piece leaves every piece and daily outfit unchanged',
    () async {
      for (final deleted in [false, true]) {
        if (deleted) {
          database.documents.remove('$root/clothes/shoes');
        } else {
          database.documents['$root/clothes/shoes']!['wearsSinceWash'] = 2;
        }
        await expectLater(
          repository.wear(fixtures.suggestion()),
          throwsA(isA<OutfitFailure>()),
        );
        expect(database.documents['$root/clothes/top']!['wearsSinceWash'], 0);
        expect(
          database.documents['$root/clothes/bottom']!['wearsSinceWash'],
          0,
        );
        expect(database.documents[outfitPath], isNull);
        expect(database.commits, 0);
      }
    },
  );

  test(
    'a stale pick cannot record wear over another saved suggestion',
    () async {
      database.documents[outfitPath] = {
        ...fixtures.savedData(),
        'topId': 'another-top',
      };
      await expectLater(
        repository.wear(fixtures.suggestion()),
        throwsA(isA<OutfitFailure>()),
      );
      expect(database.documents[outfitPath]!['topId'], 'another-top');
      expect(database.documents['$root/clothes/top']!['wearsSinceWash'], 0);
    },
  );

  test(
    'save cannot replace an outfit already worn by another session',
    () async {
      database.documents[outfitPath] = {...fixtures.savedData(), 'worn': true};
      await expectLater(
        repository.saveSuggestion(fixtures.suggestion()),
        throwsA(isA<OutfitFailure>()),
      );
      expect(database.documents[outfitPath]!['worn'], isTrue);
    },
  );

  test(
    'transaction retry uses the latest counts rather than a stale suggestion',
    () async {
      database.beforeRetry = () {
        database.documents['$root/clothes/top']!['wearsSinceWash'] = 1;
      };
      await repository.wear(fixtures.suggestion());
      expect(database.documents['$root/clothes/top']!['wearsSinceWash'], 2);
      expect(database.documents['$root/clothes/bottom']!['wearsSinceWash'], 1);
      expect(database.commits, 1);
    },
  );

  test(
    'another session completing wear during a retry does not double count',
    () async {
      database.beforeRetry = () {
        database.documents[outfitPath] = {
          ...fixtures.savedData(),
          'worn': true,
        };
        for (final piece in fixtures.suggestion().pieces) {
          database.documents['$root/clothes/${piece.id}']!['wearsSinceWash'] =
              1;
        }
      };
      await repository.wear(fixtures.suggestion());
      for (final piece in fixtures.suggestion().pieces) {
        expect(
          database.documents['$root/clothes/${piece.id}']!['wearsSinceWash'],
          1,
        );
      }
    },
  );

  test('midnight during a transaction prevents recording yesterday', () async {
    var clockCalls = 0;
    repository = FirestoreOutfitRepository(
      'owner',
      database: database,
      clock: () => clockCalls++ == 0 ? now : now.add(const Duration(days: 1)),
    );
    await expectLater(
      repository.wear(fixtures.suggestion()),
      throwsA(isA<OutfitFailure>()),
    );
    expect(database.commits, 0);
    expect(database.documents[outfitPath], isNull);
  });
}
