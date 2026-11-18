import 'package:flutter_test/flutter_test.dart';
import 'package:rees46_sdk/rees46_sdk.dart';
import 'package:rees46_sdk/src/pigeon/personalization_api.g.dart' as pigeon;
import 'package:rees46_sdk/src/popups_v3/popups_v3_hooks.dart';

import '../support/wire.dart';

/// Records what the namespaces tell the engine of popups.
class _Hooks implements PopupsV3Listener {
  final changes = <String>[];

  @override
  void onContextChanged(String type, String action, Object? data) =>
      changes.add('$type.$action');

  @override
  void onInitialized(SdkInitConfig config) {}

  @override
  void onPurchase() {}

  @override
  void onTrackEvent(String event) {}
}

const _methods = [
  'cartGet',
  'cartClear',
  'profileGet',
  'profileSet',
  'profileGetLastOrder',
  'profileGetOrders',
  'subscriptionsManage',
  'subscriptionsCheck',
  'subscriptionsSubscribeForPriceDrop',
  'subscriptionsUnsubscribeFromPriceDrop',
  'subscriptionsSubscribeForBackInStock',
  'subscriptionsUnsubscribeFromBackInStock',
  'segmentsAdd',
  'segmentsRemove',
  'segmentsGet',
  'loyaltyJoin',
  'loyaltyGetStatus',
  'loyaltyGetPromotions',
  'predictGetProbabilityToPurchase',
  'initialize',
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    for (final m in _methods) {
      unstub(m);
    }
    REES46.reset();
  });

  group('cart', () {
    test('get maps the items', () async {
      final calls = stubValue('cartGet', [
        pigeon.CartItemWire(id: '37', quantity: 2),
      ]);
      final items = await PersonalizationSdk(shopId: 's').cart.get();
      expect(calls.single, ['s']);
      expect(items.single.id, '37');
      expect(items.single.quantity, 2);
    });

    test('clear sends the secret and the ids, in order', () async {
      final calls = stubValue('cartClear', null);
      await PersonalizationSdk(shopId: 's').cart.clear(
        'secret',
        email: 'e',
        phone: 'p',
        loyaltyId: 'l',
        externalId: 'x',
        telegramId: 't',
      );
      expect(calls.single, ['secret', 'e', 'p', 'l', 'x', 't', 's']);
    });

    test('a wrong secret is http 403', () async {
      stubHost('cartClear', (_) => errorReply('http', httpCode: 403));
      await expectLater(
        PersonalizationSdk().cart.clear('wrong', externalId: 'x'),
        throwsA(isA<SdkException>().having((e) => e.httpCode, 'code', 403)),
      );
    });
  });

  group('profile', () {
    test('get maps the profile, genders included', () async {
      stubValue(
        'profileGet',
        pigeon.ProfileWire(
          id: 'u1',
          hasEmail: true,
          emailRegisteredAt: '2026-01-01 10:00:00',
          gender: 'f',
          computedGender: 'm',
          boughtSomething: true,
          customProperties: const {
            'tier': 'gold',
            'kids': [1, 2],
          },
        ),
      );
      final p = await PersonalizationSdk().profile.get();
      expect(p.id, 'u1');
      expect(p.hasEmail, isTrue);
      expect(p.emailRegisteredAt, '2026-01-01 10:00:00');
      expect(p.gender, Gender.female);
      expect(p.computedGender, Gender.male);
      expect(p.boughtSomething, isTrue);
      expect(p.customProperties, {
        'tier': 'gold',
        'kids': [1, 2],
      });
    });

    test('set sends the request and tells popups of the change', () async {
      final calls = stubValue('profileSet', null);
      final hooks = _Hooks();
      final sdk = PersonalizationSdk();
      PopupsV3Hooks.listen(sdk.tracking, hooks);
      await sdk.profile.set(
        const ProfileUpdateRequest(
          email: 'a@b.test',
          externalId: 'x1',
          gender: Gender.male,
          birthday: '1990-05-17',
          age: 36,
          kids: [ProfileKid(gender: Gender.female, birthday: '2020-01-01')],
          cars: [ProfileCar(brand: 'Lada', model: 'Niva', vds: 'v')],
          customProperties: {'tier': 'gold'},
        ),
      );
      final r = calls.single[0]! as pigeon.ProfileUpdateRequestWire;
      expect([r.email, r.externalId, r.gender], ['a@b.test', 'x1', 'm']);
      expect([r.birthday, r.age], ['1990-05-17', 36]);
      expect(r.kids!.single.gender, 'f');
      expect(r.cars!.single.model, 'Niva');
      expect(r.customProperties, {'tier': 'gold'});
      expect(hooks.changes, ['profile.set']);
    });

    test('getLastOrder maps the products', () async {
      stubValue('profileGetLastOrder', [
        pigeon.ProductWire(
          id: '37',
          name: 'Kettle',
          url: 'u',
          price: 5,
          currency: '₽',
          isNew: false,
        ),
      ]);
      final products = await PersonalizationSdk().profile.getLastOrder();
      expect(products.single.id, '37');
    });

    test('getOrders sends the secret and ids, maps the orders', () async {
      final calls = stubValue('profileGetOrders', [
        pigeon.OrderWire(
          internalId: 9007199254740993,
          id: 'o1',
          value: '69990.0',
          taxFree: false,
          items: [
            pigeon.OrderItemWire(
              amount: 1,
              price: '69990.0',
              item: pigeon.ProductWire(
                id: '37',
                name: 'Phone',
                url: 'u',
                price: 69990,
                currency: '₽',
                isNew: false,
              ),
            ),
          ],
        ),
      ]);
      final orders = await PersonalizationSdk(
        shopId: 's',
      ).profile.getOrders('secret', externalId: 'x', dateFrom: '2026-01-01');
      expect(calls.single, [
        'secret',
        null,
        null,
        null,
        null,
        'x',
        '2026-01-01',
        's',
      ]);
      final order = orders.single;
      expect(order.internalId, 9007199254740993);
      expect(order.value, '69990.0');
      expect(order.items.single.item!.name, 'Phone');
    });
  });

  group('subscriptions', () {
    test('manage sends the flags and tells popups of the change', () async {
      final calls = stubValue('subscriptionsManage', null);
      final hooks = _Hooks();
      final sdk = PersonalizationSdk();
      PopupsV3Hooks.listen(sdk.tracking, hooks);
      await sdk.subscriptions.manage(
        const SubscriptionsUpdateRequest(
          phone: '+7',
          smsBulk: true,
          walletChain: false,
        ),
      );
      final r = calls.single[0]! as pigeon.SubscriptionsUpdateRequestWire;
      expect([r.phone, r.smsBulk, r.walletChain], ['+7', true, false]);
      expect(r.emailBulk, isNull);
      expect(hooks.changes, ['subscription.manage']);
    });

    test('check maps the status', () async {
      stubValue(
        'subscriptionsCheck',
        pigeon.SubscriptionStatusWire(
          exists: true,
          emailBulk: true,
          emailChain: false,
          emailTransactional: false,
          smsBulk: false,
          smsChain: false,
          smsTransactional: false,
          webPushBulk: false,
          webPushChain: false,
          webPushTransactional: false,
          mobilePushBulk: true,
          mobilePushChain: false,
          mobilePushTransactional: false,
          telegramBulk: false,
          telegramChain: false,
          telegramTransactional: false,
          whatsappBulk: false,
          whatsappChain: false,
          whatsappTransactional: false,
          maxBulk: false,
          maxChain: false,
          maxTransactional: false,
          walletBulk: false,
          walletChain: false,
          walletTransactional: true,
          hasWebPush: false,
          hasMobilePush: true,
          emailInvalid: false,
          emailBlacklisted: false,
          emailBounced: false,
          emailSuppressed: false,
          emailConfirmed: true,
        ),
      );
      final s = await PersonalizationSdk().subscriptions.check();
      expect(s.exists, isTrue);
      expect(s.emailBulk, isTrue);
      expect(s.mobilePushBulk, isTrue);
      expect(s.walletTransactional, isTrue);
      expect(s.hasMobilePush, isTrue);
      expect(s.emailConfirmed, isTrue);
      expect(s.smsBulk, isFalse);
    });

    test('price drop and back in stock send their arguments', () async {
      final drop = stubValue('subscriptionsSubscribeForPriceDrop', null);
      final undrop = stubValue('subscriptionsUnsubscribeFromPriceDrop', null);
      final stock = stubValue('subscriptionsSubscribeForBackInStock', null);
      final unstock = stubValue(
        'subscriptionsUnsubscribeFromBackInStock',
        null,
      );
      final subscriptions = PersonalizationSdk(shopId: 's').subscriptions;
      await subscriptions.subscribeForPriceDrop('37', 99.9, email: 'e');
      await subscriptions.unsubscribeFromPriceDrop(const [], phone: 'p');
      await subscriptions.subscribeForBackInStock(
        '37',
        properties: const BackInStockProperties(
          fashionSize: 'M',
          fashionColor: 'red',
          barcode: 'b',
        ),
      );
      await subscriptions.unsubscribeFromBackInStock(const ['37', '38']);
      expect(drop.single, ['37', 99.9, 'e', null, 's']);
      expect(undrop.single, [<Object?>[], null, 'p', 's']);
      final props = stock.single[1]! as pigeon.BackInStockPropertiesWire;
      expect(stock.single[0], '37');
      expect(
        [props.fashionSize, props.fashionColor, props.barcode],
        ['M', 'red', 'b'],
      );
      expect(unstock.single, [
        ['37', '38'],
        null,
        null,
        's',
      ]);
    });
  });

  group('segments', () {
    test('add, remove and get, popups told of the changes', () async {
      final adds = stubValue('segmentsAdd', null);
      final removes = stubValue('segmentsRemove', null);
      stubValue('segmentsGet', [
        pigeon.SegmentWire(id: 12, type: 'static'),
        pigeon.SegmentWire(id: 13),
      ]);
      final hooks = _Hooks();
      final sdk = PersonalizationSdk(shopId: 's');
      PopupsV3Hooks.listen(sdk.tracking, hooks);
      await sdk.segments.add(12, email: 'e');
      await sdk.segments.remove(12, phone: 'p');
      final segments = await sdk.segments.get();
      expect(adds.single, [12, 'e', null, 's']);
      expect(removes.single, [12, null, 'p', 's']);
      expect(segments.map((s) => (s.id, s.type)), [(12, 'static'), (13, null)]);
      expect(hooks.changes, ['segment.add', 'segment.remove']);
    });

    test('getAbGroup is the copy of the native A/B group', () async {
      stubValue('initialize', snapshotWire('ab-shop', segment: 'B'));
      final sdk = REES46.initialize(const REES46Config(shopId: 'ab-shop'));
      expect(sdk.segments.getAbGroup(), '', reason: 'before the answer');
      await sdk.ready;
      expect(sdk.segments.getAbGroup(), 'B');
    });
  });

  group('loyalty', () {
    test('join sends the member fields, gender as m / f', () async {
      final calls = stubValue(
        'loyaltyJoin',
        pigeon.LoyaltyMemberWire(identifier: '79991234567'),
      );
      final member = await PersonalizationSdk(shopId: 's').loyalty.join(
        '+79991234567',
        firstName: 'Anna',
        lastName: 'Ivanova',
        gender: Gender.female,
        birthday: '1990-05-17',
      );
      expect(calls.single, [
        '+79991234567',
        'Anna',
        'Ivanova',
        'f',
        '1990-05-17',
        's',
      ]);
      expect(member.identifier, '79991234567');
    });

    test('getStatus maps the level', () async {
      stubValue(
        'loyaltyGetStatus',
        pigeon.LoyaltyStatusWire(
          isMember: true,
          level: pigeon.LoyaltyLevelWire(code: 'gold', name: 'Gold'),
        ),
      );
      final s = await PersonalizationSdk().loyalty.getStatus('+7');
      expect(s.isMember, isTrue);
      expect([s.level!.code, s.level!.name], ['gold', 'Gold']);
    });

    test('getPromotions sends its arguments and maps reward types', () async {
      final calls = stubValue('loyaltyGetPromotions', [
        pigeon.LoyaltyPromotionWire(
          id: 9007199254740993,
          name: 'x2',
          rewardType: 'bonuses_earn',
          badgeLabel: 'x2',
        ),
        pigeon.LoyaltyPromotionWire(id: 2, name: 'new', rewardType: 'future'),
      ]);
      final promotions = await PersonalizationSdk().loyalty.getPromotions(
        locationId: 'msk',
        promoCodes: ['A'],
        chargeBonuses: true,
        currentTime: '10:30',
      );
      expect(calls.single.take(4), [
        'msk',
        ['A'],
        true,
        '10:30',
      ]);
      expect(promotions.first.id, 9007199254740993);
      expect(promotions.first.rewardType, LoyaltyRewardType.bonusesEarn);
      expect(promotions.last.rewardType, isNull, reason: 'unknown value');
    });
  });

  group('predict', () {
    test('maps the probability', () async {
      stubValue(
        'predictGetProbabilityToPurchase',
        pigeon.PurchaseProbabilityWire(probability: 0.42, clientId: 'c1'),
      );
      final p = await PersonalizationSdk().predict.getProbabilityToPurchase();
      expect([p.probability, p.clientId], [0.42, 'c1']);
    });

    test('a shop without the service is http 402', () async {
      stubHost(
        'predictGetProbabilityToPurchase',
        (_) => errorReply('http', httpCode: 402),
      );
      await expectLater(
        PersonalizationSdk().predict.getProbabilityToPurchase(),
        throwsA(
          isA<SdkException>().having(
            (e) => e.error,
            'error',
            const SdkErrorHttp(402),
          ),
        ),
      );
    });
  });
}
