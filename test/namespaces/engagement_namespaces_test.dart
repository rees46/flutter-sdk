import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rees46_sdk/rees46_sdk.dart';
import 'package:rees46_sdk/src/pigeon/personalization_api.g.dart' as pigeon;

import '../support/wire.dart';

pigeon.PushPayloadWire _push(String shopId, {String code = 'm1'}) =>
    pigeon.PushPayloadWire(
      shopId: shopId,
      code: code,
      type: 'bulk',
      title: 'Sale',
      body: 'Up to 30%',
      actions: [pigeon.PushActionWire(id: 'a1', title: 'Open', url: 'u')],
      target: pigeon.PushTargetWire(
        type: 'product',
        uri: '37',
        payload: const {'k': 1},
      ),
      source: 'utm',
      data: const {'id': 'm1', 'type': 'bulk', 'shop_id': 'x'},
    );

const _methods = [
  'notificationsTrackDelivered',
  'notificationsTrackOpened',
  'notificationsTrackClicked',
  'notificationsTrackClosed',
  'notificationsGetPushToken',
  'notificationsSetPushToken',
  'notificationsGetHistory',
  'slidersGet',
  'reviewsCreateNps',
  'reviewsCreateCsat',
  'reviewsCreateCes',
  'reviewsGetNpsCategories',
  'reviewsGetNpsChannels',
  'reviewsGetCsatCampaigns',
  'reviewsGetCesCampaigns',
  'reviewsGetProductReviews',
  'reviewsGetClientReviews',
  'trackBannerView',
  'trackBannerClick',
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

  group('notifications', () {
    test('the four events send the code and the type', () async {
      final calls = {
        for (final event in ['Delivered', 'Opened', 'Clicked', 'Closed'])
          event: stubValue('notificationsTrack$event', null),
      };
      final n = PersonalizationSdk(shopId: 's').notifications;
      await n.trackDelivered('c1', 'bulk');
      await n.trackOpened('c2', 'chain');
      await n.trackClicked('c3', 'transactional');
      await n.trackClosed('c4', 'digest');
      expect(calls['Delivered']!.single, ['c1', 'bulk', 's']);
      expect(calls['Opened']!.single, ['c2', 'chain', 's']);
      expect(calls['Clicked']!.single, ['c3', 'transactional', 's']);
      expect(calls['Closed']!.single, ['c4', 'digest', 's']);
    });

    test('an empty code is the native invalidArgument', () async {
      stubHost(
        'notificationsTrackClicked',
        (_) => errorReply('invalidArgument', message: 'code is empty'),
      );
      await expectLater(
        PersonalizationSdk().notifications.trackClicked('', 'bulk'),
        throwsA(
          isA<SdkException>().having((e) => e.type, 'type', 'invalidArgument'),
        ),
      );
    });

    test('getPushToken reads the copy of the native tokens', () async {
      stubValue(
        'initialize',
        snapshotWire(
          'push-shop',
          pushToken: pigeon.PushTokenWire(token: 't-fcm', provider: 'fcm'),
          pushTokens: [
            pigeon.PushTokenWire(token: 't-fcm', provider: 'fcm'),
            pigeon.PushTokenWire(token: 't-hms', provider: 'hms'),
          ],
        ),
      );
      final sdk = REES46.initialize(const REES46Config(shopId: 'push-shop'));
      expect(sdk.notifications.getPushToken(), isNull);
      await sdk.ready;
      final token = sdk.notifications.getPushToken()!;
      expect([token.token, token.provider], ['t-fcm', PushProvider.fcm]);
      expect(
        sdk.notifications.getPushToken(provider: PushProvider.hms)!.token,
        't-hms',
      );
      expect(
        sdk.notifications.getPushToken(provider: PushProvider.apns),
        isNull,
      );
    });

    test('readPushToken asks natively', () async {
      final calls = stubValue(
        'notificationsGetPushToken',
        pigeon.PushTokenWire(token: 'apns-token', provider: 'apns'),
      );
      final token = await PersonalizationSdk(
        shopId: 's',
      ).notifications.readPushToken(provider: PushProvider.apns);
      expect(calls.single, ['apns', 's']);
      expect(token!.provider, PushProvider.apns);
    });

    test('the released getStoredPushToken reads the stored token as 1.6.4 '
        'did, null for none', () async {
      final calls = stubValue('legacyGetStoredPushToken', 'fcm-token');
      final sdk = PersonalizationSdk(shopId: 's');
      // ignore: deprecated_member_use_from_same_package
      expect(await sdk.getStoredPushToken(), 'fcm-token');
      expect(calls.single, ['s']);
      stubValue('legacyGetStoredPushToken', null);
      // ignore: deprecated_member_use_from_same_package
      expect(await sdk.getStoredPushToken(), isNull);
      unstub('legacyGetStoredPushToken');
    });

    test('setPushToken sends the token and the provider', () async {
      final calls = stubValue('notificationsSetPushToken', null);
      await PersonalizationSdk(
        shopId: 's',
      ).notifications.setPushToken('tok', PushProvider.hms);
      expect(calls.single, ['tok', 'hms', 's']);
    });

    test(
      'push events reach the shop\'s callbacks, the shared ones else',
      () async {
        stubValue('initialize', snapshotWire('shop-a'));
        final a = REES46.initialize(const REES46Config(shopId: 'shop-a'));
        await a.ready;
        final heard = <String>[];
        a.notifications.setCallbacks(
          PushCallbacks(
            onDelivered: (p) => heard.add('a delivered ${p.code}'),
            onClicked: (p) =>
                heard.add('a clicked ${p.target!.type.value} ${p.target!.uri}'),
          ),
        );
        REES46.setPushCallbacks(
          PushCallbacks(
            onDelivered: (p) => heard.add('shared delivered ${p.shopId}'),
            onOpened: (p) => heard.add('shared opened ${p.title}'),
            onClosed: (p) => heard.add('shared closed ${p.actions.single.url}'),
          ),
        );
        await sendStateEvent('onPushEvent', [
          'shop-a',
          'delivered',
          _push('shop-a'),
        ]);
        await sendStateEvent('onPushEvent', [
          'shop-a',
          'opened',
          _push('shop-a'),
        ]);
        await sendStateEvent('onPushEvent', [
          'shop-a',
          'clicked',
          _push('shop-a'),
        ]);
        await sendStateEvent('onPushEvent', [
          'shop-b',
          'delivered',
          _push('shop-b'),
        ]);
        await sendStateEvent('onPushEvent', [
          'shop-a',
          'closed',
          _push('shop-a'),
        ]);
        expect(heard, [
          'a delivered m1',
          'shared opened Sale',
          'a clicked product 37',
          'shared delivered shop-b',
          'shared closed u',
        ]);
      },
    );

    test('a callback that throws does not stop the next event', () async {
      REES46.setPushCallbacks(
        PushCallbacks(onDelivered: (_) => throw StateError('app bug')),
      );
      final errors = <FlutterErrorDetails>[];
      final previous = FlutterError.onError;
      FlutterError.onError = errors.add;
      addTearDown(() => FlutterError.onError = previous);
      await sendStateEvent('onPushEvent', ['s', 'delivered', _push('s')]);
      expect(errors.single.exception, isA<StateError>());
    });

    test('a new token reaches onToken, once per callback', () async {
      stubValue('initialize', snapshotWire('shop-a'));
      final a = REES46.initialize(const REES46Config(shopId: 'shop-a'));
      await a.ready;
      final tokens = <String>[];
      void own(PushToken t) => tokens.add('own ${t.token}');
      a.notifications.setCallbacks(PushCallbacks(onToken: own));
      REES46.setPushCallbacks(
        PushCallbacks(onToken: (t) => tokens.add('shared ${t.provider.name}')),
      );
      await sendStateEvent('onPushToken', [
        pigeon.PushTokenWire(token: 'new', provider: 'fcm'),
      ]);
      expect(tokens, unorderedEquals(['own new', 'shared fcm']));
    });

    test('getHistory sends every argument and maps the messages', () async {
      final calls = stubValue(
        'notificationsGetHistory',
        pigeon.NotificationHistoryWire(
          status: 'success',
          messages: [
            pigeon.NotificationMessageWire(
              code: 'c1',
              channel: 'mobile_push',
              campaignId: 5,
              subject: 'Sale',
              statistics: pigeon.NotificationStatisticsWire(
                clicked: true,
                complained: false,
                hardBounced: false,
                opened: true,
                purchased: false,
                softBounced: false,
                unsubscribed: false,
              ),
            ),
          ],
        ),
      );
      final history = await PersonalizationSdk(shopId: 's').notifications
          .getHistory(
            'secret',
            'bulk,chain',
            phone: '+7',
            email: 'e',
            externalId: 'x',
            loyaltyId: 'l',
            channel: 'email,mobile_push',
            limit: 10,
            page: 2,
            dateFrom: '2026-01-01',
            did: 'd',
          );
      expect(calls.single, [
        'secret',
        'bulk,chain',
        '+7',
        'e',
        'x',
        'l',
        'email,mobile_push',
        10,
        2,
        '2026-01-01',
        'd',
        's',
      ]);
      final message = history.messages.single;
      expect(history.status, 'success');
      expect([message.code, message.campaignId], ['c1', 5]);
      expect(message.statistics!.clicked, isTrue);
    });
  });

  group('sliders and banners', () {
    test('get sends its arguments and maps the banners', () async {
      final calls = stubValue(
        'slidersGet',
        pigeon.SliderWire(
          code: 'main',
          width: 1200,
          height: 400,
          banners: [
            pigeon.SliderBannerWire(
              id: '5',
              code: 'b5',
              imageUrl: 'img',
              deeplinkIos: 'ios',
            ),
          ],
        ),
      );
      final slider = await PersonalizationSdk(
        shopId: 's',
      ).sliders.get('main', tags: ['home'], locationId: 'msk');
      expect(calls.single, [
        'main',
        ['home'],
        'msk',
        's',
      ]);
      expect([slider.code, slider.width, slider.height], ['main', 1200, 400]);
      expect(slider.banners.single.deeplinkIos, 'ios');
    });

    test('banner view and click go to the tracking namespace', () async {
      final views = stubValue('trackBannerView', null);
      final clicks = stubValue('trackBannerClick', null);
      final tracking = PersonalizationSdk(shopId: 's').tracking;
      await tracking.bannerView('5', 'b5');
      await tracking.bannerClick('5', 'b5');
      expect(views.single, ['5', 'b5', 's']);
      expect(clicks.single, ['5', 'b5', 's']);
    });

    test('a refused banner is the native invalidArgument', () async {
      stubHost('trackBannerView', (_) => errorReply('invalidArgument'));
      await expectLater(
        PersonalizationSdk().tracking.bannerView('x', 'b'),
        throwsA(
          isA<SdkException>().having((e) => e.type, 'type', 'invalidArgument'),
        ),
      );
    });
  });

  group('reviews', () {
    test('the three ratings send their arguments', () async {
      final nps = stubValue('reviewsCreateNps', pigeon.PollReviewWire(id: 1));
      final csat = stubValue('reviewsCreateCsat', pigeon.PollReviewWire(id: 2));
      final ces = stubValue(
        'reviewsCreateCes',
        pigeon.PollReviewWire(id: 9007199254740993),
      );
      final reviews = PersonalizationSdk(shopId: 's').reviews;
      final a = await reviews.createNps(
        9,
        'android_app',
        'delivery',
        orderId: 'o1',
        comment: 'ok',
        label: 'l',
      );
      final b = await reviews.createCsat(4, 'android_app', 'support');
      final c = await reviews.createCes(7, 'ios_app', 'checkout', label: 'x');
      expect(nps.single, [9, 'android_app', 'delivery', 'o1', 'ok', 'l', 's']);
      expect(csat.single, [4, 'android_app', 'support', null, null, null, 's']);
      expect(ces.single, [7, 'ios_app', 'checkout', null, null, 'x', 's']);
      expect([a.id, b.id, c.id], [1, 2, 9007199254740993]);
    });

    test('the dictionaries map their entries', () async {
      stubValue('reviewsGetNpsCategories', [
        pigeon.NpsCategoryWire(
          code: 'delivery',
          name: 'Delivery',
          promoterQuestion: 'Why?',
        ),
      ]);
      stubValue('reviewsGetNpsChannels', [
        pigeon.PollChannelWire(code: 'android_app', name: 'App'),
      ]);
      stubValue('reviewsGetCsatCampaigns', [
        pigeon.CsatCampaignWire(
          code: 'c',
          name: 'C',
          satisfiedSuccess: 'Thanks',
        ),
      ]);
      stubValue('reviewsGetCesCampaigns', [
        pigeon.CesCampaignWire(code: 'e', name: 'E', easyQuestion: 'Easy?'),
      ]);
      final reviews = PersonalizationSdk().reviews;
      expect(
        (await reviews.getNpsCategories()).single.promoterQuestion,
        'Why?',
      );
      expect((await reviews.getNpsChannels()).single.name, 'App');
      expect(
        (await reviews.getCsatCampaigns()).single.satisfiedSuccess,
        'Thanks',
      );
      expect((await reviews.getCesCampaigns()).single.easyQuestion, 'Easy?');
    });

    test('product and client reviews', () async {
      final productCalls = stubValue(
        'reviewsGetProductReviews',
        pigeon.ProductReviewsResponseWire(
          summary: pigeon.ProductRatingSummaryWire(
            count: 2,
            averageRating: 4.5,
            ratings: const {5: 1, 4: 1},
          ),
          reviews: [
            pigeon.ProductReviewWire(
              id: 1,
              rating: 5,
              author: 'Anna',
              createdAt: '2026-11-01T00:00:00Z',
            ),
          ],
        ),
      );
      stubValue('reviewsGetClientReviews', [
        pigeon.ClientReviewWire(
          id: 3,
          itemId: '37',
          orderId: 'o1',
          rating: 4,
          state: 'moderation',
          createdAt: '2026-11-02T00:00:00Z',
        ),
        pigeon.ClientReviewWire(
          id: 4,
          itemId: '38',
          orderId: 'o1',
          rating: 3,
          state: 'archived',
          createdAt: '2026-11-02T00:00:00Z',
        ),
      ]);
      final reviews = PersonalizationSdk().reviews;
      final product = await reviews.getProductReviews(
        '37',
        limit: 10,
        offset: 5,
      );
      final client = await reviews.getClientReviews('o1');
      expect(productCalls.single.take(3), ['37', 10, 5]);
      expect(product.summary.ratings, {5: 1, 4: 1});
      expect(product.summary.averageRating, 4.5);
      expect(product.reviews.single.author, 'Anna');
      expect(client.first.state, ReviewState.moderation);
      expect(client.last.state, isNull, reason: 'unknown state');
    });
  });
}
