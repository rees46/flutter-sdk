import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:rees46_sdk/src/ui/widgets/personalization_request_cache.dart';

void main() {
  late DateTime now;
  late PersonalizationRequestCache cache;

  setUp(() {
    now = DateTime(2026);
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
    final key = PersonalizationRequestCache.keyOf('shop', 'recommend', {
      'b': 2,
      'a': 'x',
      'none': null,
    });
    expect(key, 'shop|recommend|a=x&b=2');
    expect(
      PersonalizationRequestCache.keyOf('shop', 'recommend', {
        'a': 'x',
        'b': 2,
      }),
      key,
    );
    expect(
      PersonalizationRequestCache.keyOf('other', 'recommend', {
        'a': 'x',
        'b': 2,
      }),
      isNot(key),
    );
    expect(PersonalizationRequestCache.keyOf(null, 'search'), '|search|');
  });

  test('a fresh answer comes from the cache', () async {
    final source = loader('v1');
    expect(await cache.fetch('k', source.load), 'v1');
    now = now.add(const Duration(minutes: 9, seconds: 59));
    expect(await cache.fetch('k', source.load), 'v1');
    expect(source.calls(), 1);
  });

  test('after ten minutes the request goes out again', () async {
    final source = loader('v1');
    await cache.fetch('k', source.load);
    now = now.add(const Duration(minutes: 10));
    await cache.fetch('k', source.load);
    expect(source.calls(), 2);
  });

  test('past 32 entries the oldest goes', () async {
    for (var i = 0; i < 33; i++) {
      await cache.fetch('k$i', loader('v$i').load);
    }
    expect(cache.length, 32);

    final first = loader('again');
    expect(await cache.fetch('k0', first.load), 'again');
    expect(first.calls(), 1);
    final second = loader('again');
    expect(await cache.fetch('k2', second.load), 'v2');
    expect(second.calls(), 0);
  });

  test('a refreshed entry counts as the newest', () async {
    final small = PersonalizationRequestCache(capacity: 2, clock: () => now);
    await small.fetch('a', loader('a1').load);
    await small.fetch('b', loader('b1').load);
    now = now.add(const Duration(minutes: 11));
    await small.fetch('a', loader('a2').load);
    await small.fetch('c', loader('c1').load);

    expect(await small.fetch('a', loader('a3').load), 'a2');
    final b = loader('b2');
    expect(await small.fetch('b', b.load), 'b2');
    expect(b.calls(), 1);
  });

  test('the same request in flight goes out once', () async {
    final gate = Completer<String>();
    var calls = 0;
    Future<String> load() {
      calls++;
      return gate.future;
    }

    final one = cache.fetch('k', load);
    final two = cache.fetch('k', load);
    final other = cache.fetch('other', load);
    gate.complete('v');

    expect(await one, 'v');
    expect(await two, 'v');
    expect(await other, 'v');
    expect(calls, 2);
  });

  test('an error reaches every waiter and is not cached', () async {
    final gate = Completer<String>();
    final one = cache.fetch('k', () => gate.future);
    final two = cache.fetch('k', () async => 'never');
    // Both waiters listen before the error arrives, as callers awaiting them do.
    final failures = Future.wait(<Future<void>>[
      expectLater(one, throwsStateError),
      expectLater(two, throwsStateError),
    ]);
    gate.completeError(StateError('offline'));
    await failures;
    expect(cache.length, 0);

    final retry = loader('v');
    expect(await cache.fetch('k', retry.load), 'v');
    expect(retry.calls(), 1);
  });

  test('clear forgets every answer', () async {
    await cache.fetch('k', loader('v1').load);
    cache.clear();
    final source = loader('v2');
    expect(await cache.fetch('k', source.load), 'v2');
    expect(source.calls(), 1);
  });
}
