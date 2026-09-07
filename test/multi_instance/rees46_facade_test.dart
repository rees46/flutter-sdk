import 'package:flutter_test/flutter_test.dart';
import 'package:rees46_sdk/src/multi_instance/rees46.dart';
import 'package:rees46_sdk/src/multi_instance/rees46_config.dart';
import 'package:rees46_sdk/src/multi_instance/sdk_exceptions.dart';
import 'package:rees46_sdk/src/personalization_sdk.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Records every config the facade asks to build/initialize, and returns a
  // real (but un-initialized-over-native) handle carrying the shop id. Keeps the
  // resolution contract testable without native or a live Pigeon channel.
  late List<String> built;

  REES46Config cfg(String shopId) => REES46Config(shopId: shopId);

  setUp(() {
    built = <String>[];
    REES46.debugFactory = (config) {
      built.add(config.shopId);
      return PersonalizationSdk(shopId: config.shopId);
    };
  });

  tearDown(REES46.reset);

  group('initialize', () {
    test('returns a handle bound to the shop and marks it live', () {
      final sdk = REES46.initialize(cfg('a'));

      expect(sdk.shopId, 'a');
      expect(built, ['a']);
      expect(REES46.isInitialized('a'), isTrue);
      expect(REES46.liveShopIds, ['a']);
    });

    test('clears any pending registration for the same shop', () {
      REES46.registerShops([cfg('a')]);
      expect(REES46.pendingShopIds, ['a']);

      REES46.initialize(cfg('a'));

      expect(REES46.pendingShopIds, isEmpty);
      expect(REES46.liveShopIds, ['a']);
    });
  });

  group('registerShops', () {
    test('lazy by default — registers without building', () {
      REES46.registerShops([cfg('a'), cfg('b')]);

      expect(built, isEmpty);
      expect(REES46.pendingShopIds, ['a', 'b']);
      expect(REES46.isInitialized('a'), isFalse);
    });

    test('eagerInit builds every shop up front', () {
      REES46.registerShops([cfg('a'), cfg('b')], eagerInit: true);

      expect(built, ['a', 'b']);
      expect(REES46.liveShopIds, ['a', 'b']);
      expect(REES46.pendingShopIds, isEmpty);
    });
  });

  group('getInstance', () {
    test('no id, single live shop → that instance', () {
      REES46.initialize(cfg('a'));
      expect(REES46.getInstance().shopId, 'a');
    });

    test('explicit id returns the matching live instance', () {
      REES46.initialize(cfg('a'));
      REES46.initialize(cfg('b'));
      expect(REES46.getInstance('b').shopId, 'b');
    });

    test('materializes a pending shop on first use', () {
      REES46.registerShops([cfg('a')]);
      expect(built, isEmpty);

      final sdk = REES46.getInstance('a');

      expect(sdk.shopId, 'a');
      expect(built, ['a']);
      expect(REES46.liveShopIds, ['a']);
      expect(REES46.pendingShopIds, isEmpty);
    });

    test('materializes a pending shop only once', () {
      REES46.registerShops([cfg('a')]);
      final first = REES46.getInstance('a');
      final second = REES46.getInstance('a');

      expect(built, ['a']); // built once
      expect(identical(first, second), isTrue);
    });

    test('no id with several shops → AmbiguousShopException', () {
      REES46.initialize(cfg('a'));
      REES46.registerShops([cfg('b')]);

      expect(
        () => REES46.getInstance(),
        throwsA(
          isA<AmbiguousShopException>().having(
            (e) => e.registeredShopIds,
            'registeredShopIds',
            ['a', 'b'],
          ),
        ),
      );
    });

    test('unknown id → UnknownShopIdException', () {
      REES46.initialize(cfg('a'));
      expect(
        () => REES46.getInstance('nope'),
        throwsA(
          isA<UnknownShopIdException>().having(
            (e) => e.shopId,
            'shopId',
            'nope',
          ),
        ),
      );
    });

    test('no id with nothing registered → UnknownShopIdException', () {
      expect(
        () => REES46.getInstance(),
        throwsA(isA<UnknownShopIdException>()),
      );
    });
  });

  group('isInitialized', () {
    test('null id true only when exactly one live shop', () {
      expect(REES46.isInitialized(), isFalse);
      REES46.initialize(cfg('a'));
      expect(REES46.isInitialized(), isTrue);
      REES46.initialize(cfg('b'));
      expect(REES46.isInitialized(), isFalse); // ambiguous default
    });

    test('pending shop is not counted as initialized', () {
      REES46.registerShops([cfg('a')]);
      expect(REES46.isInitialized('a'), isFalse);
      expect(REES46.isInitialized(), isFalse);
    });
  });
}
