import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:rees46_sdk/src/ui/personalization_ui.dart';
import 'package:rees46_sdk/src/ui/widgets/stories_api_v3.dart';
import 'package:rees46_sdk/src/ui/widgets/stories_share.dart';

const String _code = 'block';

/// A product element of a v3 product slide.
Map<String, dynamic> _product(String id) => <String, dynamic>{
  'type': 'product',
  'item': <String, dynamic>{'id': id, 'name': 'Product $id', 'price': 1},
};

/// A v3 product slide: `background` and `preview` are JSON `null`, no own link.
Map<String, dynamic> _productSlide(String id) => <String, dynamic>{
  'id': id,
  'type': '',
  'background': null,
  'preview': null,
  'duration': 1,
  'elements': <Map<String, dynamic>>[_product(id)],
};

/// A v3 media-free slide with its own link.
Map<String, dynamic> _linkedSlide(
  int id, {
  int story = 40,
}) => <String, dynamic>{
  'id': id,
  'type': '',
  'duration': 1,
  'share_url':
      'https://shop.example/?r46_stories=$_code&r46_story=$story&r46_slide=$id',
  'elements': <Map<String, dynamic>>[_product('$id')],
};

/// Campaign 39 — products `39_0`, `39_1`, a campaign link only; campaign 40 — slides 37,
/// 38 with own links; campaign 41 — sharing off.
Map<String, dynamic> _feed({
  int start40 = 0,
  List<int>? only,
}) => <String, dynamic>{
  'status': 'success',
  'payload': <String, dynamic>{
    'id': 35,
    'settings': <String, dynamic>{'avatar_size': 54},
    'stories': <Map<String, dynamic>>[
      <String, dynamic>{
        'id': 39,
        'name': 'Products',
        'avatar': '',
        'shareable': true,
        'share_url': 'https://shop.example/?r46_stories=$_code&r46_story=39',
        'slides': [_productSlide('39_0'), _productSlide('39_1')],
      },
      <String, dynamic>{
        'id': 40,
        'name': 'Media',
        'avatar': '',
        'start_position': start40,
        'share_url': 'https://shop.example/?r46_stories=$_code&r46_story=40',
        'slides': [_linkedSlide(37), _linkedSlide(38)],
      },
      <String, dynamic>{
        'id': 41,
        'name': 'Private',
        'avatar': '',
        'shareable': false,
        'share_url': 'https://shop.example/?r46_story=41',
        'slides': [_linkedSlide(50, story: 41)],
      },
    ].where((story) => only == null || only.contains(story['id'])).toList(),
  },
};

void main() {
  group('parseStoriesShareLink', () {
    test('reads block, campaign and slide', () {
      expect(
        parseStoriesShareLink(
          'https://shop.test/?utm_source=tg&r46_stories=main&r46_story=5&r46_slide=10',
        ),
        const StoriesShareLink(code: 'main', storyId: '5', slideId: '10'),
      );
    });

    test('accepts links without a slide and virtual slides', () {
      expect(
        parseStoriesShareLink('?r46_stories=main&r46_story=5'),
        const StoriesShareLink(code: 'main', storyId: '5'),
      );
      expect(
        parseStoriesShareLink(
          'https://shop.test/promo?r46_stories=main&r46_story=5&r46_slide=5_2',
        )?.slideId,
        '5_2',
      );
    });

    test('ignores other pages and broken links', () {
      expect(parseStoriesShareLink(''), isNull);
      expect(parseStoriesShareLink('https://shop.test/'), isNull);
      expect(parseStoriesShareLink('?r46_story=5'), isNull);
      expect(parseStoriesShareLink('?r46_stories=&r46_story=5'), isNull);
      expect(parseStoriesShareLink('?r46_stories=main&r46_story=abc'), isNull);
      expect(
        parseStoriesShareLink('?r46_stories=main&r46_story=12345678901'),
        isNull,
      );
      expect(parseStoriesShareLink('?r46_stories=main&r46_story=%zz'), isNull);
      final broken = parseStoriesShareLink(
        '?r46_stories=main&r46_story=5&r46_slide=1;DROP',
      );
      expect(broken?.storyId, '5', reason: 'the campaign still opens');
      expect(broken?.slideId, isNull);
    });
  });

  group('storySlideShareUrl', () {
    final story = Story.fromJson(<String, dynamic>{
      'id': 5,
      'shareable': true,
      'share_url': 'https://shop.test/?r46_story=5',
      'slides': [
        <String, dynamic>{
          'id': 1,
          'share_url': 'https://shop.test/?r46_slide=1',
        },
        <String, dynamic>{'id': '5_0'},
      ],
    });

    test('prefers the slide link, falls back to the campaign link', () {
      expect(
        storySlideShareUrl(story, story.slides[0]),
        'https://shop.test/?r46_slide=1',
      );
      expect(
        storySlideShareUrl(story, story.slides[1]),
        'https://shop.test/?r46_story=5',
      );
    });

    test('nothing when sharing is off or the link is not http(s)', () {
      Story make(Map<String, dynamic> json) => Story.fromJson(<String, dynamic>{
        ...json,
        'slides': [
          <String, dynamic>{'id': 1},
        ],
      });
      final off = make(<String, dynamic>{
        'shareable': false,
        'share_url': 'https://shop.test/',
      });
      expect(storySlideShareUrl(off, off.slides.single), isNull);
      final none = make(<String, dynamic>{});
      expect(storySlideShareUrl(none, none.slides.single), isNull);
      final script = make(<String, dynamic>{
        'share_url': 'javascript:alert(1)',
      });
      expect(storySlideShareUrl(script, script.slides.single), isNull);
      final upper = make(<String, dynamic>{'share_url': 'HTTPS://shop.test/'});
      expect(
        storySlideShareUrl(upper, upper.slides.single),
        'HTTPS://shop.test/',
      );
    });
  });

  group('StoriesApiV3', () {
    tearDown(() => StoriesApiV3.domain = null);

    test('reads the payload of the wrapper like the old feed', () {
      final block = StoriesApiV3.parseResponse((
        status: 200,
        body: jsonEncode(_feed()),
      ));
      expect(block.id, '35');
      expect(block.stories.map((story) => story.id), <String>[
        '39',
        '40',
        '41',
      ]);
      final products = block.stories.first;
      expect(products.shareable, isTrue);
      expect(products.shareUrl, contains('r46_story=39'));
      final slide = products.slides.first;
      expect(slide.id, '39_0');
      expect(slide.background, '', reason: 'JSON null is empty, not "null"');
      expect(slide.preview, '');
      expect(slide.shareUrl, '');
      expect(block.stories[1].shareable, isTrue, reason: 'missing — allowed');
      expect(block.stories[1].slides.first.shareUrl, contains('r46_slide=37'));
      expect(block.stories[2].shareable, isFalse);
    });

    test('a failure, an HTTP error or HTML is a load error', () {
      expect(
        () => StoriesApiV3.parseResponse((
          status: 200,
          body: '{"status":"fail","message":"Client not found"}',
        )),
        throwsA(isA<StoriesV3Exception>()),
      );
      expect(
        () => StoriesApiV3.parseResponse((
          status: 404,
          body: '{"status":"fail","message":"Resource not found"}',
        )),
        throwsA(isA<StoriesV3Exception>()),
      );
      expect(
        () => StoriesApiV3.parseResponse((
          status: 404,
          body: '<html>Not found</html>',
        )),
        throwsA(isA<StoriesV3Exception>()),
      );
      expect(
        () => StoriesApiV3.parseResponse((status: 200, body: '<html>')),
        throwsA(isA<StoriesV3Exception>()),
      );
    });

    test('the event: the campaign id a number, the slide id a string', () {
      expect(
        StoriesApiV3.eventBody(
          shopId: 'shop',
          did: 'did',
          event: StoriesV3Event.sharedOpen,
          storyId: '40',
          slideId: '37',
        ),
        <String, Object>{
          'shop_id': 'shop',
          'did': 'did',
          'event': 'shared_open',
          'story_id': 40,
          'slide_id': '37',
        },
      );
      final virtual = StoriesApiV3.eventBody(
        shopId: 'shop',
        did: 'did',
        event: StoriesV3Event.view,
        storyId: '39',
        slideId: '39_0',
      );
      expect(virtual['story_id'], 39);
      expect(virtual['slide_id'], '39_0');
    });

    test('addresses go to the v3 host, the scheme is optional', () {
      expect(
        StoriesApiV3.uri(
          'app.rees46.ru',
          <String>['a b', 'story', '40'],
          <String, String>{'shop_id': 's', 'did': 'd', 'slide_id': '37'},
        ).toString(),
        'https://app.rees46.ru/api/v3/storefront/stories/a%20b/story/40'
        '?shop_id=s&did=d&slide_id=37',
      );
      expect(
        StoriesApiV3.uri(StoriesApiV3.host('https://app.rees46.ru/')!, <String>[
          'b',
          'events',
        ], const <String, String>{}).toString(),
        'https://app.rees46.ru/api/v3/storefront/stories/b/events',
      );
    });

    test('the own host wins over the global one, empty turns v3 off', () {
      expect(StoriesApiV3.host(null), isNull);
      expect(StoriesApiV3.host('own.example'), 'own.example');
      StoriesApiV3.domain = 'global.example';
      expect(StoriesApiV3.host(null), 'global.example');
      expect(StoriesApiV3.host('own.example'), 'own.example');
      expect(StoriesApiV3.host(''), isNull);
      expect(StoriesApiV3.host(' '), isNull);
    });
  });
}
