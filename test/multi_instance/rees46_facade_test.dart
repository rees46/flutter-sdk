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

  Rees46Config cfg(String shopId) => Rees46Config(shopId: shopId);

  setUp(() {
    built = <String>[];
    Rees46.debugFactory = (config) {
      built.add(config.shopId);
      return PersonalizationSdk(shopId: config.shopId);
    };
  });

  tearDown(Rees46.reset);

  group('initialize', () {
    test('returns a handle bound to the shop and marks it live', () {
      final sdk = Rees46.initialize(cfg('a'));

      expect(sdk.shopId, 'a');
      expect(built, ['a']);
      expect(Rees46.isInitialized('a'), isTrue);
      expect(Rees46.liveShopIds, ['a']);
    });

    test('clears any pending registration for the same shop', () {
      Rees46.registerShops([cfg('a')]);
      expect(Rees46.pendingShopIds, ['a']);

      Rees46.initialize(cfg('a'));

      expect(Rees46.pendingShopIds, isEmpty);
      expect(Rees46.liveShopIds, ['a']);
    });
  });

  group('registerShops', () {
    test('lazy by default — registers without building', () {
      Rees46.registerShops([cfg('a'), cfg('b')]);

      expect(built, isEmpty);
      expect(Rees46.pendingShopIds, ['a', 'b']);
      expect(Rees46.isInitialized('a'), isFalse);
    });

    test('eagerInit builds every shop up front', () {
      Rees46.registerShops([cfg('a'), cfg('b')], eagerInit: true);

      expect(built, ['a', 'b']);
      expect(Rees46.liveShopIds, ['a', 'b']);
      expect(Rees46.pendingShopIds, isEmpty);
    });
  });

  group('getInstance', () {
    test('no id, single live shop → that instance', () {
      Rees46.initialize(cfg('a'));
      expect(Rees46.getInstance().shopId, 'a');
    });

    test('explicit id returns the matching live instance', () {
      Rees46.initialize(cfg('a'));
      Rees46.initialize(cfg('b'));
      expect(Rees46.getInstance('b').shopId, 'b');
    });

    test('materializes a pending shop on first use', () {
      Rees46.registerShops([cfg('a')]);
      expect(built, isEmpty);

      final sdk = Rees46.getInstance('a');

      expect(sdk.shopId, 'a');
      expect(built, ['a']);
      expect(Rees46.liveShopIds, ['a']);
      expect(Rees46.pendingShopIds, isEmpty);
    });

    test('materializes a pending shop only once', () {
      Rees46.registerShops([cfg('a')]);
      final first = Rees46.getInstance('a');
      final second = Rees46.getInstance('a');

      expect(built, ['a']); // built once
      expect(identical(first, second), isTrue);
    });

    test('no id with several shops → AmbiguousShopException', () {
      Rees46.initialize(cfg('a'));
      Rees46.registerShops([cfg('b')]);

      expect(
        () => Rees46.getInstance(),
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
      Rees46.initialize(cfg('a'));
      expect(
        () => Rees46.getInstance('nope'),
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
        () => Rees46.getInstance(),
        throwsA(isA<UnknownShopIdException>()),
      );
    });
  });

  group('isInitialized', () {
    test('null id true only when exactly one live shop', () {
      expect(Rees46.isInitialized(), isFalse);
      Rees46.initialize(cfg('a'));
      expect(Rees46.isInitialized(), isTrue);
      Rees46.initialize(cfg('b'));
      expect(Rees46.isInitialized(), isFalse); // ambiguous default
    });

    test('pending shop is not counted as initialized', () {
      Rees46.registerShops([cfg('a')]);
      expect(Rees46.isInitialized('a'), isFalse);
      expect(Rees46.isInitialized(), isFalse);
    });
  });
}
