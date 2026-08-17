import 'package:flutter_test/flutter_test.dart';
import 'package:rees46_sdk/src/multi_instance/instance_resolver.dart';

/// Table-driven port of the native `InstanceResolverTest` — the rules must stay
/// byte-for-byte identical across platforms.
void main() {
  Resolution resolve({
    String? requested,
    Set<String> live = const {},
    Set<String> pending = const {},
  }) => InstanceResolver.resolve(
    requestedShopId: requested,
    liveShopIds: live,
    pendingShopIds: pending,
  );

  group('explicit shopId', () {
    test('live shop → Existing', () {
      expect(
        resolve(requested: 'a', live: {'a'}),
        const ExistingResolution('a'),
      );
    });

    test('pending shop → Pending', () {
      expect(
        resolve(requested: 'a', pending: {'a'}),
        const PendingResolution('a'),
      );
    });

    test('live wins over pending for the same id', () {
      expect(
        resolve(requested: 'a', live: {'a'}, pending: {'a'}),
        const ExistingResolution('a'),
      );
    });

    test('unknown shop → NotRegistered', () {
      expect(
        resolve(requested: 'x', live: {'a'}, pending: {'b'}),
        const NotRegisteredResolution(),
      );
    });

    test('unknown shop with nothing registered → NotRegistered', () {
      expect(resolve(requested: 'x'), const NotRegisteredResolution());
    });
  });

  group('no shopId', () {
    test('nothing registered → NotRegistered', () {
      expect(resolve(), const NotRegisteredResolution());
    });

    test('exactly one live → Existing', () {
      expect(resolve(live: {'a'}), const ExistingResolution('a'));
    });

    test('exactly one pending → Pending', () {
      expect(resolve(pending: {'a'}), const PendingResolution('a'));
    });

    test('two live → Ambiguous', () {
      expect(resolve(live: {'a', 'b'}), const AmbiguousResolution());
    });

    test('one live + one pending → Ambiguous', () {
      expect(resolve(live: {'a'}, pending: {'b'}), const AmbiguousResolution());
    });

    test('two pending → Ambiguous', () {
      expect(resolve(pending: {'a', 'b'}), const AmbiguousResolution());
    });
  });
}
