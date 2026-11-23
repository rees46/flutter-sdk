// Stories over API v3 behave as the web SDK does (start slide, viewed, media by type,
// the slide colour, text blocks, header, buttons without a link, promo codes), drawn by
// the kit; the old feed keeps the kit's rules.

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rees46_sdk/rees46_sdk.dart';
import 'package:rees46_sdk/src/pigeon/personalization_api.g.dart' as pigeon;
import 'package:rees46_sdk/src/ui/widgets/stories_api_v3.dart';
import 'package:rees46_sdk/src/v3/personalization_v3.dart';
import 'package:rees46_sdk/src/ui/widgets/stories_seen_store.dart';
import 'package:rees46_sdk/src/ui/widgets/stories_slide_view.dart';
import 'package:rees46_sdk/src/ui/widgets/stories_sound.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String _code = 'block';

class _FakeHostApi extends pigeon.PersonalizationHostApi {
  /// What the old feed through the bridge answers.
  String? bridgeFeed;
  final List<String> bridge = <String>[];
  Map<String, List<String>> seen = <String, List<String>>{};

  @override
  Future<String?> getDid(String? shopId) async => 'did-1';

  @override
  Future<String> getSid(String? shopId) async => 'sid-1';

  @override
  Future<String> legacyGetStories(String code, String? shopId) async =>
      bridgeFeed!;

  @override
  Future<Map<String, List<String>>> getStoriesSeen(String shop) async => seen;

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
  ) async {}
}

Widget _icon(BuildContext context, String asset, double size, Color color) =>
    SizedBox.square(key: ValueKey<String>(asset), dimension: size);

Map<String, dynamic> _story(
  int id,
  List<Map<String, dynamic>> slides, {
  int start = 0,
  bool viewed = false,
}) => <String, dynamic>{
  'id': id,
  'name': 'Story $id',
  'avatar': '',
  'viewed': viewed,
  'start_position': start,
  'slides': slides,
};

/// A slide that runs at once: no media URL, a text naming it.
Map<String, dynamic> _slide(
  String id, {
  String type = 'image',
  String background = '',
  String? color,
  int duration = 1,
  List<Map<String, dynamic>> elements = const <Map<String, dynamic>>[],
}) => <String, dynamic>{
  'id': id,
  'type': type,
  'background': background,
  'background_color': ?color,
  'duration': duration,
  'elements': <Map<String, dynamic>>[
    <String, dynamic>{
      'type': 'text_block',
      'text_input': 'Slide $id',
      'font_size': 20,
      'y_offset': 60,
    },
    ...elements,
  ],
};

Map<String, dynamic> _product(String id) => <String, dynamic>{
  'type': 'product',
  'item': <String, dynamic>{'id': id, 'name': 'Product $id', 'price': 1},
};

void main() {
  late _FakeHostApi api;
  late PersonalizationSdk sdk;
  late List<Map<String, dynamic>> events;
  late List<Map<String, dynamic>> stories;
  late List<String> links;
  late List<String> products;
  late List<String> promos;

  setUp(() {
    StoriesSeenStore.instance = StoriesSeenStore();
    api = _FakeHostApi();
    sdk = PersonalizationSdk(api: api, shopId: 'shop');
    events = <Map<String, dynamic>>[];
    links = <String>[];
    products = <String>[];
    promos = <String>[];
    stories = <Map<String, dynamic>>[];
    StoriesApiV3.domain = 'app.example';
    StoriesApiV3.send = (method, uri, body) async {
      if (method == 'POST') {
        events.add(jsonDecode(body!) as Map<String, dynamic>);
        return (status: 200, body: '{"status":"success"}');
      }
      return (
        status: 200,
        body: jsonEncode(<String, dynamic>{
          'status': 'success',
          'payload': <String, dynamic>{'id': 35, 'stories': stories},
        }),
      );
    };
  });

  tearDown(() => StoriesApiV3.domain = null);

  List<String> sent() => <String>[
    for (final event in events)
      '${event['event']} ${event['story_id']}/${event['slide_id']}',
  ];

  Future<void> bar(WidgetTester tester, {bool v3 = true}) async {
    if (!v3) {
      StoriesApiV3.domain = null;
      api.bridgeFeed = jsonEncode(<String, dynamic>{
        'id': 35,
        'stories': stories,
      });
    }
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 400,
              child: PersonalizationStories(
                code: _code,
                sdk: sdk,
                iconBuilder: _icon,
                onLinkClick: links.add,
                onProductClick: (product) => products.add(product.id),
                onPromoCopied: promos.add,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();
  }

  Future<void> open(WidgetTester tester, String name) async {
    await tester.tap(find.text(name));
    await settle(tester);
  }

  Future<void> close(WidgetTester tester) async {
    Navigator.of(tester.element(find.byType(PersonalizationStoryViewer))).pop();
    await settle(tester);
  }

  PersonalizationStoryCoverState cover(WidgetTester tester, int index) => tester
      .widgetList<PersonalizationStoryPreview>(
        find.byType(PersonalizationStoryPreview),
      )
      .elementAt(index)
      .state;

  group('start slide and viewed, as the web', () {
    testWidgets('a story opens at start_position, not at the first unseen '
        'slide of the device', (tester) async {
      api.seen = <String, List<String>>{
        '1': <String>['11'],
      };
      stories.add(
        _story(1, <Map<String, dynamic>>[
          _slide('10', duration: 30),
          _slide('11', duration: 30),
          _slide('12', duration: 30),
        ], start: 2),
      );
      await bar(tester);
      await open(tester, 'Story 1');
      expect(find.text('Slide 12'), findsOneWidget);
      expect(sent(), <String>['view 1/12']);
    });

    testWidgets('a story left in the middle opens there again; finished — it '
        'is viewed and starts over', (tester) async {
      stories.add(
        _story(1, <Map<String, dynamic>>[
          _slide('10', duration: 30),
          _slide('11', duration: 30),
        ]),
      );
      await bar(tester);
      expect(cover(tester, 0), PersonalizationStoryCoverState.unviewed);
      await open(tester, 'Story 1');
      final viewer = tester.getRect(find.byType(PersonalizationStoryViewer));
      final right = Offset(viewer.right - 10, viewer.center.dy);
      await tester.tapAt(right);
      await tester.pump();
      expect(find.text('Slide 11'), findsOneWidget);
      await close(tester);
      expect(
        cover(tester, 0),
        PersonalizationStoryCoverState.unviewed,
        reason: 'left in the middle',
      );
      await open(tester, 'Story 1');
      expect(find.text('Slide 11'), findsOneWidget, reason: 'where it was');
      await tester.tapAt(right);
      await settle(tester);
      expect(find.byType(PersonalizationStoryViewer), findsNothing);
      expect(cover(tester, 0), PersonalizationStoryCoverState.viewed);
      await open(tester, 'Story 1');
      expect(find.text('Slide 10'), findsOneWidget, reason: 'starts over');
    });

    testWidgets('a swipe to the next story marks the one left viewed', (
      tester,
    ) async {
      stories.addAll(<Map<String, dynamic>>[
        _story(1, <Map<String, dynamic>>[
          _slide('10', duration: 30),
          _slide('11', duration: 30),
        ]),
        _story(2, <Map<String, dynamic>>[_slide('20', duration: 30)]),
        _story(3, <Map<String, dynamic>>[
          _slide('30', duration: 30),
        ], viewed: true),
      ]);
      await bar(tester);
      expect(cover(tester, 2), PersonalizationStoryCoverState.viewed);
      await open(tester, 'Story 1');
      await tester.fling(
        find.byType(PersonalizationStoryViewer),
        const Offset(-500, 0),
        1500,
      );
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.text('Slide 20'), findsOneWidget);
      expect(sent(), <String>['view 1/10', 'view 2/20']);
      await close(tester);
      expect(cover(tester, 0), PersonalizationStoryCoverState.viewed);
      expect(cover(tester, 1), PersonalizationStoryCoverState.unviewed);
      await open(tester, 'Story 1');
      expect(find.text('Slide 10'), findsOneWidget, reason: 'its slide');
    });

    testWidgets('the old feed keeps the first unseen slide', (tester) async {
      api.seen = <String, List<String>>{
        '1': <String>['10'],
      };
      stories.add(
        _story(1, <Map<String, dynamic>>[
          _slide('10', duration: 30),
          _slide('11', duration: 30),
        ]),
      );
      await bar(tester, v3: false);
      await open(tester, 'Story 1');
      expect(find.text('Slide 11'), findsOneWidget);
    });
  });

  group('slides', () {
    // The slide's own box: the nearest coloured box around its [text].
    Color? slideColor(WidgetTester tester, [String text = 'Slide ']) => tester
        .widget<ColoredBox>(
          find
              .ancestor(
                of: find.textContaining(text),
                matching: find.byType(ColoredBox),
              )
              .first,
        )
        .color;

    testWidgets('media by type; a slide without media takes background_color', (
      tester,
    ) async {
      stories.addAll(<Map<String, dynamic>>[
        _story(1, <Map<String, dynamic>>[
          _slide(
            '10',
            type: '',
            background: 'https://cdn.example/a.jpg',
            color: '#112233',
            elements: <Map<String, dynamic>>[_product('p1')],
          ),
        ]),
        _story(2, <Map<String, dynamic>>[_slide('20', color: '#445566')]),
      ]);
      await bar(tester);
      await open(tester, 'Story 1');
      expect(slideColor(tester, 'Product p1'), const Color(0xFF112233));
      expect(
        find.descendant(
          of: find.byType(PersonalizationStoryViewer),
          matching: find.byType(Image),
        ),
        findsNothing,
        reason: 'a product type is no media whatever the background',
      );
      expect(find.text('Retry'), findsNothing);
      await close(tester);
      await open(tester, 'Story 2');
      // An image slide with no URL: media (its letterbox colour), nothing to load.
      expect(slideColor(tester), const Color(0xFF445566));
      expect(find.text('Retry'), findsNothing);
    });

    testWidgets('the old feed keeps the kit card colour', (tester) async {
      stories.add(
        _story(1, <Map<String, dynamic>>[
          _slide('10', type: '', color: '#112233'),
        ]),
      );
      await bar(tester, v3: false);
      await open(tester, 'Story 1');
      expect(slideColor(tester), PersonalizationColors.light.backgroundCard);
    });

    testWidgets('text blocks: the kit body size without font_size, '
        'text_italic and monospace', (tester) async {
      stories.add(
        _story(1, <Map<String, dynamic>>[
          _slide(
            '10',
            elements: <Map<String, dynamic>>[
              <String, dynamic>{
                'type': 'text_block',
                'text_input': 'Plain',
                'text_italic': true,
                'font_type': 'monospace',
                'y_offset': 20,
              },
            ],
          ),
        ]),
      );
      await bar(tester);
      await open(tester, 'Story 1');
      final style = tester.widget<Text>(find.text('Plain')).style!;
      expect(style.fontSize, PersonalizationTypography.baseDefault.fontSize);
      expect(style.fontStyle, FontStyle.italic);
      expect(style.fontFamily, 'monospace');
      await close(tester);

      await bar(tester, v3: false);
      await open(tester, 'Story 1');
      expect(
        tester.widget<Text>(find.text('Plain')).style!.fontSize,
        StoryTextBlockElement.defaultFontSize,
        reason: 'the old feed keeps 14',
      );
    });
  });

  group('the sound button', () {
    Future<void> slide(
      WidgetTester tester, {
      required bool v3,
      required bool hasAudio,
    }) async {
      final story = Story.fromJson(<String, dynamic>{
        'id': 1,
        'name': 'Video',
        'avatar': '',
        'slides': <Map<String, dynamic>>[
          <String, dynamic>{
            'id': '10',
            'type': 'video',
            'background': 'https://cdn.example/v.mp4',
          },
        ],
      });
      await tester.pumpWidget(
        MaterialApp(
          home: StorySlideView(
            story: story,
            slideIndex: 0,
            config: PersonalizationStoryViewer(
              stories: <Story>[story],
              iconBuilder: _icon,
            ),
            live: true,
            v3: v3,
            hasAudio: hasAudio,
          ),
        ),
      );
    }

    final Finder button = find.byType(PersonalizationStorySoundButton);

    testWidgets('the new feed: only for a video with sound', (tester) async {
      await slide(tester, v3: true, hasAudio: false);
      expect(button, findsNothing);
      await slide(tester, v3: true, hasAudio: true);
      expect(button, findsOneWidget);
    });

    testWidgets('the old feed: for every video', (tester) async {
      await slide(tester, v3: false, hasAudio: false);
      expect(button, findsOneWidget);
    });

    testWidgets('the new feed takes the choice saved for its own shop', (
      tester,
    ) async {
      final sound = StoriesSound.instance;
      addTearDown(() => sound.muted.value = true);
      stories.add(_story(1, <Map<String, dynamic>>[_slide('10')]));

      SharedPreferences.setMockInitialValues(<String, Object>{
        StoriesSound.mutedKey('shop'): false,
      });
      await bar(tester);
      await open(tester, 'Story 1');
      expect(sound.muted.value, isFalse, reason: 'saved for this shop');
      await close(tester);

      SharedPreferences.setMockInitialValues(<String, Object>{
        StoriesSound.mutedKey('other'): false,
      });
      await open(tester, 'Story 1');
      expect(
        sound.muted.value,
        isTrue,
        reason: 'nothing saved for this shop: muted, as the web',
      );
    });
  });

  group('taps and events', () {
    testWidgets('the header: drawn, a tap sends click and opens its link', (
      tester,
    ) async {
      stories.add(
        _story(1, <Map<String, dynamic>>[
          _slide(
            '10',
            elements: <Map<String, dynamic>>[
              <String, dynamic>{
                'type': 'header',
                'icon': '',
                'title': 'Brand',
                'subtitle': 'Since 1990',
                'link': 'https://shop.example/brand',
              },
            ],
          ),
        ]),
      );
      await bar(tester);
      await open(tester, 'Story 1');
      expect(find.text('Since 1990'), findsOneWidget);
      await tester.tap(find.text('Brand'));
      await settle(tester);
      expect(sent(), <String>['view 1/10', 'click 1/10']);
      expect(links, <String>['https://shop.example/brand']);
      expect(find.byType(PersonalizationStoryViewer), findsNothing);
    });

    testWidgets('the old feed draws no header', (tester) async {
      stories.add(
        _story(1, <Map<String, dynamic>>[
          _slide(
            '10',
            elements: <Map<String, dynamic>>[
              <String, dynamic>{'type': 'header', 'title': 'Brand'},
            ],
          ),
        ]),
      );
      await bar(tester, v3: false);
      await open(tester, 'Story 1');
      expect(find.text('Brand'), findsNothing);
    });

    testWidgets(
      'a button without a link: click only, also on a product slide',
      (tester) async {
        stories.add(
          _story(1, <Map<String, dynamic>>[
            _slide(
              '10',
              type: '',
              duration: 30,
              elements: <Map<String, dynamic>>[
                _product('p1'),
                <String, dynamic>{'type': 'button', 'title': 'Buy'},
              ],
            ),
          ]),
        );
        await bar(tester);
        await open(tester, 'Story 1');
        await tester.tap(find.text('Buy'));
        await settle(tester);
        expect(sent(), <String>['view 1/10', 'click 1/10']);
        expect(products, isEmpty);
        expect(find.byType(PersonalizationStoryViewer), findsOneWidget);
        await close(tester);

        await bar(tester, v3: false);
        await open(tester, 'Story 1');
        await tester.tap(find.text('Buy'));
        await settle(tester);
        expect(products, <String>['p1'], reason: 'the old feed opens it');
      },
    );

    testWidgets('a product slide without buttons: no More info, as the web', (
      tester,
    ) async {
      stories.add(
        _story(1, <Map<String, dynamic>>[
          _slide(
            '10',
            type: '',
            duration: 30,
            elements: <Map<String, dynamic>>[_product('p1')],
          ),
        ]),
      );
      await bar(tester);
      await open(tester, 'Story 1');
      expect(find.text('Product p1'), findsOneWidget);
      expect(find.text('More info'), findsNothing);
      await close(tester);

      await bar(tester, v3: false);
      await open(tester, 'Story 1');
      expect(
        find.text('More info'),
        findsOneWidget,
        reason: 'the old feed keeps the kit button',
      );
      await tester.tap(find.text('More info'));
      await settle(tester);
      expect(products, <String>['p1']);
    });

    testWidgets('copying a promo code sends no click', (tester) async {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async => null,
      );
      stories.add(
        _story(1, <Map<String, dynamic>>[
          _slide(
            '10',
            duration: 30,
            elements: <Map<String, dynamic>>[
              <String, dynamic>{
                'type': 'text_block',
                'text_input': 'Code',
                'promocode': 'SALE10',
                'y_offset': 20,
              },
            ],
          ),
        ]),
      );
      await bar(tester);
      await open(tester, 'Story 1');
      await tester.tap(find.text('Code'));
      await tester.pump();
      expect(promos, <String>['SALE10']);
      expect(sent(), <String>['view 1/10']);
      await tester.pump(const Duration(seconds: 3));
    });
  });
  group('a slide with no media and no product is skipped, as the web', () {
    Map<String, dynamic> skipped(String id) =>
        _slide(id, type: '', duration: 30, color: '#112233');

    testWidgets('going forward and back passes it, with no view', (
      tester,
    ) async {
      stories.add(
        _story(1, <Map<String, dynamic>>[
          _slide('10', duration: 30),
          skipped('11'),
          _slide('12', duration: 30),
        ]),
      );
      await bar(tester);
      await open(tester, 'Story 1');
      final viewer = tester.getRect(find.byType(PersonalizationStoryViewer));
      await tester.tapAt(Offset(viewer.right - 10, viewer.center.dy));
      await settle(tester);
      expect(find.text('Slide 12'), findsOneWidget);
      await tester.tapAt(Offset(viewer.left + 10, viewer.center.dy));
      await settle(tester);
      expect(find.text('Slide 10'), findsOneWidget);
      expect(sent(), <String>['view 1/10', 'view 1/12', 'view 1/10']);
    });

    testWidgets('a story opens past it; a story of such slides only stays in '
        'the bar, opening it opens the next one and marks it viewed', (
      tester,
    ) async {
      stories.addAll(<Map<String, dynamic>>[
        _story(1, <Map<String, dynamic>>[skipped('10')]),
        _story(2, <Map<String, dynamic>>[
          _slide('20', duration: 30),
          skipped('21'),
          _slide('22', duration: 30),
        ], start: 1),
      ]);
      await bar(tester);
      expect(find.text('Story 1'), findsOneWidget, reason: 'in the bar');
      await open(tester, 'Story 2');
      expect(find.text('Slide 22'), findsOneWidget);
      await close(tester);
      expect(cover(tester, 0), PersonalizationStoryCoverState.unviewed);
      await open(tester, 'Story 1');
      expect(find.text('Slide 22'), findsOneWidget, reason: 'the next story');
      expect(sent(), <String>['view 2/22', 'view 2/22']);
      await close(tester);
      expect(cover(tester, 0), PersonalizationStoryCoverState.viewed);
    });

    testWidgets('the last such story: no viewer at all, it is viewed', (
      tester,
    ) async {
      stories.addAll(<Map<String, dynamic>>[
        _story(1, <Map<String, dynamic>>[_slide('10', duration: 30)]),
        _story(2, <Map<String, dynamic>>[skipped('20'), skipped('21')]),
      ]);
      await bar(tester);
      await open(tester, 'Story 2');
      expect(find.byType(PersonalizationStoryViewer), findsNothing);
      expect(find.byType(PersonalizationStoriesBar), findsOneWidget);
      expect(cover(tester, 1), PersonalizationStoryCoverState.viewed);
      expect(cover(tester, 0), PersonalizationStoryCoverState.unviewed);
      expect(sent(), isEmpty);
    });

    testWidgets('started past its last shown slide: finished, the next story; '
        'the last one closes the viewer', (tester) async {
      stories.addAll(<Map<String, dynamic>>[
        _story(1, <Map<String, dynamic>>[
          _slide('10', duration: 30),
          skipped('11'),
        ], start: 1),
        _story(2, <Map<String, dynamic>>[_slide('20', duration: 30)]),
      ]);
      await bar(tester);
      await open(tester, 'Story 1');
      expect(find.text('Slide 20'), findsOneWidget);
      expect(cover(tester, 0), PersonalizationStoryCoverState.viewed);
      final viewer = tester.getRect(find.byType(PersonalizationStoryViewer));
      await tester.tapAt(Offset(viewer.right - 10, viewer.center.dy));
      await settle(tester);
      expect(find.byType(PersonalizationStoryViewer), findsNothing);
      await open(tester, 'Story 1');
      expect(find.text('Slide 10'), findsOneWidget, reason: 'starts over');
    });

    testWidgets('a swipe onto such a story turns on past it', (tester) async {
      stories.addAll(<Map<String, dynamic>>[
        _story(1, <Map<String, dynamic>>[_slide('10', duration: 30)]),
        _story(2, <Map<String, dynamic>>[skipped('20')]),
        _story(3, <Map<String, dynamic>>[_slide('30', duration: 30)]),
      ]);
      await bar(tester);
      await open(tester, 'Story 1');
      await tester.fling(
        find.byType(PersonalizationStoryViewer),
        const Offset(-500, 0),
        1500,
      );
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.text('Slide 30'), findsOneWidget);
      expect(sent(), <String>['view 1/10', 'view 3/30']);
      await close(tester);
      expect(cover(tester, 1), PersonalizationStoryCoverState.viewed);
    });

    testWidgets('show(): nothing to show — no viewer, no error', (
      tester,
    ) async {
      stories.add(_story(1, <Map<String, dynamic>>[skipped('10')]));
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: Placeholder())),
      );
      final errors = <Object>[];
      var done = false;
      unawaited(
        PersonalizationStories.show(
          tester.element(find.byType(Placeholder)),
          code: _code,
          sdk: sdk,
          onError: errors.add,
        ).then((_) => done = true),
      );
      await settle(tester);
      expect(find.byType(PersonalizationStoryViewer), findsNothing);
      expect(done, isTrue);
      expect(errors, isEmpty);
    });

    group('handleLink', () {
      Future<void> link(WidgetTester tester, String url) async {
        await tester.pumpWidget(
          const MaterialApp(home: Scaffold(body: Placeholder())),
        );
        expect(
          PersonalizationStoriesV3.handleLink(
            tester.element(find.byType(Placeholder)),
            url,
            sdk: sdk,
            iconBuilder: _icon,
          ),
          isTrue,
        );
        await settle(tester);
      }

      testWidgets('a story of such slides only: no viewer, shared_open', (
        tester,
      ) async {
        stories.add(_story(1, <Map<String, dynamic>>[skipped('10')]));
        await link(
          tester,
          'https://shop.example/?r46_stories=$_code&r46_story=1',
        );
        expect(find.byType(PersonalizationStoryViewer), findsNothing);
        expect(sent(), <String>['shared_open 1/10']);
      });

      testWidgets('a link slide that is skipped opens the next shown one', (
        tester,
      ) async {
        stories.add(
          _story(1, <Map<String, dynamic>>[
            _slide('10', duration: 30),
            skipped('11'),
            _slide('12', duration: 30),
          ]),
        );
        await link(
          tester,
          'https://shop.example/?r46_stories=$_code&r46_story=1&r46_slide=11',
        );
        expect(find.text('Slide 12'), findsOneWidget);
        expect(sent(), <String>['view 1/12', 'shared_open 1/12']);
      });
    });

    testWidgets('the old feed shows it', (tester) async {
      stories.add(
        _story(1, <Map<String, dynamic>>[
          _slide('10', duration: 30),
          skipped('11'),
        ]),
      );
      await bar(tester, v3: false);
      await open(tester, 'Story 1');
      final viewer = tester.getRect(find.byType(PersonalizationStoryViewer));
      await tester.tapAt(Offset(viewer.right - 10, viewer.center.dy));
      await settle(tester);
      expect(find.text('Slide 11'), findsOneWidget);
    });
  });
}
