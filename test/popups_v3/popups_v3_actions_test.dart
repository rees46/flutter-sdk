import 'package:flutter_test/flutter_test.dart';
import 'package:rees46_sdk/src/popups_v3/popups_v3_engine.dart';
import 'package:rees46_sdk/src/ui/components/personalization_product.dart';

import 'fixtures.dart';
import 'harness.dart';

/// Движок с показанным вручную попапом [fixture] (`id` фикстуры).
Future<({EngineHarness harness, PopupV3Actions actions})> _shown(
  String fixture,
) async {
  final popup = popupsV3Fixture(fixture);
  final harness = EngineHarness(
    server: FakeServer(popups: <Map<String, Object?>>[popup]),
  );
  await harness.engine.show(popup['id'] as int);
  await pumpEventQueue();
  return (
    harness: harness,
    actions: harness.presenter.actions[popup['id'] as int]!,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(PopupsV3Slots.reset);

  test(
    'email: subscription with the flags, then the segment, then events',
    () async {
      final shown = await _shown('element-email-collector.json');
      await shown.actions.subscribeEmail(
        email: 'demo+flutter@rees46.test',
        consentFields: const <String>['email_bulk', 'email_chain'],
        segmentId: '123',
      );
      await pumpEventQueue();
      final subscription = shown.harness.host.subscriptions.single;
      expect(subscription.email, 'demo+flutter@rees46.test');
      expect(subscription.emailBulk, isTrue);
      expect(subscription.emailChain, isTrue);
      expect(subscription.emailTransactional, isNull);
      final segment = shown.harness.server.requests.firstWhere(
        (request) => request.uri.path == '/segments/add',
      );
      expect(segment.body!['segment_id'], 123);
      expect(segment.body!['did'], 'DID123');
      expect(shown.harness.server.events, <String>[
        '9106:show',
        '9106:subscribe',
        '9106:submit',
      ]);
      final subscribe = shown.harness.server.requests.firstWhere(
        (request) => request.body?['event'] == 'subscribe',
      );
      expect(subscribe.body!['channel'], 'email');
    },
  );

  test(
    'form: the profile, consent flags with the contact, the segment',
    () async {
      final shown = await _shown('element-form.json');
      await shown.actions.submitProfile(
        const PopupV3ProfileSubmission(
          email: 'anna@example.com',
          phone: '+79990000000',
          firstName: 'Анна',
          lastName: 'Иванова',
          birthday: '1990-04-12',
          gender: 'f',
          custom: <String, String>{
            'fav_color': 'зелёный',
            'loyaltylevel': 'gold',
          },
          consentFields: <String>['email_bulk'],
          segmentId: '456',
        ),
      );
      await pumpEventQueue();
      final profile = shown.harness.host.profiles.single;
      expect(profile.email, 'anna@example.com');
      expect(profile.phone, '+79990000000');
      expect(profile.firstName, 'Анна');
      expect(profile.lastName, 'Иванова');
      expect(profile.birthday, '1990-04-12');
      expect(profile.gender, 'f');
      expect(profile.customPropertiesJson, contains('fav_color'));
      final subscription = shown.harness.host.subscriptions.single;
      expect(subscription.email, 'anna@example.com');
      expect(subscription.emailBulk, isTrue);
      expect(
        shown.harness.server.requests
            .where((request) => request.uri.path == '/segments/add')
            .single
            .body!['segment_id'],
        456,
      );
      expect(shown.harness.server.events.last, '9107:submit');
    },
  );

  test('form without consent: no subscription', () async {
    final shown = await _shown('element-form.json');
    await shown.actions.submitProfile(
      const PopupV3ProfileSubmission(firstName: 'Анна'),
    );
    expect(shown.harness.host.subscriptions, isEmpty);
    expect(shown.harness.host.profiles.single.firstName, 'Анна');
  });

  test(
    'survey: NPS by category, CSAT and CES by campaign, comment trimmed',
    () async {
      final requests = popupsV3Fixture('requests.json');
      final shown = await _shown('element-survey.json');
      await shown.actions.review(
        kind: 'nps',
        code: 'test',
        rate: 0,
        comment: 'Долгая доставка',
      );
      await shown.actions.review(
        kind: 'csat',
        code: 'MNTEST',
        rate: 5,
        comment: '  ',
      );
      await shown.actions.review(kind: 'ces', code: 'MN TEST', rate: 7);
      Map<String, Object?> body(String name) => <String, Object?>{
        for (final entry
            in ((requests[name] as Map<String, Object?>)['json']
                    as Map<String, Object?>)
                .entries)
          if (!<String>['shop_id', 'did', 'sid'].contains(entry.key))
            entry.key: entry.value,
      };
      final reviews = shown.harness.platform.reviews;
      expect(reviews.map((review) => review.kind), <String>[
        'nps',
        'csat',
        'ces',
      ]);
      expect(reviews[0].body, body('review_nps'));
      expect(reviews[1].body, body('review_csat_no_comment'));
      expect(reviews[2].body, <String, Object>{
        'channel': 'popup',
        'campaign': 'MN TEST',
        'rate': 7,
      });
      await pumpEventQueue();
      expect(
        shown.harness.server.events.where((event) => event.endsWith('submit')),
        hasLength(3),
      );
    },
  );

  test('a failed review throws and sends no submit', () async {
    final shown = await _shown('element-survey.json');
    shown.harness.platform.reviewError = Exception('Channel not found');
    await expectLater(
      shown.actions.review(kind: 'nps', code: '', rate: 9),
      throwsException,
    );
    await pumpEventQueue();
    expect(shown.harness.server.events, <String>['9109:show']);
  });

  test('links: the host handler first, unsafe schemes never', () async {
    final shown = await _shown('element-button.json');
    await shown.actions.openLink('https://demo.rees46.ru/');
    await shown.actions.openLink('javascript:alert(1)');
    await shown.actions.openLink('  ');
    expect(shown.harness.host.opened, <String>['https://demo.rees46.ru/']);
    final handled = <String>[];
    shown.harness.engine.onLink = (url) {
      handled.add(url);
      return true;
    };
    await shown.actions.openLink('rees46demo://sale');
    expect(handled, <String>['rees46demo://sale']);
    expect(shown.harness.host.opened, hasLength(1));
  });

  test('products: the host opens them, otherwise the product link', () async {
    final shown = await _shown('element-recommendation.json');
    expect(shown.actions.openProduct(fakeProduct), isFalse);
    await pumpEventQueue();
    expect(shown.harness.host.opened, <String>[fakeProduct.url!]);

    final taken = <String>[];
    shown.harness.engine.onProductClick = (product) {
      taken.add(product.id);
      return true;
    };
    expect(shown.actions.openProduct(fakeProduct), isTrue);
    await pumpEventQueue();
    expect(taken, <String>['868']);
    expect(shown.harness.host.opened, hasLength(1));
  });

  test('products: declined or failed by the host — the deeplink, else the url, '
      'through the link handler', () async {
    final shown = await _shown('element-recommendation.json');
    final links = <String>[];
    shown.harness.engine.onLink = (url) {
      links.add(url);
      return true;
    };
    shown.harness.engine.onProductClick = (product) => false;
    expect(
      shown.actions.openProduct(
        const PersonalizationProduct(
          id: '868',
          name: 'Товар',
          price: '100 ₽',
          url: 'https://demo.rees46.ru/product/868',
          deeplink: 'rees46demo://product/868',
        ),
      ),
      isFalse,
    );
    shown.harness.engine.onProductClick = (product) =>
        throw StateError('no shop');
    expect(
      shown.actions.openProduct(
        const PersonalizationProduct(
          id: '868',
          name: 'Товар',
          price: '100 ₽',
          url: 'https://demo.rees46.ru/product/868',
          deeplink: ' ',
        ),
      ),
      isFalse,
    );
    await pumpEventQueue();
    expect(links, <String>[
      'rees46demo://product/868',
      'https://demo.rees46.ru/product/868',
    ]);
    expect(shown.harness.host.opened, isEmpty);
  });

  test('the close event comes from the presenter', () async {
    final shown = await _shown('element-text.json');
    shown.harness.presenter.close(9101);
    await pumpEventQueue();
    expect(shown.harness.server.events, <String>['9101:show', '9101:close']);
    expect(shown.harness.engine.openIds, isEmpty);
  });
}
