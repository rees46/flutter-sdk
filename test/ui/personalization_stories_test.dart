import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rees46_sdk/rees46_sdk.dart';
import 'package:rees46_sdk/src/pigeon/personalization_api.g.dart' as pigeon;
import 'package:rees46_sdk/src/ui/personalization_ui.dart';
import 'package:rees46_sdk/src/ui/widgets/stories_seen_store.dart';

/// A 1×1 transparent PNG: slides and covers need an image that loads offline.
final ImageProvider _pixel = MemoryImage(
  Uint8List.fromList(const <int>[
    0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, //
    0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, //
    0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00, //
    0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00, //
    0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49, //
    0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82, //
  ]),
);

ImageProvider _offline(String url) => _pixel;

/// An image that never arrives: its slide waits for the readiness timeout.
class _NeverImage extends ImageProvider<_NeverImage> {
  @override
  Future<_NeverImage> obtainKey(ImageConfiguration configuration) =>
      Future<_NeverImage>.value(this);

  @override
  ImageStreamCompleter loadImage(
    _NeverImage key,
    ImageDecoderCallback decode,
  ) => OneFrameImageStreamCompleter(Completer<ImageInfo>().future);
}

/// A product slide (no background: no media to wait for) with numeric id [id].
Map<String, dynamic> _productSlide(
  Object id,
  int product, {
  Object? button,
}) => <String, dynamic>{
  'id': id,
  'duration': 1,
  'type': '',
  'elements': <Map<String, dynamic>>[
    if (button != null) <String, dynamic>{'type': 'button', ...?button as Map?},
    <String, dynamic>{
      'type': 'product',
      'item': <String, dynamic>{
        'id': 'p$product',
        'name': 'Product $product',
        'price': 100,
        'price_formatted': '100 ₽',
        'picture': 'https://cdn.example/p$product.jpg',
        'url': 'https://shop.example/p$product',
      },
    },
  ],
};

/// Story 1: slides 10 and 11; story 2: slide 20. One second each.
String _blockJson({Object slideOne = 10}) => jsonEncode(<String, dynamic>{
  'id': 1,
  'stories': <Map<String, dynamic>>[
    <String, dynamic>{
      'id': 1,
      'name': 'Story 1',
      'avatar': 'https://cdn.example/1.jpg',
      'slides': [_productSlide(slideOne, 1), _productSlide(11, 1)],
    },
    <String, dynamic>{
      'id': 2,
      'name': 'Story 2',
      'avatar': 'https://cdn.example/2.jpg',
      'slides': [_productSlide(20, 2)],
    },
    <String, dynamic>{'id': 3, 'name': 'No slides', 'slides': <Object>[]},
  ],
});

class _FakeHostApi extends pigeon.PersonalizationHostApi {
  _FakeHostApi(this.answer);

  /// What `getStories` answers; `null` — the call fails.
  final String? answer;
  Completer<void>? hold;
  final List<String> views = <String>[];
  final List<String> clicks = <String>[];
  final List<String> stored = <String>[];
  Map<String, List<String>> seen = <String, List<String>>{};

  @override
  Future<String> getStories(String code, String? shopId) async {
    await hold?.future;
    final json = answer;
    if (json == null) throw PlatformException(code: 'get_stories_failed');
    return json;
  }

  @override
  Future<Map<String, List<String>>> getStoriesSeen(String shop) async => seen;

  @override
  Future<void> setStorySlideSeen(
    String shop,
    String storyId,
    String slideId,
  ) async => stored.add('$storyId/$slideId');

  @override
  Future<void> trackStoryView(
    String storyId,
    String slideId,
    String? code,
    String? shopId,
  ) async => views.add('$storyId/$slideId/$code');

  @override
  Future<void> trackStoryClick(
    String storyId,
    String slideId,
    String? code,
    String? shopId,
  ) async => clicks.add('$storyId/$slideId/$code');
}

Widget _host(Widget child) => MaterialApp(
  home: Scaffold(
    body: Align(
      alignment: Alignment.topLeft,
      child: SizedBox(width: 400, child: child),
    ),
  ),
);

PersonalizationStoryPreview _preview(WidgetTester tester, String label) =>
    tester.widget<PersonalizationStoryPreview>(
      find.ancestor(
        of: find.text(label),
        matching: find.byType(PersonalizationStoryPreview),
      ),
    );

/// Taps the cover [label] and lets the viewer route come in.
Future<void> _openStory(WidgetTester tester, String label) async {
  await tester.tap(find.text(label));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pump();
}

/// Lets [time] pass in 100 ms frames: the slide clock takes at most a second per frame,
/// as a real device delivers frames far more often.
Future<void> _wait(WidgetTester tester, Duration time) async {
  for (var left = time; left > Duration.zero; left -= _frame) {
    await tester.pump(left < _frame ? left : _frame);
  }
}

const Duration _frame = Duration(milliseconds: 100);

/// Lets the viewer route go away.
Future<void> _closed(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  setUp(() => StoriesSeenStore.instance = StoriesSeenStore());

  group('PersonalizationStoryViewer', () {
    /// One story: two image slides, a text block on each, products on the first.
    final story = Story.fromJson(<String, dynamic>{
      'id': 7,
      'name': 'Media',
      'avatar': '',
      'slides': <Map<String, dynamic>>[
        for (final id in <int>[70, 71])
          <String, dynamic>{
            'id': id,
            'duration': 5,
            'type': 'image',
            'background': 'https://cdn.example/$id.jpg',
            'elements': <Map<String, dynamic>>[
              <String, dynamic>{
                'type': 'text_block',
                'text_input': 'Slide $id',
                'y_offset': 30,
              },
              if (id == 70)
                <String, dynamic>{
                  'type': 'products',
                  'products': <Map<String, dynamic>>[
                    <String, dynamic>{'id': 'm1', 'name': 'Mouse', 'price': 1},
                  ],
                },
            ],
          },
      ],
    });

    Future<_FakeHostApi> open(
      WidgetTester tester, {
      List<Story>? stories,
      VoidCallback? onClose,
      ValueChanged<String>? onLink,
      void Function(Story story, int slideIndex)? onSlideShown,
    }) async {
      final api = _FakeHostApi(null);
      await tester.pumpWidget(
        MaterialApp(
          home: PersonalizationStoryViewer(
            stories: stories ?? <Story>[story],
            code: 'block',
            sdk: PersonalizationSdk(api: api),
            imageProvider: _offline,
            onClose: onClose ?? () {},
            onLinkClick: onLink,
            onSlideShown: onSlideShown,
          ),
        ),
      );
      await tester.pump();
      // The slide's clock starts once its image is decoded, and decoding needs real
      // async: let it finish, then pump the result in.
      await tester.runAsync(
        () => precacheImage(
          _pixel,
          tester.element(find.byType(PersonalizationStoryViewer)),
        ),
      );
      await tester.pump();
      await tester.pump();
      return api;
    }

    Offset at(WidgetTester tester, double x) {
      final size = tester.getSize(find.byType(PersonalizationStoryViewer));
      return Offset(size.width * x, size.height / 2);
    }

    testWidgets('media slides take the dark tokens in a light app', (
      tester,
    ) async {
      await open(tester);
      final text = tester.widget<Text>(find.text('Slide 70'));
      expect(text.style!.color, PersonalizationColors.dark.textPrimary);
    });

    testWidgets('thirds: back, nothing, next; a hold pauses, never moves', (
      tester,
    ) async {
      final api = await open(tester);
      expect(api.views, <String>['7/70/block']);

      await tester.tapAt(at(tester, 0.5));
      await tester.pump();
      expect(find.text('Slide 70'), findsOneWidget, reason: 'the centre');

      await tester.tapAt(at(tester, 0.8));
      await tester.pump();
      expect(find.text('Slide 71'), findsOneWidget);
      expect(api.views, <String>['7/70/block', '7/71/block']);

      await tester.tapAt(at(tester, 0.1));
      await tester.pump();
      expect(find.text('Slide 70'), findsOneWidget);

      // Held on the right third longer than the slide lasts: still there.
      final hold = await tester.startGesture(at(tester, 0.8));
      await tester.pump(const Duration(milliseconds: 300));
      await _wait(tester, const Duration(seconds: 6));
      expect(find.text('Slide 70'), findsOneWidget);
      await hold.up();
      await tester.pump();
      expect(find.text('Slide 70'), findsOneWidget, reason: 'release stays');
      await _wait(tester, const Duration(seconds: 5));
      await tester.pump();
      expect(find.text('Slide 71'), findsOneWidget);
    });

    testWidgets('back on the first slide restarts it without a new view', (
      tester,
    ) async {
      final shown = <int>[];
      final api = await open(
        tester,
        onSlideShown: (_, index) => shown.add(index),
      );
      expect(shown, <int>[0]);
      await _wait(tester, const Duration(seconds: 3));
      await tester.tapAt(at(tester, 0.1));
      await tester.pump();
      expect(api.views, <String>['7/70/block']);
      expect(shown, <int>[0]);

      // The slide starts over: its five seconds run again.
      await _wait(tester, const Duration(seconds: 4));
      expect(find.text('Slide 70'), findsOneWidget);
      await _wait(tester, const Duration(seconds: 2));
      await tester.pump();
      expect(find.text('Slide 71'), findsOneWidget);
    });

    testWidgets('in the background the clock stands still', (tester) async {
      await open(tester);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await _wait(tester, const Duration(seconds: 30));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(find.text('Slide 70'), findsOneWidget);
      await _wait(tester, const Duration(seconds: 6));
      await tester.pump();
      expect(find.text('Slide 71'), findsOneWidget);
    });

    testWidgets('the readiness timeout stands still in the background', (
      tester,
    ) async {
      final stuck = Story.fromJson(<String, dynamic>{
        'id': 9,
        'name': 'Stuck',
        'avatar': '',
        'slides': <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 90,
            'duration': 5,
            'type': 'image',
            'background': 'https://cdn.example/90.jpg',
            'elements': <Object>[],
          },
        ],
      });
      await tester.pumpWidget(
        MaterialApp(
          home: PersonalizationStoryViewer(
            stories: <Story>[stuck],
            imageProvider: (_) => _NeverImage(),
            onClose: () {},
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 6));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump(const Duration(seconds: 30));
      expect(find.text('Retry'), findsNothing);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump(const Duration(seconds: 3));
      expect(find.text('Retry'), findsNothing, reason: '9 of 10 seconds');
      await tester.pump(const Duration(milliseconds: 1200));
      await tester.pump();
      expect(find.text('Retry'), findsOneWidget);
    });

    testWidgets('the open sheet pauses; a tap outside only closes it', (
      tester,
    ) async {
      await open(tester);
      await tester.tap(find.text('Used products'));
      await tester.pump();
      expect(find.text('Hide products'), findsOneWidget);
      await _wait(tester, const Duration(seconds: 10));
      expect(find.text('Slide 70'), findsOneWidget, reason: 'paused');

      // Above the sheet, on the right third.
      await tester.tapAt(at(tester, 0.9) - const Offset(0, 200));
      await tester.pump();
      expect(find.text('Used products'), findsOneWidget, reason: 'closed');
      expect(find.text('Slide 70'), findsOneWidget, reason: 'no navigation');
    });

    testWidgets('a button without a link only counts the click', (
      tester,
    ) async {
      final buttonStory = Story.fromJson(<String, dynamic>{
        'id': 8,
        'name': 'Button',
        'avatar': '',
        'slides': <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 80,
            'duration': 5,
            'type': 'image',
            'background': 'https://cdn.example/80.jpg',
            'elements': <Map<String, dynamic>>[
              <String, dynamic>{'type': 'button', 'title': 'Nowhere'},
            ],
          },
        ],
      });
      var closed = false;
      final links = <String>[];
      final api = await open(
        tester,
        stories: <Story>[buttonStory],
        onClose: () => closed = true,
        onLink: links.add,
      );
      await tester.tap(find.text('Nowhere'));
      await tester.pump();
      expect(api.clicks, <String>['8/80/block']);
      expect(closed, isFalse);
      expect(links, isEmpty);
      expect(find.text('Nowhere'), findsOneWidget);
    });

    testWidgets('the cross closes the viewer also with the sheet open', (
      tester,
    ) async {
      var closed = 0;
      await open(tester, onClose: () => closed++);
      await tester.tap(find.text('Used products'));
      await tester.pump();

      // The header row beside the cross is outside the sheet: only the sheet goes.
      final header = tester.getTopLeft(
        find.byType(PersonalizationStoryNavigation),
      );
      await tester.tapAt(header + const Offset(40, 30));
      await tester.pump();
      expect(find.text('Used products'), findsOneWidget);
      expect(closed, 0);

      await tester.tap(find.text('Used products'));
      await tester.pump();
      await tester.tap(
        find.descendant(
          of: find.byType(PersonalizationStoryNavigation),
          matching: find.byType(GestureDetector),
        ),
      );
      await tester.pump();
      expect(closed, 1);
    });

    testWidgets(
      'a carousel product closes the viewer even with the sheet open',
      (tester) async {
        final products = <String>[];
        final api = _FakeHostApi(null);
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) => TextButton(
                onPressed: () => Navigator.of(context).push(
                  PersonalizationStoryViewer.route(
                    PersonalizationStoryViewer(
                      stories: <Story>[story],
                      code: 'block',
                      sdk: PersonalizationSdk(api: api),
                      imageProvider: _offline,
                      onProductClick: (product) => products.add(product.id),
                    ),
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        );
        await tester.tap(find.text('open'));
        await _closed(tester);
        await tester.tap(find.text('Used products'));
        await tester.pump();
        await tester.tap(find.text('Mouse'));
        await _closed(tester);
        expect(find.byType(PersonalizationStoryViewer), findsNothing);
        expect(products, <String>['m1']);
        expect(api.clicks, <String>['7/70/block']);
      },
    );
  });

  group('PersonalizationStories', () {
    Future<_FakeHostApi> bar(
      WidgetTester tester, {
      _FakeHostApi? api,
      PersonalizationStoriesController? controller,
      ValueChanged<String>? onLink,
      List<Object>? errors,
      String code = 'block',
    }) async {
      final host = api ?? _FakeHostApi(_blockJson());
      await tester.pumpWidget(
        _host(
          PersonalizationStories(
            code: code,
            sdk: PersonalizationSdk(api: host, shopId: 'shop'),
            controller: controller,
            imageProvider: _offline,
            productButtonText: 'Open',
            onLinkClick: onLink,
            onProductClick: (product) => onLink?.call('product:${product.id}'),
            onError: errors?.add,
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      return host;
    }

    testWidgets('skeletons while loading, hidden when empty', (tester) async {
      final api = _FakeHostApi(jsonEncode(<String, dynamic>{'stories': []}))
        ..hold = Completer<void>();
      await tester.pumpWidget(
        _host(
          PersonalizationStories(
            code: 'block',
            sdk: PersonalizationSdk(api: api),
          ),
        ),
      );
      expect(find.byType(PersonalizationStoryPreview), findsNWidgets(4));
      api.hold!.complete();
      await tester.pump();
      await tester.pump();
      expect(find.byType(PersonalizationStoriesBar), findsNothing);
    });

    testWidgets('errors, a missing code and a slow load reach onError', (
      tester,
    ) async {
      final errors = <Object>[];
      await bar(tester, api: _FakeHostApi(null), errors: errors);
      expect(find.byType(PersonalizationStoriesBar), findsNothing);
      expect(errors.single, isA<PlatformException>());

      errors.clear();
      await bar(tester, errors: errors, code: '');
      expect(errors.single, isA<ArgumentError>());

      errors.clear();
      final slow = _FakeHostApi(_blockJson())..hold = Completer<void>();
      await bar(tester, api: slow, errors: errors);
      expect(find.byType(PersonalizationStoryPreview), findsNWidgets(4));
      await tester.pump(PersonalizationStories.loadTimeout);
      await tester.pump();
      expect(errors.single, isA<TimeoutException>());
      expect(find.byType(PersonalizationStoriesBar), findsNothing);
    });

    testWidgets('seen slides persist, light the ring, pick the start', (
      tester,
    ) async {
      final api = await bar(
        tester,
        api: _FakeHostApi(_blockJson())
          ..seen = <String, List<String>>{
            '1': <String>['11'],
          },
      );
      expect(find.text('No slides'), findsNothing);
      expect(_preview(tester, 'Story 1').seenSegments, <int>{1});

      await _openStory(tester, 'Story 1');
      expect(find.text('Product 1'), findsOneWidget);
      expect(api.views, <String>['1/10/block'], reason: 'the first unseen');
      expect(api.stored, <String>['1/10']);

      // Both slides seen: the story is viewed. Then story 2 plays to the end.
      await _wait(tester, const Duration(seconds: 4));
      await _closed(tester);
      expect(find.byType(PersonalizationStoryViewer), findsNothing);
      expect(api.views, <String>['1/10/block', '1/11/block', '2/20/block']);
      expect(
        _preview(tester, 'Story 1').state,
        PersonalizationStoryCoverState.viewed,
      );
      expect(
        _preview(tester, 'Story 2').state,
        PersonalizationStoryCoverState.viewed,
      );
    });

    testWidgets('a button closes the viewer, then hands over the link', (
      tester,
    ) async {
      final links = <String>[];
      final api = await bar(tester, onLink: links.add);
      await _openStory(tester, 'Story 2');
      await tester.tap(find.text('Open'));
      expect(links, <String>['product:p2']);
      expect(api.clicks, <String>['2/20/block']);
      await _closed(tester);
      expect(find.byType(PersonalizationStoryViewer), findsNothing);
    });

    testWidgets('dynamic slide ids are not tracked', (tester) async {
      final api = await bar(
        tester,
        api: _FakeHostApi(_blockJson(slideOne: '1_0')),
      );
      await _openStory(tester, 'Story 1');
      expect(api.views, isEmpty);
      expect(api.stored, <String>['1/1_0'], reason: 'still seen locally');
    });

    testWidgets('the controller opens a story and pauses it', (tester) async {
      final controller = PersonalizationStoriesController();
      final api = await bar(tester, controller: controller);
      unawaited(controller.openStory('2'));
      await _closed(tester);
      expect(find.text('Product 2'), findsOneWidget);
      controller.pause();
      await _wait(tester, const Duration(seconds: 3));
      expect(find.text('Product 2'), findsOneWidget);
      controller.resume();
      await _wait(tester, const Duration(seconds: 2));
      await _closed(tester);
      expect(find.byType(PersonalizationStoryViewer), findsNothing);
      expect(api.views, <String>['2/20/block']);
    });

    testWidgets('open before the block loads runs after the load', (
      tester,
    ) async {
      final controller = PersonalizationStoriesController();
      final api = _FakeHostApi(_blockJson())..hold = Completer<void>();
      await bar(tester, api: api, controller: controller);
      var done = false;
      unawaited(controller.openStory('2').then((_) => done = true));
      await tester.pump();
      expect(find.byType(PersonalizationStoryViewer), findsNothing);

      api.hold!.complete();
      await tester.pump();
      await _closed(tester);
      expect(find.text('Product 2'), findsOneWidget);
      expect(done, isFalse);
      await _wait(tester, const Duration(seconds: 2));
      await _closed(tester);
      expect(find.byType(PersonalizationStoryViewer), findsNothing);
      expect(done, isTrue);
    });

    testWidgets('open with the viewer open turns to that story inside it', (
      tester,
    ) async {
      final controller = PersonalizationStoriesController();
      final api = await bar(tester, controller: controller);
      var first = false;
      var second = false;
      unawaited(controller.open(0).then((_) => first = true));
      await _closed(tester);
      expect(find.text('Product 1'), findsOneWidget);

      unawaited(controller.openStory('2').then((_) => second = true));
      await _wait(tester, const Duration(milliseconds: 500));
      expect(find.text('Product 2'), findsOneWidget);
      expect(find.byType(PersonalizationStoryViewer), findsOneWidget);
      expect(api.views, <String>['1/10/block', '2/20/block']);
      expect(second, isFalse, reason: 'done when the viewer closes');

      await _wait(tester, const Duration(seconds: 2));
      await _closed(tester);
      expect(find.byType(PersonalizationStoryViewer), findsNothing);
      expect(first, isTrue);
      expect(second, isTrue);
    });

    testWidgets('pause and resume without a viewer do nothing', (tester) async {
      final controller = PersonalizationStoriesController();
      await bar(tester, controller: controller);
      controller.pause();
      unawaited(controller.openStory('2'));
      await _closed(tester);
      expect(find.text('Product 2'), findsOneWidget);
      await _wait(tester, const Duration(seconds: 2));
      await _closed(tester);
      expect(
        find.byType(PersonalizationStoryViewer),
        findsNothing,
        reason: 'the earlier pause did not stick',
      );
    });

    group('without an explicit SDK', () {
      late _FakeHostApi api;

      setUp(() {
        api = _FakeHostApi(_blockJson());
        REES46.debugFactory = (config) =>
            PersonalizationSdk(api: api, shopId: config.shopId);
      });

      tearDown(REES46.reset);

      Future<List<Object>> pumpBar(WidgetTester tester) async {
        final errors = <Object>[];
        await tester.pumpWidget(
          _host(
            PersonalizationStories(
              code: 'block',
              imageProvider: _offline,
              onError: errors.add,
            ),
          ),
        );
        return errors;
      }

      testWidgets('the widget waits for the SDK registration', (tester) async {
        final errors = await pumpBar(tester);
        await tester.pump(const Duration(seconds: 3));
        expect(find.byType(PersonalizationStoryPreview), findsNWidgets(4));

        REES46.initialize(const REES46Config(shopId: 'shop'));
        await tester.pump(const Duration(milliseconds: 200));
        await tester.pump();
        expect(find.text('Story 1'), findsOneWidget);
        expect(errors, isEmpty);
      });

      testWidgets('no registration in 15 s reaches onError', (tester) async {
        final errors = await pumpBar(tester);
        await tester.pump(PersonalizationStories.registrationTimeout);
        await tester.pump(const Duration(milliseconds: 200));
        await tester.pump();
        expect(errors.single, isA<UnknownShopIdException>());
        expect(find.byType(PersonalizationStoriesBar), findsNothing);
      });
    });

    testWidgets('show() opens a block without the bar', (tester) async {
      final api = _FakeHostApi(_blockJson());
      await tester.pumpWidget(_host(const Placeholder()));
      final context = tester.element(find.byType(Placeholder));
      var done = false;
      PersonalizationStories.show(
        context,
        code: 'block',
        sdk: PersonalizationSdk(api: api, shopId: 'shop'),
        startStoryId: '2',
        imageProvider: _offline,
      ).then((_) => done = true);
      await tester.pump();
      await _closed(tester);
      expect(find.text('Product 2'), findsOneWidget);
      await _wait(tester, const Duration(seconds: 2));
      await _closed(tester);
      expect(done, isTrue);
    });
  });
}
