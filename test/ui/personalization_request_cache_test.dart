import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rees46_sdk/src/ui/widgets/personalization_request_cache.dart';

/// The answer to one [PersonalizationRequestCache.fetch] as a future.
Future<T> get<T>(
  PersonalizationRequestCache cache,
  String key,
  Future<T> Function() load, {
  bool force = false,
}) {
  final answer = Completer<T>();
  cache.fetch<T>(
    key,
    load,
    onValue: answer.complete,
    onError: answer.completeError,
    force: force,
  );
  return answer.future;
}

void main() {
  late Duration now;
  late PersonalizationRequestCache cache;

  setUp(() {
    now = Duration.zero;
    cache = PersonalizationRequestCache(clock: () => now);
  });

  /// A loader that counts its calls and answers [value].
  ({Future<String> Function() load, int Function() calls}) loader(
    String value,
  ) {
    var calls = 0;
    return (
      load: () async {
        calls++;
        return value;
      },
      calls: () => calls,
    );
  }

  test('the key holds the shop, the kind and the sorted parameters', () {
    String key(String? shop, String kind, Map<String, Object?> params) =>
        PersonalizationRequestCache.keyOf(shop, kind, params);

    final base = key('shop', 'recommend', {'b': 2, 'a': 'x'});
    expect(key('shop', 'recommend', {'a': 'x', 'b': 2}), base);
    expect(key('shop', 'recommend', {'a': 'x', 'b': 2, 'none': null}), base);
    expect(key('other', 'recommend', {'a': 'x', 'b': 2}), isNot(base));
    expect(key('shop', 'search', {'a': 'x', 'b': 2}), isNot(base));
    expect(key('shop', 'recommend', {'a': 'x', 'b': '2'}), isNot(base));
  });

  test('values are encoded, not glued together', () {
    expect(
      PersonalizationRequestCache.keyOf('shop', 'search', {
        'query': 'tv&sort=price',
      }),
      isNot(
        PersonalizationRequestCache.keyOf('shop', 'search', {
          'query': 'tv',
          'sort': 'price',
        }),
      ),
    );
    expect(
      PersonalizationRequestCache.keyOf('a|b', 'c'),
      isNot(PersonalizationRequestCache.keyOf('a', 'b|c')),
    );
  });

  test('a fresh answer comes from the cache', () async {
    final source = loader('v1');
    expect(await get(cache, 'k', source.load), 'v1');
    now += const Duration(minutes: 9, seconds: 59);
    expect(await get(cache, 'k', source.load), 'v1');
    expect(source.calls(), 1);
  });

  test('after ten minutes the request goes out again', () async {
    final source = loader('v1');
    await get(cache, 'k', source.load);
    now += const Duration(minutes: 10);
    await get(cache, 'k', source.load);
    expect(source.calls(), 2);
  });

  test('past 32 entries the oldest goes', () async {
    for (var i = 0; i < 33; i++) {
      await get(cache, 'k$i', loader('v$i').load);
    }
    expect(cache.length, 32);

    final first = loader('again');
    expect(await get(cache, 'k0', first.load), 'again');
    expect(first.calls(), 1);
    final second = loader('again');
    expect(await get(cache, 'k2', second.load), 'v2');
    expect(second.calls(), 0);
  });

  test('a refreshed entry counts as the newest', () async {
    final small = PersonalizationRequestCache(capacity: 2, clock: () => now);
    await get(small, 'a', loader('a1').load);
    await get(small, 'b', loader('b1').load);
    now += const Duration(minutes: 11);
    await get(small, 'a', loader('a2').load);
    await get(small, 'c', loader('c1').load);

    expect(await get(small, 'a', loader('a3').load), 'a2');
    final b = loader('b2');
    expect(await get(small, 'b', b.load), 'b2');
    expect(b.calls(), 1);
  });

  test('the same request in flight goes out once', () async {
    final gate = Completer<String>();
    var calls = 0;
    Future<String> load() {
      calls++;
      return gate.future;
    }

    final one = get(cache, 'k', load);
    final two = get(cache, 'k', load);
    final other = get(cache, 'other', load);
    gate.complete('v');

    expect(await one, 'v');
    expect(await two, 'v');
    expect(await other, 'v');
    expect(calls, 2);
  });

  test('an error reaches every waiter and is not cached', () async {
    final gate = Completer<String>();
    final one = get(cache, 'k', () => gate.future);
    final two = get(cache, 'k', () async => 'never');
    // Both waiters listen before the error arrives, as callers awaiting them do.
    final failures = Future.wait(<Future<void>>[
      expectLater(one, throwsStateError),
      expectLater(two, throwsStateError),
    ]);
    gate.completeError(StateError('offline'));
    await failures;
    expect(cache.length, 0);

    final retry = loader('v');
    expect(await get(cache, 'k', retry.load), 'v');
    expect(retry.calls(), 1);
  });

  test('clear forgets every answer', () async {
    await get(cache, 'k', loader('v1').load);
    cache.clear();
    final source = loader('v2');
    expect(await get(cache, 'k', source.load), 'v2');
    expect(source.calls(), 1);
  });

  test(
    'a request hanging past 30 seconds takes no one: a new one goes out',
    () async {
      final hung = Completer<String>();
      var calls = 0;
      final first = get(cache, 'k', () {
        calls++;
        return hung.future;
      });
      now += const Duration(seconds: 29);
      final joined = get(cache, 'k', () async => 'never');
      now += const Duration(seconds: 2);
      final fresh = get(cache, 'k', () async {
        calls++;
        return 'new';
      });

      expect(await fresh, 'new');
      expect(calls, 2);

      // The old generation answers its own waiters and does not overwrite the cache.
      hung.complete('old');
      expect(await first, 'old');
      expect(await joined, 'old');
      expect(await get(cache, 'k', () async => 'never'), 'new');
    },
  );

  test('once every waiter leaves, the same key loads again', () async {
    final gate = Completer<String>();
    var called = false;
    final subscription = cache.fetch<String>(
      'k',
      () => gate.future,
      onValue: (_) => called = true,
    );
    subscription.cancel();

    final again = loader('v2');
    final second = get(cache, 'k', again.load);
    gate.complete('v1');
    expect(await second, 'v2');
    expect(again.calls(), 1);
    await pumpEventQueue();
    expect(called, isFalse);
  });

  test('a waiter that leaves is not called back, the rest are', () async {
    final gate = Completer<String>();
    var left = false;
    final leaving = cache.fetch<String>(
      'k',
      () => gate.future,
      onValue: (_) => left = true,
    );
    final stayed = get(cache, 'k', () async => 'never');
    // One of two waiters leaves: the request stays in flight for the other.
    leaving.cancel();
    gate.complete('v');
    expect(await stayed, 'v');
    expect(left, isFalse);
  });

  test('clear during a request keeps its answer out of the cache', () async {
    final gate = Completer<String>();
    final pending = get(cache, 'k', () => gate.future);
    cache.clear();
    gate.complete('v1');
    expect(await pending, 'v1');
    expect(cache.length, 0);

    final again = loader('v2');
    expect(await get(cache, 'k', again.load), 'v2');
    expect(again.calls(), 1);
  });

  test('force goes past the cached answer and the request in flight', () async {
    await get(cache, 'k', loader('v1').load);
    final forced = loader('v2');
    expect(await get(cache, 'k', forced.load, force: true), 'v2');
    expect(forced.calls(), 1);
    expect(await get(cache, 'k', loader('never').load), 'v2');

    final gate = Completer<String>();
    final slow = get(cache, 'other', () => gate.future);
    final retry = loader('fresh');
    expect(await get(cache, 'other', retry.load, force: true), 'fresh');
    gate.complete('stale');
    expect(await slow, 'stale');
    expect(await get(cache, 'other', loader('never').load), 'fresh');
  });

  test(
    'a throwing callback does not keep the answer from the others',
    () async {
      final reported = <FlutterErrorDetails>[];
      final previous = FlutterError.onError;
      FlutterError.onError = reported.add;
      addTearDown(() => FlutterError.onError = previous);

      final gate = Completer<String>();
      cache.fetch<String>(
        'k',
        () => gate.future,
        onValue: (_) => throw StateError('broken widget'),
      );
      final other = get(cache, 'k', () async => 'never');
      gate.complete('v');

      expect(await other, 'v');
      expect(reported, hasLength(1));
      expect(reported.single.exception, isStateError);
    },
  );

  test('a cached answer comes later, and not after cancel', () async {
    await get(cache, 'k', loader('v').load);
    var calls = 0;
    cache
        .fetch<String>('k', loader('never').load, onValue: (_) => calls++)
        .cancel();
    cache.fetch<String>('k', loader('never').load, onValue: (_) => calls++);
    expect(calls, 0);
    await pumpEventQueue();
    expect(calls, 1);
  });
}
