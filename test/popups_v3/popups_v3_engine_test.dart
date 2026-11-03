import 'package:flutter_test/flutter_test.dart';
import 'package:rees46_sdk/src/personalization_sdk.dart';
import 'package:rees46_sdk/src/popups_v3/popup_v3.dart';
import 'package:rees46_sdk/src/popups_v3/popups_v3.dart';
import 'package:rees46_sdk/src/popups_v3/popups_v3_engine.dart';
import 'package:rees46_sdk/src/popups_v3/popups_v3_frequency.dart';
import 'package:rees46_sdk/src/sdk_init_config.dart';

import 'fixtures.dart';
import 'harness.dart';

/// Попапы `list-response.json` по id.
Map<int, Map<String, Object?>> _listPopups() {
  final fixture = popupsV3Fixture('list-response.json');
  return <int, Map<String, Object?>>{
    for (final popup
        in ((fixture['payload'] as Map<String, Object?>)['popups'] as List)
            .cast<Map<String, Object?>>())
      popup['id'] as int: popup,
  };
}

/// Попап [id] из списка, с правками [changes].
Map<String, Object?> _popup(
  int id, [
  Map<String, Object?> changes = const {},
]) => <String, Object?>{..._listPopups()[id]!, ...changes};

Future<EngineHarness> _started(List<Map<String, Object?>> popups) async {
  final harness = EngineHarness(server: FakeServer(popups: popups));
  await harness.engine.start();
  await pumpEventQueue();
  return harness;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(PopupsV3Slots.reset);

  group('scenarios.json', () {
    test('the fixture has 18 scenarios', () {
      expect(
        (popupsV3Fixture('scenarios.json')['scenarios'] as List).length,
        18,
      );
    });

    test('app_start without screens: shown at list loaded', () async {
      final harness = await _started(<Map<String, Object?>>[_popup(512)]);
      expect(harness.presenter.shown, <int>[512]);
      expect(harness.server.events, <String>['512:show']);
    });

    test('app_start waits for a matching screen', () async {
      final harness = await _started(<Map<String, Object?>>[
        _popup(512, <String, Object?>{
          'target_screens': <String>['product'],
        }),
      ]);
      expect(harness.presenter.shown, isEmpty);
      harness.engine.screenOpened('home');
      await pumpEventQueue();
      expect(harness.presenter.shown, isEmpty);
      harness.engine.screenOpened('product');
      await pumpEventQueue();
      expect(harness.presenter.shown, <int>[512]);
    });

    test('screen_open on a listed screen', () async {
      final harness = await _started(<Map<String, Object?>>[_popup(513)]);
      harness.engine.screenOpened('home');
      await pumpEventQueue();
      expect(harness.presenter.shown, isEmpty);
      harness.engine.screenOpened('product');
      await pumpEventQueue();
      expect(harness.presenter.shown, <int>[513]);
    });

    test('screen_open with no screens: any screen', () async {
      final harness = await _started(<Map<String, Object?>>[
        _popup(513, <String, Object?>{'target_screens': <String>[]}),
      ]);
      harness.engine.screenOpened('home');
      await pumpEventQueue();
      expect(harness.presenter.shown, <int>[513]);
    });

    test('time_on_screen: left the screen early', () async {
      final harness = await _started(<Map<String, Object?>>[_popup(514)]);
      harness.engine.screenOpened('home');
      harness.clock.advance(const Duration(seconds: 9));
      harness.engine.screenOpened('category');
      harness.clock.advance(const Duration(seconds: 11));
      await pumpEventQueue();
      expect(harness.presenter.shown, isEmpty);
    });

    test('time_on_screen: stayed long enough', () async {
      final harness = await _started(<Map<String, Object?>>[_popup(514)]);
      harness.engine.screenOpened('home');
      harness.clock.advance(const Duration(milliseconds: 9900));
      await pumpEventQueue();
      expect(harness.presenter.shown, isEmpty);
      harness.clock.advance(const Duration(milliseconds: 100));
      await pumpEventQueue();
      expect(harness.presenter.shown, <int>[514]);
    });

    test('time_on_screen: the background resets the timer', () async {
      final harness = await _started(<Map<String, Object?>>[_popup(514)]);
      harness.engine.screenOpened('home');
      harness.clock.advance(const Duration(seconds: 5));
      harness.engine.onBackground();
      harness.clock.advance(const Duration(seconds: 25));
      harness.engine.onForeground();
      harness.clock.advance(const Duration(seconds: 9));
      await pumpEventQueue();
      expect(harness.presenter.shown, isEmpty);
      harness.clock.advance(const Duration(seconds: 1));
      await pumpEventQueue();
      expect(harness.presenter.shown, <int>[514]);
    });

    test('track_event', () async {
      final harness = await _started(<Map<String, Object?>>[_popup(515)]);
      harness.engine.onTrackEvent('other');
      await pumpEventQueue();
      expect(harness.presenter.shown, isEmpty);
      harness.engine.onTrackEvent('promo_view');
      await pumpEventQueue();
      expect(harness.presenter.shown, <int>[515]);
    });

    test(
      'track_event on another screen does not wait for the screen',
      () async {
        final harness = await _started(<Map<String, Object?>>[
          _popup(515, <String, Object?>{
            'target_screens': <String>['cart'],
          }),
        ]);
        harness.engine.screenOpened('home');
        harness.engine.onTrackEvent('promo_view');
        harness.engine.screenOpened('cart');
        await pumpEventQueue();
        expect(harness.presenter.shown, isEmpty);
      },
    );

    test('manual: GET the popup, show it, no frequency', () async {
      final harness = await _started(<Map<String, Object?>>[_popup(516)]);
      harness.engine.screenOpened('home');
      await pumpEventQueue();
      expect(harness.presenter.shown, isEmpty);
      await harness.engine.show(516);
      await pumpEventQueue();
      expect(harness.presenter.shown, <int>[516]);
      expect(
        harness.server.requests.map((request) => request.uri.path),
        contains('/api/v3/storefront/popups/516'),
      );
      expect(harness.storage.shows[516], isNull);
    });

    test(
      'once_session: shown, not again in the session, again in a new one',
      () async {
        final first = await _started(<Map<String, Object?>>[_popup(512)]);
        expect(first.presenter.shown, <int>[512]);
        first.presenter.close(512);
        await pumpEventQueue();

        final sameSession = first.restart();
        await sameSession.engine.start();
        await pumpEventQueue();
        expect(sameSession.presenter.shown, isEmpty);

        sameSession.host.sid = 'SID456';
        final newSession = sameSession.restart();
        await newSession.engine.start();
        await pumpEventQueue();
        expect(newSession.presenter.shown, <int>[512]);
      },
    );

    test(
      'app_start once_session: not again on other screens, again in a new session',
      () async {
        final harness = await _started(<Map<String, Object?>>[_popup(512)]);
        harness.presenter.close(512);
        await pumpEventQueue();
        await harness.engine.refresh();
        harness.engine.screenOpened('home');
        harness.engine.screenOpened('product');
        await pumpEventQueue();
        expect(harness.presenter.shown, <int>[512]);
        harness.host.sid = 'SID456';
        harness.engine.onBackground();
        harness.engine.onForeground();
        await pumpEventQueue();
        expect(harness.presenter.shown, <int>[512, 512]);
      },
    );

    test('once_day with a 60 minute cooldown', () async {
      final harness = await _started(<Map<String, Object?>>[_popup(513)]);
      final shown = <bool>[];
      Future<void> visit(Duration after) async {
        harness.clock.advance(after);
        final before = harness.presenter.shown.length;
        harness.engine.screenOpened('product');
        await pumpEventQueue();
        shown.add(harness.presenter.shown.length > before);
        if (harness.presenter.open.containsKey(513)) {
          harness.presenter.close(513);
          await pumpEventQueue();
        }
      }

      await visit(Duration.zero);
      await visit(const Duration(minutes: 30));
      await visit(const Duration(hours: 23) - const Duration(minutes: 30));
      await visit(const Duration(hours: 1));
      expect(shown, <bool>[true, false, false, true]);
    });

    test('every_page: once per screen opening', () async {
      final rules = PopupsV3FrequencyRules(PopupsV3MemoryStorage());
      final popup = PopupV3.tryParse(
        _popup(512, <String, Object?>{'frequency': 'every_page'}),
      )!;
      final now = DateTime(2026, 11, 3);
      expect(await rules.check(popup, now: now, sid: 's'), isNull);
      await rules.record(popup, now: now, sid: 's');
      expect(await rules.check(popup, now: now, sid: 's'), isNotNull);
      rules.newPage();
      expect(await rules.check(popup, now: now, sid: 's'), isNull);

      // app_start с every_page: показ на каждом экране, но раз на экран.
      final harness = EngineHarness(
        server: FakeServer(
          popups: <Map<String, Object?>>[
            _popup(512, <String, Object?>{'frequency': 'every_page'}),
          ],
        ),
      );
      harness.engine.screenOpened('home');
      await harness.engine.start();
      await pumpEventQueue();
      expect(harness.presenter.shown, <int>[512]);
      harness.presenter.close(512);
      await pumpEventQueue();
      await harness.engine.refresh(force: true);
      await pumpEventQueue();
      expect(harness.presenter.shown, <int>[512]);
      harness.engine.screenOpened('product');
      await pumpEventQueue();
      expect(harness.presenter.shown, <int>[512, 512]);

      // track_event с every_page — так же.
      harness.presenter.close(512);
      await pumpEventQueue();
      final events = await _started(<Map<String, Object?>>[
        _popup(515, <String, Object?>{'frequency': 'every_page'}),
      ]);
      events.engine.screenOpened('home');
      events.engine.onTrackEvent('promo_view');
      await pumpEventQueue();
      events.presenter.close(515);
      await pumpEventQueue();
      events.engine.onTrackEvent('promo_view');
      await pumpEventQueue();
      expect(events.presenter.shown, <int>[515]);
      events.engine.screenOpened('product');
      events.engine.onTrackEvent('promo_view');
      await pumpEventQueue();
      expect(events.presenter.shown, <int>[515, 515]);
    });

    test('test mode writes no frequency', () async {
      final popups = <Map<String, Object?>>[
        _popup(512, <String, Object?>{'frequency': 'once_life'}),
      ];
      final first = EngineHarness(server: FakeServer(popups: popups))
        ..engine.testMode = true;
      await first.engine.start();
      await pumpEventQueue();
      expect(first.presenter.shown, <int>[512]);
      expect(first.storage.shows, isEmpty);
      expect(first.server.lists.single.uri.queryParameters['testmode'], 'true');
      first.presenter.close(512);
      await pumpEventQueue();
      final second = first.restart()..engine.testMode = true;
      await second.engine.start();
      await pumpEventQueue();
      expect(second.presenter.shown, <int>[512]);
    });

    test('one modal: the second waits for the first to close', () async {
      final harness = await _started(<Map<String, Object?>>[
        _popup(513),
        _popup(513, <String, Object?>{'id': 613}),
      ]);
      harness.engine.screenOpened('product');
      await pumpEventQueue();
      expect(harness.presenter.shown, <int>[513]);
      expect(harness.engine.queuedIds, <int>[613]);
      harness.presenter.close(513);
      await pumpEventQueue();
      expect(harness.presenter.shown, <int>[513, 613]);
    });

    test('a banner does not wait for the modal', () async {
      final harness = await _started(<Map<String, Object?>>[
        _popup(512),
        _popup(514, <String, Object?>{
          'trigger_type': 'app_start',
          'target_screens': <String>[],
        }),
      ]);
      expect(harness.presenter.shown, unorderedEquals(<int>[512, 514]));
      expect(harness.presenter.open.keys, unorderedEquals(<int>[512, 514]));
    });

    test('no promo code: no show and no show event', () async {
      final promo = popupsV3Fixture('element-promo-code.json');
      final harness = await _started(<Map<String, Object?>>[
        _popup(519, <String, Object?>{'design': promo['design']}),
      ]);
      expect(harness.presenter.shown, isEmpty);
      expect(harness.server.events, isEmpty);
      expect(
        harness.server.requests.last.uri.toString(),
        'https://api.rees46.ru/promo_codes/fetch?shop_id=c1140c8254976de297c3caf971701a&did=DID123&sid=SID123&id=7',
      );
    });

    test('a promo code becomes the promo_code variable', () async {
      final promo = popupsV3Fixture('element-promo-code.json');
      final server = FakeServer(
        popups: <Map<String, Object?>>[
          _popup(519, <String, Object?>{'design': promo['design']}),
        ],
      )..promoCode = 'ABC123';
      final harness = EngineHarness(server: server);
      await harness.engine.start();
      await pumpEventQueue();
      expect(harness.presenter.shown, <int>[519]);
      expect(harness.presenter.variables[519], <String, String>{
        'promo_code': 'ABC123',
      });
    });

    test('a context change refetches the list once per new data', () async {
      final harness = await _started(<Map<String, Object?>>[_popup(513)]);
      expect(harness.server.lists, hasLength(1));
      harness.engine.onContextChanged('profile', 'set', <String, Object?>{
        'email': 'a@b.c',
      });
      harness.clock.advance(const Duration(seconds: 1));
      await pumpEventQueue();
      expect(harness.server.lists, hasLength(1));
      harness.clock.advance(const Duration(seconds: 1));
      await pumpEventQueue();
      expect(harness.server.lists, hasLength(2));
      harness.engine.onContextChanged('profile', 'set', <String, Object?>{
        'email': 'a@b.c',
      });
      harness.clock.advance(const Duration(seconds: 3));
      await pumpEventQueue();
      expect(harness.server.lists, hasLength(2));
      harness.engine.onPurchase();
      harness.clock.advance(const Duration(seconds: 2));
      await pumpEventQueue();
      expect(harness.server.lists, hasLength(3));
    });
  });

  group('list cache', () {
    test('a valid cache is used; an expired one is requested again', () async {
      final harness = await _started(<Map<String, Object?>>[_popup(513)]);
      await harness.engine.refresh();
      expect(harness.server.lists, hasLength(1));
      harness.clock.advance(const Duration(seconds: 301));
      await harness.engine.refresh();
      expect(harness.server.lists, hasLength(2));
    });

    test(
      '4xx is cached as an empty list for 300 s; 5xx is not cached',
      () async {
        final server = FakeServer(popups: <Map<String, Object?>>[_popup(512)])
          ..listReply = (status: 402, body: '{"status":"fail"}');
        final harness = EngineHarness(server: server);
        await harness.engine.start();
        await harness.engine.refresh();
        expect(server.lists, hasLength(1));
        expect(harness.engine.popups, isEmpty);

        harness.clock.advance(const Duration(seconds: 301));
        server.listReply = (status: 503, body: 'down');
        await harness.engine.refresh();
        await harness.engine.refresh();
        expect(server.lists, hasLength(3));

        server.listReply = null;
        await harness.engine.refresh();
        await pumpEventQueue();
        expect(harness.presenter.shown, <int>[512]);
      },
    );

    test('events sent before the list arrives fire once it does', () async {
      final harness = EngineHarness(
        server: FakeServer(popups: <Map<String, Object?>>[_popup(515)]),
      );
      final start = harness.engine.start();
      harness.engine.onTrackEvent('promo_view');
      await start;
      await pumpEventQueue();
      expect(harness.presenter.shown, <int>[515]);
    });

    test('a screen opened before the list arrives still counts', () async {
      final harness = EngineHarness(
        server: FakeServer(popups: <Map<String, Object?>>[_popup(513)]),
      );
      harness.engine.screenOpened('product');
      await harness.engine.start();
      await pumpEventQueue();
      expect(harness.presenter.shown, <int>[513]);
    });

    test('a stopped engine makes no requests', () async {
      final harness = EngineHarness(
        server: FakeServer(popups: <Map<String, Object?>>[_popup(512)]),
      );
      harness.engine.screenOpened('home');
      harness.engine.onTrackEvent('promo_view');
      await harness.engine.refresh();
      await pumpEventQueue();
      expect(harness.server.requests, isEmpty);
    });
  });

  group('automatic presentation', () {
    test('off: triggers are skipped, a manual show is shown', () async {
      final harness = EngineHarness(
        server: FakeServer(popups: <Map<String, Object?>>[_popup(512)]),
      );
      harness.engine.autoPresentation = () => false;
      await harness.engine.start();
      harness.engine.screenOpened('home');
      await pumpEventQueue();
      expect(harness.presenter.shown, isEmpty);
      expect(harness.server.events, isEmpty);
      expect(harness.storage.shows[512], isNull);

      await harness.engine.show(512);
      await pumpEventQueue();
      expect(harness.presenter.shown, <int>[512]);
      expect(harness.server.events, <String>['512:show']);
    });

    test('follows enableAutoPopupPresentation of the init', () async {
      addTearDown(PopupsV3.reset);
      final sdk = PersonalizationSdk(
        api: FakeHostApi(),
        shopId: 'c1140c8254976de297c3caf971701a',
      );
      expect(sdk.popups.engine.autoPresentation(), isTrue);
      await sdk.initialize(
        const SdkInitConfig(
          shopId: 'c1140c8254976de297c3caf971701a',
          enableAutoPopupPresentation: false,
        ),
      );
      expect(sdk.popups.engine.autoPresentation(), isFalse);
      await sdk.initialize(
        const SdkInitConfig(shopId: 'c1140c8254976de297c3caf971701a'),
      );
      expect(sdk.popups.engine.autoPresentation(), isTrue);
    });
  });

  group('slots', () {
    test('a modal waits for an old popup on screen', () async {
      var legacy = true;
      PopupsV3Slots.legacyModal = () => legacy;
      final harness = await _started(<Map<String, Object?>>[
        _popup(512),
        _popup(514, <String, Object?>{
          'trigger_type': 'app_start',
          'target_screens': <String>[],
        }),
      ]);
      expect(harness.presenter.shown, <int>[514]);
      legacy = false;
      PopupsV3Slots.notify();
      await pumpEventQueue();
      expect(harness.presenter.shown, <int>[514, 512]);
      expect(PopupsV3Slots.isTaken(PopupsV3Slots.modal), isTrue);
      harness.presenter.close(512);
      await pumpEventQueue();
      expect(PopupsV3Slots.isTaken(PopupsV3Slots.modal), isFalse);
    });

    test('two shops share the modal slot', () async {
      final first = await _started(<Map<String, Object?>>[_popup(512)]);
      final second = await _started(<Map<String, Object?>>[
        _popup(512, <String, Object?>{'id': 712}),
      ]);
      expect(first.presenter.shown, <int>[512]);
      expect(second.presenter.shown, isEmpty);
      first.presenter.close(512);
      await pumpEventQueue();
      expect(second.presenter.shown, <int>[712]);
    });
  });
}
