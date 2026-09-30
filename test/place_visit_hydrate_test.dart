import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:viateria/data/memory_leaderboard.dart';
import 'package:viateria/data/place_visit_hydrate.dart';
import 'package:viateria/data/place_visit_sync.dart';
import 'package:viateria/data/supabase_leaderboard.dart';
import 'package:viateria/data/verified_places.dart';
import 'package:viateria/domain/leaderboard_score.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const userId = 'user-a';
  const localId = '11111111-1111-4111-8111-111111111111';
  const serverId = '22222222-2222-4222-8222-222222222222';

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('hydrate merges server place ids into the local store', () async {
    SharedPreferences.setMockInitialValues({
      '${VerifiedPlacesStore.prefsKey}.$userId': [localId, 'karlstejn'],
      '${PlaceVisitSync.syncedFlag}.$userId': true,
    });
    final store = VerifiedPlacesStore();
    await store.bindUser(userId);
    final board = MemoryLeaderboardRepository(
      visitedPlaceIds: [serverId, localId, ''],
    );

    await const PlaceVisitHydrate().mergeFromServer(
      userId: userId,
      store: store,
      leaderboard: board,
    );

    expect(store.ids, {localId, 'karlstejn', serverId});
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getStringList('${VerifiedPlacesStore.prefsKey}.$userId'), [
      localId,
      serverId,
      'karlstejn',
    ]);
    expect(prefs.getBool('${PlaceVisitSync.syncedFlag}.$userId'), isTrue);
    expect(board.batches, isEmpty);
  });

  test('empty prefs still receive server place ids', () async {
    final store = VerifiedPlacesStore();
    await store.bindUser(userId);
    expect(store.ids, isEmpty);

    await const PlaceVisitHydrate().mergeFromServer(
      userId: userId,
      store: store,
      leaderboard: MemoryLeaderboardRepository(visitedPlaceIds: [serverId]),
    );

    expect(store.ids, {serverId});
  });

  test('a late response does not write into the next account', () async {
    SharedPreferences.setMockInitialValues({
      '${VerifiedPlacesStore.prefsKey}.$userId': [localId],
    });
    final store = VerifiedPlacesStore();
    await store.bindUser(userId);
    final board = _RebindDuringRead(
      store,
      visitedPlaceIds: [serverId],
      nextUserId: 'user-b',
    );

    await const PlaceVisitHydrate().mergeFromServer(
      userId: userId,
      store: store,
      leaderboard: board,
    );

    expect(store.boundUserId, 'user-b');
    expect(store.ids, isEmpty);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getStringList('${VerifiedPlacesStore.prefsKey}.$userId'), [
      localId,
    ]);
    expect(
      prefs.getStringList('${VerifiedPlacesStore.prefsKey}.user-b'),
      isNull,
    );
  });

  test(
    'login refresh hydrates when prefs were already synced, then skips upload',
    () async {
      SharedPreferences.setMockInitialValues({
        '${VerifiedPlacesStore.prefsKey}.$userId': [localId],
        '${PlaceVisitSync.syncedFlag}.$userId': true,
      });
      final store = VerifiedPlacesStore();
      await store.bindUser(userId);
      final board = MemoryLeaderboardRepository(visitedPlaceIds: [serverId]);

      await refreshVerifiedPlacesOnLogin(
        userId: userId,
        store: store,
        leaderboard: board,
      );

      expect(store.ids, {localId, serverId});
      expect(board.batches, isEmpty);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('${PlaceVisitSync.syncedFlag}.$userId'), isTrue);
    },
  );

  test('login refresh uploads the merged uuid set', () async {
    SharedPreferences.setMockInitialValues({
      '${VerifiedPlacesStore.prefsKey}.$userId': [localId, 'karlstejn'],
    });
    final store = VerifiedPlacesStore();
    await store.bindUser(userId);
    final board = MemoryLeaderboardRepository(visitedPlaceIds: [serverId]);

    await refreshVerifiedPlacesOnLogin(
      userId: userId,
      store: store,
      leaderboard: board,
    );

    expect(store.ids, {localId, 'karlstejn', serverId});
    expect(board.batches, [
      [localId, serverId],
    ]);
    expect(board.visits.map((visit) => visit.source), [
      PlaceVisitSource.prefsSync,
      PlaceVisitSource.prefsSync,
    ]);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('${PlaceVisitSync.syncedFlag}.$userId'), isTrue);
  });

  test('a failed place_visits read still uploads local prefs', () async {
    SharedPreferences.setMockInitialValues({
      '${VerifiedPlacesStore.prefsKey}.$userId': [localId],
    });
    final store = VerifiedPlacesStore();
    await store.bindUser(userId);
    final board = _ReadFails();

    await refreshVerifiedPlacesOnLogin(
      userId: userId,
      store: store,
      leaderboard: board,
    );

    expect(store.ids, {localId});
    expect(board.batches, [
      [localId],
    ]);
  });

  test('a failed upload keeps hydrated ids and leaves the flag unset', () async {
    final store = VerifiedPlacesStore();
    await store.bindUser(userId);
    final board = _BatchFails(visitedPlaceIds: [serverId]);

    await refreshVerifiedPlacesOnLogin(
      userId: userId,
      store: store,
      leaderboard: board,
    );

    expect(store.ids, {serverId});
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('${PlaceVisitSync.syncedFlag}.$userId'), isNot(true));
  });

  test('place visit pages union ids and stop on a short page', () async {
    const pageA = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
    const pageB = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';
    const pageC = 'cccccccc-cccc-4ccc-8ccc-cccccccccccc';
    final pages = [
      [
        {'place_id': pageB},
        {'place_id': pageA},
      ],
      [
        {'place_id': pageA},
        {'place_id': '  '},
        'nope',
      ],
      [
        {'place_id': pageC},
      ],
    ];
    var calls = 0;
    final ids = await collectPlaceVisitIds(
      pageSize: 2,
      loadPage: (offset, pageSize) async {
        expect(pageSize, 2);
        expect(offset, calls * 2);
        return pages[calls++];
      },
    );
    expect(calls, 3);
    expect(ids, [pageA, pageB, pageC]);
  });

  test('a repeated full page does not loop', () async {
    var calls = 0;
    final ids = await collectPlaceVisitIds(
      pageSize: 1,
      loadPage: (offset, pageSize) async {
        calls += 1;
        return [
          {'place_id': serverId},
        ];
      },
    );
    expect(calls, 2);
    expect(ids, [serverId]);
  });
}

class _ReadFails extends MemoryLeaderboardRepository {
  @override
  Future<List<String>> fetchMyVisitedPlaceIds() async {
    throw StateError('read down');
  }
}

class _BatchFails extends MemoryLeaderboardRepository {
  _BatchFails({List<String>? visitedPlaceIds})
    : super(visitedPlaceIds: visitedPlaceIds);

  @override
  Future<void> recordPlaceVisitsBatch(
    List<String> placeIds, {
    PlaceVisitSource source = PlaceVisitSource.prefsSync,
  }) async {
    throw StateError('write down');
  }
}

class _RebindDuringRead extends MemoryLeaderboardRepository {
  _RebindDuringRead(
    this.store, {
    required this.nextUserId,
    List<String>? visitedPlaceIds,
  }) : super(visitedPlaceIds: visitedPlaceIds);

  final VerifiedPlacesStore store;
  final String nextUserId;

  @override
  Future<List<String>> fetchMyVisitedPlaceIds() async {
    await store.bindUser(nextUserId);
    return super.fetchMyVisitedPlaceIds();
  }
}
