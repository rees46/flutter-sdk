import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rees46_sdk/rees46_sdk.dart';
import 'package:rees46_sdk/src/pigeon/personalization_api.g.dart' as pigeon;

import '../support/wire.dart';

/// Each tracking method and the channel it goes by.
final _events = <String, Future<void> Function(TrackingApi tracking)>{
  'trackProductView': (t) => t.productView('37'),
  'trackCategoryView': (t) => t.categoryView('7'),
  'trackSearch': (t) => t.search('kettle'),
  'trackAddToCart': (t) => t.addToCart(const TrackingItem(id: '37')),
  'trackSyncCart': (t) => t.syncCart(const [TrackingItem(id: '37')]),
  'trackRemoveFromCart': (t) => t.removeFromCart('37'),
  'trackAddToFavorites': (t) => t.addToFavorites('37'),
  'trackSyncFavorites': (t) => t.syncFavorites(const ['37']),
  'trackRemoveFromFavorites': (t) => t.removeFromFavorites('37'),
  'trackStoryView': (t) => t.storyView('1', '2'),
  'trackStoryClick': (t) => t.storyClick('1', '2'),
  'trackBannerView': (t) => t.bannerView('b1', 'slider'),
  'trackBannerClick': (t) => t.bannerClick('b1', 'slider'),
  'trackPopupShown': (t) => t.popupShown(9),
  'trackEvent': (t) => t.custom('an_event_the_shop_does_not_know'),
  'trackPurchase': (t) => t.purchase(
    const PurchaseTrackingRequest(
      orderId: 'order-1',
      orderPrice: 1990,
      items: [PurchaseItem(id: '37', amount: 1, price: 1990)],
    ),
  ),
};

// A tracking call completes once the native side reports that the shop's queue
// accepted the event — on Android and iOS alike — and fails only with the error
// that kept the event out of the queue. The server's later answer is not the call's.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    for (final channel in [..._events.keys, 'notificationsGetHistory']) {
      unstub(channel);
    }
  });

  test('every tracking method completes when the native side accepts the '
      'event, not before', () async {
    for (final MapEntry(key: channel, value: send) in _events.entries) {
      final accepted = Completer<void>();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMessageHandler(hostChannel(channel), (_) async {
            await accepted.future;
            return okReply(null);
          });
      var done = false;

      final call = send(PersonalizationSdk(shopId: 's').tracking).then((_) {
        done = true;
      });
      await pumpEventQueue();
      expect(done, isFalse, reason: channel);

      accepted.complete();
      await call;
      expect(done, isTrue, reason: channel);
    }
  });

  test('an event kept out of the queue fails with the native error', () async {
    const errors = {
      'invalidArgument': SdkErrorInvalidArgument,
      'shopBlocked': SdkErrorShopBlocked,
      'notInitialized': SdkErrorNotInitialized,
    };
    for (final MapEntry(key: channel, value: send) in _events.entries) {
      for (final MapEntry(key: type, value: kind) in errors.entries) {
        stubHost(channel, (_) => errorReply(type));

        await expectLater(
          send(PersonalizationSdk(shopId: 's').tracking),
          throwsA(
            isA<SdkException>()
                .having((e) => e.error.runtimeType, 'error', kind)
                .having((e) => e, 'released type', isA<PlatformException>()),
          ),
          reason: '$channel $type',
        );
      }
    }
  });

  group('notifications.getHistory', () {
    test(
      'a message carries the channel, campaign id and every statistic',
      () async {
        stubValue(
          'notificationsGetHistory',
          pigeon.NotificationHistoryWire(
            status: 'success',
            messages: [
              pigeon.NotificationMessageWire(
                body: 'Up to 50%',
                campaignId: 4217,
                channel: 'email',
                code: 'c-1',
                date: '2026-11-01',
                icon: 'https://img.test/i.png',
                picture: 'https://img.test/p.png',
                sentAt: '2026-11-01T10:00:00Z',
                statistics: pigeon.NotificationStatisticsWire(
                  clicked: true,
                  complained: false,
                  hardBounced: false,
                  opened: true,
                  purchased: true,
                  softBounced: true,
                  unsubscribed: false,
                ),
                subject: 'Sale',
                type: 'bulk',
                url: 'https://shop.test/sale',
              ),
            ],
          ),
        );

        final history = await PersonalizationSdk(
          shopId: 's',
        ).notifications.getHistory('secret', 'bulk');

        expect(history.status, 'success');
        final m = history.messages.single;
        expect(
          [m.body, m.campaignId, m.channel, m.code, m.date, m.icon, m.picture],
          [
            'Up to 50%',
            4217,
            'email',
            'c-1',
            '2026-11-01',
            'https://img.test/i.png',
            'https://img.test/p.png',
          ],
        );
        expect(
          [m.sentAt, m.subject, m.type, m.url],
          ['2026-11-01T10:00:00Z', 'Sale', 'bulk', 'https://shop.test/sale'],
        );
        final s = m.statistics!;
        expect(
          [
            s.clicked,
            s.complained,
            s.hardBounced,
            s.opened,
            s.purchased,
            s.softBounced,
            s.unsubscribed,
          ],
          [true, false, false, true, true, true, false],
        );
      },
    );

    test('what the answer lacks stays null', () async {
      stubValue(
        'notificationsGetHistory',
        pigeon.NotificationHistoryWire(
          messages: [pigeon.NotificationMessageWire(code: 'c-2')],
        ),
      );

      final history = await PersonalizationSdk(
        shopId: 's',
      ).notifications.getHistory('secret', 'chain');

      expect(history.status, isNull);
      final m = history.messages.single;
      expect([m.campaignId, m.channel, m.statistics], [null, null, null]);
    });
  });
}
