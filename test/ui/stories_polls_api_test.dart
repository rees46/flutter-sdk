import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rees46_sdk/rees46_sdk.dart';
import 'package:rees46_sdk/src/pigeon/personalization_api.g.dart' as pigeon;
import 'package:rees46_sdk/src/stories/stories_response.dart';
import 'package:rees46_sdk/src/ui/widgets/stories_api_v3.dart';
import 'package:rees46_sdk/src/ui/widgets/stories_polls_api.dart';

class _FakeHostApi extends pigeon.PersonalizationHostApi {
  String sid = 'sid-1';
  String? did = 'did-1';

  /// `getSid` throws: no session yet.
  bool noSession = false;

  @override
  Future<String?> getDid(String? shopId) async => did;

  @override
  Future<String> getSid(String? shopId) async =>
      noSession ? throw StateError('no session') : sid;
}

/// One request: method, URL and the JSON body.
typedef _Request = ({String method, Uri uri, Map<String, dynamic> body});

StoryPollElement _poll(StoryPollType type, {String channel = ''}) =>
    StoryPollElement(pollType: type, code: 'delivery', channel: channel);

void main() {
  late _FakeHostApi api;
  late PersonalizationSdk sdk;
  late StoriesPollsApi polls;
  late List<_Request> requests;
  late FutureOr<StoriesV3Response> Function() reply;

  setUp(() {
    api = _FakeHostApi();
    sdk = PersonalizationSdk(api: api, shopId: 'shop');
    polls = StoriesPollsApi(sdk, 'app.example');
    requests = <_Request>[];
    reply = () => (status: 200, body: '{"status":"success"}');
    StoriesApiV3.send = (method, uri, body) async {
      requests.add((
        method: method,
        uri: uri,
        body: jsonDecode(body!) as Map<String, dynamic>,
      ));
      return reply();
    };
  });

  group('bodies', () {
    test(
      'a mini poll: the campaign as a number, the slide always a string',
      () {
        expect(
          storyPollAnswerBody(
            optionIds: <int>[2],
            storyId: '5',
            slideId: '101',
          ),
          <String, Object>{
            'option_ids': <int>[2],
            'story_id': 5,
            'slide_id': '101',
          },
        );
        expect(
          storyPollAnswerBody(text: 'Мастер', storyId: '39', slideId: '39_0'),
          <String, Object>{
            'text': 'Мастер',
            'story_id': 39,
            'slide_id': '39_0',
          },
        );
      },
    );

    test('no code and a blank channel go as they are', () {
      expect(
        storyPollReviewBody(
          StoryPollElement(pollType: StoryPollType.nps, code: ''),
          5,
        ),
        <String, Object>{'channel': 'stories', 'category': '', 'rate': 5},
      );
      expect(
        storyPollReviewBody(
          StoryPollElement(pollType: StoryPollType.ces, code: '', channel: ' '),
          5,
        ),
        <String, Object>{'channel': ' ', 'campaign': '', 'rate': 5},
      );
    });

    test('a scale: category for NPS, campaign for CSAT and CES', () {
      expect(storyPollReviewBody(_poll(StoryPollType.nps), 9), <String, Object>{
        'channel': 'stories',
        'category': 'delivery',
        'rate': 9,
      });
      expect(
        storyPollReviewBody(_poll(StoryPollType.csat, channel: 'web'), 1),
        <String, Object>{'channel': 'web', 'campaign': 'delivery', 'rate': 1},
      );
      expect(storyPollReviewBody(_poll(StoryPollType.ces), 7), <String, Object>{
        'channel': 'stories',
        'campaign': 'delivery',
        'rate': 7,
      });
    });
  });

  test(
    'a mini poll answer goes to /mini_polls/{code}/answers with the ids',
    () async {
      reply = () => (
        status: 200,
        body: jsonEncode(<String, dynamic>{
          'status': 'success',
          'payload': <String, dynamic>{
            'answer': <String, dynamic>{
              'id': 77,
              'option_ids': <int>[2],
              'text': null,
            },
            'results': <String, dynamic>{
              'total': 121,
              'options': <Map<String, dynamic>>[
                <String, dynamic>{'id': 1, 'percent': 40},
                <String, dynamic>{'id': 2, 'percent': 60},
              ],
            },
          },
        }),
      );
      final result = await polls.answerMiniPoll(
        'gift recipient/1',
        storyPollAnswerBody(optionIds: <int>[2], storyId: '5', slideId: '101'),
      );
      final request = requests.single;
      expect(request.method, 'POST');
      expect(
        request.uri.toString(),
        'https://app.example/api/v3/polls/mini_polls/gift%20recipient%2F1/answers',
      );
      expect(request.body, <String, dynamic>{
        'shop_id': 'shop',
        'did': 'did-1',
        'sid': 'sid-1',
        'option_ids': <int>[2],
        'story_id': 5,
        'slide_id': '101',
      });
      expect(result.answer!.id, 77);
      expect(result.answer!.optionIds, <int>[2]);
      expect(result.results!.percentOf(2), 60);
    },
  );

  test(
    '200 without an answer; sid always goes, empty without a session',
    () async {
      api.sid = '';
      final result = await polls.answerMiniPoll(
        'x',
        storyPollAnswerBody(text: 'ok', storyId: '5', slideId: '7'),
      );
      expect(result.answer, isNull);
      expect(result.results, isNull);
      expect(requests.single.body['sid'], '');
      api.noSession = true;
      await polls.review(StoryPollType.csat, <String, Object>{'rate': 4});
      expect(requests.last.body['sid'], '');
    },
  );

  test('no code: the request still goes, the server answers', () async {
    reply = () =>
        (status: 404, body: '{"status":"fail","message":"Poll not found"}');
    await expectLater(
      polls.answerMiniPoll('', <String, Object>{'text': 'a'}),
      throwsA(isA<StoriesV3Exception>()),
    );
    expect(requests.single.uri.path, '/api/v3/polls/mini_polls//answers');
  });

  testWidgets('did is awaited like the feed; none in time — an error', (
    tester,
  ) async {
    api.did = null;
    Object? error;
    unawaited(
      polls
          .review(StoryPollType.nps, <String, Object>{'rate': 1})
          .then<void>((_) {}, onError: (Object e) => error = e),
    );
    await tester.pump(const Duration(seconds: 1));
    expect(requests, isEmpty, reason: 'waits for the did');
    api.did = 'did-2';
    await tester.pump(StoriesApiV3.didPoll);
    await tester.pump();
    expect(requests.single.body['did'], 'did-2');
    expect(error, isNull);

    api.did = null;
    unawaited(
      polls
          .review(StoryPollType.nps, <String, Object>{'rate': 1})
          .then<void>((_) {}, onError: (Object e) => error = e),
    );
    await tester.pump(StoriesApiV3.didTimeout + StoriesApiV3.didPoll);
    await tester.pump(StoriesApiV3.didPoll);
    expect(error, isA<TimeoutException>());
    expect(requests, hasLength(1));
  });

  test(
    'any answer object of the reply is the answer, even without ids',
    () async {
      reply = () => (
        status: 200,
        body:
            '{"status":"success","payload":{"answer":{"id":77},"results":null}}',
      );
      final result = await polls.answerMiniPoll('x', <String, Object>{
        'option_ids': <int>[1],
      });
      expect(result.answer!.id, 77);
      expect(result.answer!.optionIds, isNull);
      expect(result.results, isNull);
    },
  );

  test('reviews go to /polls/{kind}/reviews', () async {
    for (final kind in <StoryPollType>[
      StoryPollType.nps,
      StoryPollType.csat,
      StoryPollType.ces,
    ]) {
      await polls.review(kind, storyPollReviewBody(_poll(kind), 3));
    }
    expect(requests.map((request) => request.uri.path), <String>[
      '/api/v3/polls/nps/reviews',
      '/api/v3/polls/csat/reviews',
      '/api/v3/polls/ces/reviews',
    ]);
    expect(requests.first.body, <String, dynamic>{
      'shop_id': 'shop',
      'did': 'did-1',
      'sid': 'sid-1',
      'channel': 'stories',
      'category': 'delivery',
      'rate': 3,
    });
  });

  group('errors', () {
    for (final status in <int>[400, 402, 403, 404, 429, 500, 503]) {
      test('HTTP $status, with its code and message', () async {
        reply = () => (
          status: status,
          body: '{"status":"fail","message":"Payment required"}',
        );
        final error = await polls
            .review(StoryPollType.nps, <String, Object>{'rate': 1})
            .then<Object?>((_) => null, onError: (Object error) => error);
        expect(error, isA<StoriesV3Exception>());
        error as StoriesV3Exception;
        expect(error.status, status);
        expect(error.message, 'HTTP $status: Payment required');
      });
    }

    test('fail or error with 200', () async {
      reply = () => (status: 200, body: '{"status":"fail","message":"Nope"}');
      await expectLater(
        polls.answerMiniPoll('x', <String, Object>{'text': 'a'}),
        throwsA(isA<StoriesV3Exception>()),
      );
      reply = () => (status: 200, body: '{"status":"error"}');
      await expectLater(
        polls.review(StoryPollType.ces, <String, Object>{'rate': 1}),
        throwsA(isA<StoriesV3Exception>()),
      );
    });

    test('only 2xx is a success: a redirect is an error', () async {
      reply = () => (status: 302, body: '{"status":"success"}');
      await expectLater(
        polls.review(StoryPollType.nps, <String, Object>{'rate': 1}),
        throwsA(isA<StoriesV3Exception>()),
      );
    });

    test(
      'the transport logs a failure with its HTTP code and message',
      () async {
        final logs = <String>[];
        final print = debugPrint;
        debugPrint = (message, {wrapWidth}) => logs.add(message ?? '');
        addTearDown(() => debugPrint = print);
        reply = () => (
          status: 429,
          body: '{"status":"fail","message":"Too many requests"}',
        );
        await polls
            .answerMiniPoll('gift', <String, Object>{'text': 'a'})
            .then<void>((_) {}, onError: (Object _) {});
        await polls
            .review(StoryPollType.csat, <String, Object>{'campaign': 'support'})
            .then<void>((_) {}, onError: (Object _) {});
        expect(logs, hasLength(2));
        expect(logs.first, contains('"gift"'));
        expect(logs.last, contains('csat "support"'));
        expect(logs, everyElement(contains('HTTP 429: Too many requests')));
      },
    );

    test('not JSON', () async {
      reply = () => (status: 200, body: '<html>');
      await expectLater(
        polls.answerMiniPoll('x', <String, Object>{'text': 'a'}),
        throwsA(isA<StoriesV3Exception>()),
      );
    });

    test('no network', () async {
      reply = () => throw const SocketException('offline');
      await expectLater(
        polls.answerMiniPoll('x', <String, Object>{'text': 'a'}),
        throwsA(isA<SocketException>()),
      );
    });

    testWidgets('no answer in time', (tester) async {
      reply = () => Completer<StoriesV3Response>().future;
      Object? error;
      unawaited(
        polls
            .review(StoryPollType.nps, <String, Object>{'rate': 1})
            .then<void>((_) {}, onError: (Object e) => error = e),
      );
      await tester.pump(
        StoriesApiV3.requestTimeout - const Duration(seconds: 1),
      );
      expect(error, isNull);
      await tester.pump(const Duration(seconds: 2));
      expect(error, isA<TimeoutException>());
    });
  });
}
