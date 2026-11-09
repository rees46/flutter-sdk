import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:rees46_sdk/src/personalization_sdk.dart';
import 'package:rees46_sdk/src/popups_v3/popups_v3.dart';
import 'package:rees46_sdk/src/popups_v3/popups_v3_api.dart';
import 'package:rees46_sdk/src/ui/widgets/stories_api_v3.dart';

import 'fixtures.dart';
import 'harness.dart';

const PopupsV3Identity _id = (
  shopId: 'c1140c8254976de297c3caf971701a',
  did: 'DID123',
  sid: 'SID123',
);

/// URL из фикстуры: путь и параметры (порядок параметров не важен).
void _expectUrl(Uri actual, Map<String, Object?> request) {
  final expected = Uri.parse(request['url'] as String);
  expect(actual.scheme, expected.scheme);
  expect(actual.host, expected.host);
  expect(actual.path, expected.path);
  expect(actual.queryParameters, expected.queryParameters);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final requests = popupsV3Fixture('requests.json');
  Map<String, Object?> request(String name) =>
      requests[name] as Map<String, Object?>;

  group('requests.json', () {
    test('the list, with test mode and debug', () {
      _expectUrl(PopupsV3Api.listUri('app.rees46.ru', _id), request('list'));
      _expectUrl(
        PopupsV3Api.listUri('app.rees46.ru', _id, testMode: true, debug: true),
        request('list_testmode_debug'),
      );
    });

    test('one popup, with test mode', () {
      _expectUrl(PopupsV3Api.oneUri('app.rees46.ru', 516, _id), request('one'));
      _expectUrl(
        PopupsV3Api.oneUri('app.rees46.ru', 516, _id, testMode: true),
        request('one_testmode'),
      );
    });

    test('events: channel only with subscribe', () {
      _expectUrl(
        PopupsV3Api.eventsUri('app.rees46.ru', 512),
        request('event_show'),
      );
      expect(
        PopupsV3Api.eventBody(_id, PopupV3Event.show, channel: 'email'),
        request('event_show')['json'],
      );
      expect(
        PopupsV3Api.eventBody(_id, PopupV3Event.subscribe, channel: 'email'),
        request('event_subscribe')['json'],
      );
    });

    test('the promo code', () {
      _expectUrl(
        PopupsV3Api.promoUri('api.rees46.ru', _id, '7'),
        request('promo'),
      );
    });

    test('segments/add by did', () async {
      final server = FakeServer();
      await PopupsV3Api(
        send: server.send,
      ).segmentAdd('api.rees46.ru', _id, '123');
      final sent = server.requests.single;
      final expected = request('segment_add');
      expect(sent.method, expected['method']);
      expect(sent.uri.toString(), expected['url']);
      expect(sent.body, containsPair('shop_id', _id.shopId));
      (expected['json_subset'] as Map<String, Object?>).forEach(
        (key, value) => expect(sent.body![key], value, reason: key),
      );
    });

    test(
      'reviews go to /polls/{kind}/reviews with the popup channel',
      () async {
        final host = FakeHostApi();
        final sdk = PersonalizationSdk(api: host, shopId: _id.shopId);
        final sent = <FakeRequest>[];
        final original = StoriesApiV3.send;
        addTearDown(() => StoriesApiV3.send = original);
        StoriesApiV3.send = (method, uri, body) async {
          sent.add((
            method: method,
            uri: uri,
            body: jsonDecode(body!) as Map<String, Object?>,
          ));
          return (status: 200, body: '{"status":"success"}');
        };
        addTearDown(PopupsV3.reset);
        final popups = sdk.popups..appHost = 'https://app.rees46.ru/';
        Map<String, Object> body(String name) => <String, Object>{
          for (final entry
              in (request(name)['json'] as Map<String, Object?>).entries)
            if (!<String>['shop_id', 'did', 'sid'].contains(entry.key))
              entry.key: entry.value!,
        };
        await popups.engine.platform.review('nps', body('review_nps'));
        await popups.engine.platform.review(
          'csat',
          body('review_csat_no_comment'),
        );
        final nps = request('review_nps');
        expect(sent.first.uri.toString(), nps['url']);
        expect(sent.first.body, nps['json']);
        final csat = request('review_csat_no_comment');
        expect(sent.last.uri.toString(), csat['url']);
        expect(sent.last.body, csat['json']);
      },
    );
  });

  group('error-responses.json', () {
    final errors = popupsV3Fixture('error-responses.json');

    test(
      'the list: 4xx is a client error, 5xx and no network are failures',
      () async {
        for (final name in <String>[
          'list_400',
          'list_402',
          'list_403',
          'list_404',
        ]) {
          final status = int.parse(name.substring(5));
          final api = PopupsV3Api(
            send: (method, uri, body) async =>
                (status: status, body: jsonEncode(errors[name])),
          );
          final result = await api.list('app.rees46.ru', _id);
          expect(result.outcome, PopupsV3ListOutcome.clientError, reason: name);
          expect(result.list.popups, isEmpty);
        }
        final down = PopupsV3Api(
          send: (method, uri, body) async => (status: 502, body: 'Bad gateway'),
        );
        expect(
          (await down.list('app.rees46.ru', _id)).outcome,
          PopupsV3ListOutcome.failure,
        );
        final offline = PopupsV3Api(
          send: (method, uri, body) async => throw Exception('offline'),
        );
        expect(
          (await offline.list('app.rees46.ru', _id)).outcome,
          PopupsV3ListOutcome.failure,
        );
      },
    );

    test('one popup: 404 is nothing, with the reason', () async {
      final api = PopupsV3Api(
        send: (method, uri, body) async =>
            (status: 404, body: jsonEncode(errors['one_404'])),
      );
      String? reason;
      expect(
        await api.one(
          'app.rees46.ru',
          1,
          _id,
          onError: (error) => reason = error,
        ),
        isNull,
      );
      expect(reason, contains('Resource not found'));
    });

    test('events: 429 pauses sending for a minute', () async {
      final clock = FakeClock();
      var calls = 0;
      var status = 429;
      final api = PopupsV3Api(
        now: clock.now,
        send: (method, uri, body) async {
          calls++;
          return (status: status, body: jsonEncode(errors['events_429']));
        },
      );
      expect(await api.event('app.rees46.ru', 1, _id, PopupV3Event.show), 429);
      status = 200;
      expect(
        await api.event('app.rees46.ru', 1, _id, PopupV3Event.click),
        isNull,
      );
      expect(calls, 1);
      clock.advance(const Duration(seconds: 61));
      expect(await api.event('app.rees46.ru', 1, _id, PopupV3Event.click), 200);
      expect(calls, 2);
    });

    test('events: one retry on 5xx and no network, none on 4xx', () async {
      final statuses = <int?>[503, 200];
      var calls = 0;
      final api = PopupsV3Api(
        send: (method, uri, body) async {
          calls++;
          final status = statuses.removeAt(0);
          if (status == null) throw Exception('offline');
          return (status: status, body: '{}');
        },
      );
      expect(await api.event('app.rees46.ru', 1, _id, PopupV3Event.show), 200);
      expect(calls, 2);

      calls = 0;
      statuses.addAll(<int?>[null, null]);
      expect(
        await api.event('app.rees46.ru', 1, _id, PopupV3Event.show),
        isNull,
      );
      expect(calls, 2);

      calls = 0;
      statuses.add(400);
      expect(await api.event('app.rees46.ru', 1, _id, PopupV3Event.show), 400);
      expect(calls, 1);
    });

    test(
      'promo codes: 404 is no code; a code is remembered for 2 hours',
      () async {
        final clock = FakeClock();
        var calls = 0;
        var reply = (status: 404, body: jsonEncode(errors['promo_404']));
        final api = PopupsV3Api(
          now: clock.now,
          send: (method, uri, body) async {
            calls++;
            return reply;
          },
        );
        expect(await api.promoCode('api.rees46.ru', _id, '7'), isNull);
        reply = (status: 200, body: jsonEncode(errors['promo_ok']));
        expect(await api.promoCode('api.rees46.ru', _id, '7'), 'ABC123');
        expect(await api.promoCode('api.rees46.ru', _id, '7'), 'ABC123');
        expect(calls, 2);
        clock.advance(const Duration(hours: 2, seconds: 1));
        reply = (status: 200, body: '{"code":"NEW"}');
        expect(await api.promoCode('api.rees46.ru', _id, '7'), 'NEW');
      },
    );
  });
}
