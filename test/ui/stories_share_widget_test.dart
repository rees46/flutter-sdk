import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rees46_sdk/rees46_sdk.dart';
import 'package:rees46_sdk/src/pigeon/personalization_api.g.dart' as pigeon;
import 'package:rees46_sdk/src/v3/personalization_v3.dart';
import 'package:rees46_sdk/src/ui/widgets/stories_api_v3.dart';
import 'package:rees46_sdk/src/ui/widgets/stories_seen_store.dart';

const String _code = 'block';

Map<String, dynamic> _slide(
  String id, {
  bool link = false,
}) => <String, dynamic>{
  'id': id,
  'type': '',
  'background': null,
  'preview': null,
  'duration': 1,
  if (link) 'share_url': 'https://shop.example/?r46_story=40&r46_slide=$id',
  'elements': <Map<String, dynamic>>[
    <String, dynamic>{
      'type': 'product',
      'item': <String, dynamic>{'id': id, 'name': 'Product $id', 'price': 1},
    },
  ],
};

const String _link39 = 'https://shop.example/?r46_story=39';

/// Campaign 39 — product slides with a campaign link; 40 — slides 37, 38 with own links,
/// [start40] is the slide of a link; 41 — sharing off.
String _feed({
  int start40 = 0,
  List<String>? only,
}) => jsonEncode(<String, dynamic>{
  'status': 'success',
  'payload': <String, dynamic>{
    'id': 35,
    'stories':
        <Map<String, dynamic>>[
              <String, dynamic>{
                'id': 39,
                'name': 'Products',
                'avatar': '',
                'share_url': _link39,
                'slides': [_slide('39_0'), _slide('39_1')],
              },
              <String, dynamic>{
                'id': 40,
                'name': 'Media',
                'avatar': '',
                'start_position': start40,
                'slides': [_slide('37', link: true), _slide('38', link: true)],
              },
              <String, dynamic>{
                'id': 41,
                'name': 'Private',
                'avatar': '',
                'shareable': false,
                'share_url': 'https://shop.example/?r46_story=41',
                'slides': [_slide('50', link: true)],
              },
            ]
            .where((story) => only == null || only.contains('${story['id']}'))
            .toList(),
  },
});

class _FakeHostApi extends pigeon.PersonalizationHostApi {
  final List<String> bridge = <String>[];
  final List<String> sources = <String>[];
  final List<String> shared = <String>[];
  final List<Rect> anchors = <Rect>[];

  /// The open share sheet: completing it closes the sheet.
  Completer<void>? sheet;

  /// What the old-API feed through the bridge answers; `null` — it must not be asked.
  String? bridgeFeed;

  @override
  Future<String?> getDid(String? shopId) async => 'did-1';

  @override
  Future<String> getStories(String code, String? shopId) async =>
      bridgeFeed ?? (throw StateError('the bridge feed is off with API v3'));

  @override
  Future<Map<String, List<String>>> getStoriesSeen(String shop) async =>
      <String, List<String>>{};

  @override
  Future<void> setStorySlideSeen(
    String shop,
    String story,
    String slide,
  ) async {}

  @override
  Future<void> trackStoryView(
    String storyId,
    String slideId,
    String? code,
    String? shopId,
  ) async => bridge.add('view $storyId/$slideId');

  @override
  Future<void> trackStoryClick(
    String storyId,
    String slideId,
    String? code,
    String? shopId,
  ) async => bridge.add('click $storyId/$slideId');

  @override
  Future<void> trackSetSource(
    pigeon.TrackingSourceWire source,
    String? shopId,
  ) async => sources.add('${source.type}/${source.code}');

  @override
  Future<void> shareUrl(
    String url,
    double anchorX,
    double anchorY,
    double anchorWidth,
    double anchorHeight,
  ) {
    shared.add(url);
    anchors.add(Rect.fromLTWH(anchorX, anchorY, anchorWidth, anchorHeight));
    return (sheet = Completer<void>()).future;
  }
}

/// API v3 in memory: GET answers [answer], POST is an event.
class _Server {
  _Server(this.answer);

  StoriesV3Response Function(Uri uri) answer;
  final List<String> gets = <String>[];
  final List<String> events = <String>[];

  /// Hosts of all requests, in order.
  final List<String> hosts = <String>[];

  Future<StoriesV3Response> send(String method, Uri uri, String? body) async {
    hosts.add(uri.host);
    if (method == 'POST') {
      final event = jsonDecode(body!) as Map<String, dynamic>;
      expect(uri.path, '/api/v3/storefront/stories/$_code/events');
      expect(event['shop_id'], 'shop');
      expect(event['did'], 'did-1');
      events.add('${event['event']} ${event['story_id']}/${event['slide_id']}');
      return (status: 200, body: '{"status":"success"}');
    }
    gets.add('${uri.path}?${uri.query}');
    return answer(uri);
  }
}

Widget _icon(BuildContext context, String asset, double size, Color color) =>
    SizedBox.square(key: ValueKey<String>(asset), dimension: size);

final Finder _share = find.byKey(
  const ValueKey<String>(PersonalizationIcons.share),
);
final Finder _cross = find.byKey(
  const ValueKey<String>(PersonalizationIcons.cross),
);

Widget _host(Widget child) => MaterialApp(
  home: Scaffold(
    body: Align(
      alignment: Alignment.topLeft,
      child: SizedBox(width: 400, child: child),
    ),
  ),
);

/// Lets [time] pass in 100 ms frames.
Future<void> _wait(WidgetTester tester, Duration time) async {
  const frame = Duration(milliseconds: 100);
  for (var left = time; left > Duration.zero; left -= frame) {
    await tester.pump(left < frame ? left : frame);
  }
}

/// Lets a viewer route come in or go away.
Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pump();
}

void main() {
  late _FakeHostApi api;
  late _Server server;
  late PersonalizationSdk sdk;

  setUp(() {
    StoriesSeenStore.instance = StoriesSeenStore();
    api = _FakeHostApi();
    server = _Server((_) => (status: 200, body: _feed()));
    sdk = PersonalizationSdk(api: api, shopId: 'shop');
    StoriesApiV3.domain = 'app.example';
    StoriesApiV3.send = server.send;
  });

  tearDown(() => StoriesApiV3.domain = null);

  Future<void> bar(WidgetTester tester) async {
    await tester.pumpWidget(
      _host(PersonalizationStories(code: _code, sdk: sdk, iconBuilder: _icon)),
    );
    await tester.pump();
    await tester.pump();
  }

  Future<void> open(WidgetTester tester, String label) async {
    await tester.tap(find.text(label));
    await _settle(tester);
  }

  testWidgets('the feed and the events go to v3, also for product slides', (
    tester,
  ) async {
    await bar(tester);
    expect(server.gets, <String>[
      '/api/v3/storefront/stories/$_code?shop_id=shop&did=did-1',
    ]);
    await open(tester, 'Products');
    expect(find.text('Product 39_0'), findsOneWidget);
    expect(server.events, <String>['view 39/39_0']);
    expect(api.bridge, isEmpty, reason: 'nothing through the old tracking');
    expect(api.sources, <String>['stories/$_code']);
  });

  testWidgets('share: the campaign link, a pause until the sheet closes', (
    tester,
  ) async {
    await bar(tester);
    await open(tester, 'Products');
    // Left of the cross, 8 apart, the same 32 box.
    final share = tester.getRect(_share);
    final cross = tester.getRect(_cross);
    expect(share.size, const Size(32, 32));
    expect(cross.left - share.right, 8);
    expect(share.top, cross.top);

    await tester.tap(_share);
    await tester.pump();
    expect(api.shared, <String>['$_link39&r46_slide=39_0']);
    expect(api.anchors.single, share);
    expect(server.events, <String>['view 39/39_0', 'share 39/39_0']);
    await tester.tap(_share);
    expect(api.shared, hasLength(1), reason: 'one sheet at a time');

    await _wait(tester, const Duration(seconds: 3));
    expect(find.text('Product 39_0'), findsOneWidget, reason: 'paused');
    api.sheet!.complete();
    await _wait(tester, const Duration(milliseconds: 1100));
    expect(find.text('Product 39_1'), findsOneWidget, reason: 'goes on');
  });

  testWidgets('shareUrlTransform changes the shared link, not the event', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        PersonalizationStoriesV3(
          shareUrlTransform: (url) =>
              url.replaceFirst('https://', 'demoapp://'),
          child: PersonalizationStories(
            code: _code,
            sdk: sdk,
            iconBuilder: _icon,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    await open(tester, 'Products');
    await tester.tap(_share);
    await tester.pump();
    expect(api.shared, <String>[
      'demoapp://shop.example/?r46_story=39&r46_slide=39_0',
    ]);
    expect(server.events, <String>['view 39/39_0', 'share 39/39_0']);
  });

  testWidgets('a hold on the button does not hold the slide', (tester) async {
    await bar(tester);
    await open(tester, 'Products');
    final gesture = await tester.startGesture(tester.getCenter(_share));
    await _wait(tester, const Duration(milliseconds: 1500));
    expect(find.text('Product 39_1'), findsOneWidget, reason: 'no hold pause');
    await gesture.up();
    await tester.pump();
    expect(api.shared, <String>[
      '$_link39&r46_slide=39_1',
    ], reason: 'a long press is a press, on the slide it is on');
  });

  testWidgets('own slide links; no button when sharing is off', (tester) async {
    await bar(tester);
    await open(tester, 'Private');
    expect(find.text('Product 50'), findsOneWidget);
    expect(_share, findsNothing);
    expect(_cross, findsOneWidget);
    Navigator.of(tester.element(_cross)).pop();
    await _settle(tester);

    await open(tester, 'Media');
    await tester.tap(_share);
    await tester.pump();
    expect(api.shared, <String>[
      'https://shop.example/?r46_story=40&r46_slide=37',
    ]);
  });

  testWidgets('the own value wins over the global one', (tester) async {
    StoriesApiV3.domain = 'global.example';
    await tester.pumpWidget(
      _host(
        PersonalizationStoriesV3(
          apiV3Domain: 'own.example',
          child: PersonalizationStories(
            code: _code,
            sdk: sdk,
            iconBuilder: _icon,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    await open(tester, 'Products');
    await tester.tap(_share);
    await tester.pump();
    expect(server.events, <String>['view 39/39_0', 'share 39/39_0']);
    expect(server.hosts.toSet(), <String>{'own.example'});
  });

  testWidgets('a block without a value takes the old API next to a v3 one', (
    tester,
  ) async {
    StoriesApiV3.domain = null;
    // The old feed with links: the old API never sends them, and still no button.
    api.bridgeFeed = jsonEncode(
      (jsonDecode(_feed(only: <String>['40'])) as Map)['payload'],
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 400,
            child: Column(
              children: <Widget>[
                PersonalizationStories(
                  code: _code,
                  sdk: sdk,
                  iconBuilder: _icon,
                ),
                PersonalizationStoriesV3(
                  apiV3Domain: 'own.example',
                  child: PersonalizationStories(
                    code: _code,
                    sdk: sdk,
                    iconBuilder: _icon,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(server.gets, hasLength(1), reason: 'only the second block');
    expect(find.text('Media'), findsNWidgets(2));
    expect(find.text('Products'), findsOneWidget);

    await tester.tap(find.text('Media').first);
    await _settle(tester);
    expect(find.text('Product 37'), findsOneWidget);
    expect(_share, findsNothing, reason: 'the old API has no sharing');
    expect(api.bridge, <String>['view 40/37']);
    expect(server.events, isEmpty);
    Navigator.of(tester.element(_cross)).pop();
    await _settle(tester);

    await tester.tap(find.text('Products'));
    await _settle(tester);
    expect(_share, findsOneWidget);
    expect(server.events, <String>['view 39/39_0']);
    expect(api.bridge, <String>['view 40/37']);
  });

  group('handleLink', () {
    const link =
        'https://demo.example/promo?utm=1&r46_stories=$_code'
        '&r46_story=40&r46_slide=38';

    BuildContext placeholder(WidgetTester tester) =>
        tester.element(find.byType(Placeholder));

    testWidgets('false for other links and without apiV3Domain', (
      tester,
    ) async {
      await tester.pumpWidget(_host(const Placeholder()));
      final context = placeholder(tester);
      expect(
        PersonalizationStoriesV3.handleLink(
          context,
          'https://shop.example/',
          sdk: sdk,
        ),
        isFalse,
      );
      expect(
        PersonalizationStoriesV3.handleLink(
          context,
          '?r46_stories=$_code',
          sdk: sdk,
        ),
        isFalse,
      );
      StoriesApiV3.domain = null;
      expect(
        PersonalizationStoriesV3.handleLink(context, link, sdk: sdk),
        isFalse,
      );
      await tester.pump();
      expect(server.gets, isEmpty);
    });

    testWidgets('its own apiV3Domain without the global one', (tester) async {
      StoriesApiV3.domain = null;
      server.answer = (_) =>
          (status: 200, body: _feed(start40: 1, only: <String>['40']));
      await tester.pumpWidget(_host(const Placeholder()));
      expect(
        PersonalizationStoriesV3.handleLink(
          placeholder(tester),
          link,
          sdk: sdk,
          apiV3Domain: 'own.example',
          iconBuilder: _icon,
          shareUrlTransform: (url) =>
              url.replaceFirst('https://', 'demoapp://'),
        ),
        isTrue,
      );
      await _settle(tester);
      expect(find.text('Product 38'), findsOneWidget);
      expect(server.events, <String>['view 40/38', 'shared_open 40/38']);
      expect(server.hosts.toSet(), <String>{'own.example'});
      // handleLink hands its transform to the viewer.
      await tester.tap(_share);
      await tester.pump();
      expect(api.shared, <String>[
        'demoapp://shop.example/?r46_story=40&r46_slide=38',
      ]);
      Navigator.of(
        tester.element(find.byType(PersonalizationStoryViewer)),
      ).pop();
      await _settle(tester);
    });

    testWidgets('opens the campaign at the link slide, shared_open once', (
      tester,
    ) async {
      server.answer = (_) =>
          (status: 200, body: _feed(start40: 1, only: <String>['40']));
      await tester.pumpWidget(_host(const Placeholder()));
      final context = placeholder(tester);
      expect(
        PersonalizationStoriesV3.handleLink(
          context,
          link,
          sdk: sdk,
          iconBuilder: _icon,
        ),
        isTrue,
      );
      await _settle(tester);
      expect(server.gets, <String>[
        '/api/v3/storefront/stories/$_code/story/40'
            '?shop_id=shop&did=did-1&slide_id=38',
      ]);
      expect(find.text('Product 38'), findsOneWidget, reason: 'start_position');
      expect(server.events, <String>['view 40/38', 'shared_open 40/38']);

      // The same link while its viewer is open: nothing new.
      expect(
        PersonalizationStoriesV3.handleLink(context, link, sdk: sdk),
        isTrue,
      );
      await _settle(tester);
      expect(server.gets, hasLength(1));

      await _wait(tester, const Duration(milliseconds: 1100));
      await _settle(tester);
      expect(find.byType(PersonalizationStoryViewer), findsNothing);
      expect(
        server.events.where((e) => e.startsWith('shared_open')),
        hasLength(1),
      );

      expect(
        PersonalizationStoriesV3.handleLink(context, link, sdk: sdk),
        isTrue,
      );
      await _settle(tester);
      expect(server.gets, hasLength(2), reason: 'closed: the link opens again');
    });

    testWidgets('a product campaign opens at the link slide, though the server '
        'starts at the first', (tester) async {
      // The server does not know virtual slides: `slide_id=39_1` still answers
      // `start_position: 0`.
      server.answer = (_) => (status: 200, body: _feed(only: <String>['39']));
      await tester.pumpWidget(_host(const Placeholder()));
      expect(
        PersonalizationStoriesV3.handleLink(
          placeholder(tester),
          'demoapp://demo.example/?r46_stories=$_code&r46_story=39'
          '&r46_slide=39_1',
          sdk: sdk,
          iconBuilder: _icon,
        ),
        isTrue,
      );
      await _settle(tester);
      expect(find.text('Product 39_1'), findsOneWidget);
      expect(server.events, <String>['view 39/39_1', 'shared_open 39/39_1']);
      // Its "Share" carries the slide again.
      await tester.tap(_share);
      await tester.pump();
      expect(api.shared, <String>['$_link39&r46_slide=39_1']);
    });

    testWidgets('a link slide missing from the answer — start_position', (
      tester,
    ) async {
      server.answer = (_) =>
          (status: 200, body: _feed(start40: 1, only: <String>['40']));
      await tester.pumpWidget(_host(const Placeholder()));
      expect(
        PersonalizationStoriesV3.handleLink(
          placeholder(tester),
          'https://demo.example/?r46_stories=$_code&r46_story=40&r46_slide=99',
          sdk: sdk,
          iconBuilder: _icon,
        ),
        isTrue,
      );
      await _settle(tester);
      expect(find.text('Product 38'), findsOneWidget);
      expect(server.events, <String>['view 40/38', 'shared_open 40/38']);
    });

    testWidgets('a failed load reaches onError and shows nothing', (
      tester,
    ) async {
      server.answer = (_) => (
        status: 404,
        body: '{"status":"fail","message":"Resource not found"}',
      );
      await tester.pumpWidget(_host(const Placeholder()));
      final errors = <Object>[];
      expect(
        PersonalizationStoriesV3.handleLink(
          placeholder(tester),
          link,
          sdk: sdk,
          onError: errors.add,
        ),
        isTrue,
      );
      await _settle(tester);
      expect(errors.single, isA<StoriesV3Exception>());
      expect(find.byType(PersonalizationStoryViewer), findsNothing);
      expect(server.events, isEmpty);
    });

    testWidgets('closes the open viewer before showing its campaign', (
      tester,
    ) async {
      await bar(tester);
      await open(tester, 'Products');
      expect(find.text('Product 39_0'), findsOneWidget);
      server.answer = (_) =>
          (status: 200, body: _feed(start40: 1, only: <String>['40']));
      expect(
        PersonalizationStoriesV3.handleLink(
          tester.element(find.byType(PersonalizationStories)),
          link,
          sdk: sdk,
        ),
        isTrue,
      );
      await _settle(tester);
      expect(find.byType(PersonalizationStoryViewer), findsOneWidget);
      expect(find.text('Product 38'), findsOneWidget);
      expect(find.text('Product 39_0'), findsNothing);
    });
  });
}
