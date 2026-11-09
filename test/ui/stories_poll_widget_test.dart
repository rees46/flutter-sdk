import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rees46_sdk/rees46_sdk.dart';
import 'package:rees46_sdk/src/pigeon/personalization_api.g.dart' as pigeon;
import 'package:rees46_sdk/src/ui/components/personalization_story_poll.dart';
import 'package:rees46_sdk/src/v3/personalization_v3.dart';
import 'package:rees46_sdk/src/ui/widgets/stories_api_v3.dart';
import 'package:rees46_sdk/src/ui/widgets/stories_poll.dart';
import 'package:rees46_sdk/src/ui/widgets/stories_seen_store.dart';

/// A transport answering by hand: each request waits in [pending].
class _Transport implements StoryPollsTransport {
  final List<Map<String, Object>> bodies = <Map<String, Object>>[];
  final List<Completer<StoryPollReply>> pending = <Completer<StoryPollReply>>[];

  Future<StoryPollReply> _wait(Map<String, Object> body) {
    bodies.add(body);
    final completer = Completer<StoryPollReply>();
    pending.add(completer);
    return completer.future;
  }

  @override
  Future<StoryPollReply> answerMiniPoll(
    String code,
    Map<String, Object> body,
  ) => _wait(body);

  @override
  Future<StoryPollReply> review(StoryPollType kind, Map<String, Object> body) =>
      _wait(body);
}

const List<Map<String, dynamic>> _options = <Map<String, dynamic>>[
  <String, dynamic>{'id': 1, 'label': 'Себе'},
  <String, dynamic>{'id': 2, 'label': 'Маме'},
  <String, dynamic>{'id': 3, 'label': 'Папе'},
];

Map<String, dynamic> _poll(
  String type, {
  String? kind,
  Object? yOffset = 50,
  bool allowReanswer = false,
  Map<String, dynamic>? answer,
  Map<String, dynamic>? results,
  Map<String, dynamic>? labels,
  int? maxLength,
  Map<String, dynamic> fields = const <String, dynamic>{},
}) => <String, dynamic>{
  'type': 'poll',
  'poll_type': type,
  'y_offset': yOffset,
  'allow_reanswer': allowReanswer,
  'labels': labels,
  'poll': <String, dynamic>{
    'code': 'code_$type${kind ?? ''}',
    'kind': kind,
    'question': 'Q $type ${kind ?? ''}'.trim(),
    'max_length': maxLength,
    'thanks_text': 'Спасибо!',
    'show_results': true,
    'options': _options,
    'bands': <Map<String, dynamic>>[
      <String, dynamic>{'from': 0, 'to': 10, 'success': 'Band thanks'},
    ],
    ...fields,
  },
  'answer': answer,
  'results': results,
};

/// A slide without media (it runs at once) with a text block naming it.
Map<String, dynamic> _slide(
  String id, [
  List<Map<String, dynamic>> elements = const <Map<String, dynamic>>[],
]) => <String, dynamic>{
  'id': id,
  'type': 'image',
  'background': '',
  'duration': 1,
  'elements': <Map<String, dynamic>>[
    <String, dynamic>{
      'type': 'text_block',
      'text_input': 'Slide $id',
      'y_offset': 20,
    },
    ...elements,
  ],
};

List<Story> _stories(List<List<Map<String, dynamic>>> stories) =>
    StoriesBlock.fromJson(<String, dynamic>{
      'id': 1,
      'stories': <Map<String, dynamic>>[
        for (final (index, slides) in stories.indexed)
          <String, dynamic>{
            'id': index + 1,
            'name': 'Story ${index + 1}',
            'avatar': '',
            'slides': slides,
          },
      ],
    }).stories;

Widget _icon(BuildContext context, String asset, double size, Color color) =>
    SizedBox.square(key: ValueKey<String>(asset), dimension: size);

/// Lets [time] pass in 100 ms frames.
Future<void> _wait(WidgetTester tester, Duration time) async {
  const frame = Duration(milliseconds: 100);
  for (var left = time; left > Duration.zero; left -= frame) {
    await tester.pump(left < frame ? left : frame);
  }
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pump();
}

/// A reply reaches the card: its future, then the frame.
Future<void> _replied(WidgetTester tester) async {
  await tester.pump();
  await tester.pump();
}

/// The phone: 402 × 874.
const Size _screen = Size(402, 874);

void main() {
  late _Transport transport;
  late StreamController<int> requests;

  setUp(() {
    StoryPollStore.instance = StoryPollStore();
    transport = _Transport();
    requests = StreamController<int>.broadcast();
  });

  tearDown(() => requests.close());

  /// Opens the viewer over a route without Scaffold (no Material), like the SDK does;
  /// [own] — with the test transport.
  Future<void> open(
    WidgetTester tester,
    List<Story> stories, {
    String? apiV3Domain = 'app.example',
    bool own = true,
  }) async {
    tester.view
      ..physicalSize = _screen * 3
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Center(
            child: GestureDetector(
              onTap: () => Navigator.of(context).push(
                PersonalizationStoryViewer.route(
                  PersonalizationStoriesV3(
                    apiV3Domain: apiV3Domain,
                    pollsTransport: own ? transport : null,
                    pollErrorText: 'Ошибка',
                    child: PersonalizationStoryViewer(
                      stories: stories,
                      storyRequests: requests.stream,
                      iconBuilder: _icon,
                    ),
                  ),
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await _settle(tester);
  }

  Future<void> close(WidgetTester tester) async {
    Navigator.of(tester.element(find.text('open'))).pop();
    await _settle(tester);
  }

  final Finder card = find.byType(PersonalizationStoryPoll);

  final single = _poll('mini_poll', kind: 'single_choice');

  testWidgets('the viewer: its own transport draws the card also without API '
      'v3, no transport and no SDK — none; no Material needed', (tester) async {
    final stories = _stories(<List<Map<String, dynamic>>>[
      <Map<String, dynamic>>[
        _slide('1', <Map<String, dynamic>>[single]),
      ],
    ]);
    await open(tester, stories, own: false);
    expect(find.text('Slide 1'), findsOneWidget);
    expect(card, findsNothing, reason: 'API v3 without an SDK: no HTTP');
    await close(tester);
    await open(tester, stories, apiV3Domain: '');
    expect(card, findsOneWidget, reason: 'its own transport');
    await close(tester);
    await open(tester, stories);
    expect(card, findsOneWidget);
    expect(find.text('Q mini_poll single_choice'), findsOneWidget);
    // y_offset 50 of the slide, 12 from the edges, centred.
    final rect = tester.getRect(card);
    expect(rect.top, _screen.height / 2);
    expect((rect.left, rect.right), (12, _screen.width - 12));
  });

  testWidgets('taps, holds and swipes on the card stay on it', (tester) async {
    await open(
      tester,
      _stories(<List<Map<String, dynamic>>>[
        <Map<String, dynamic>>[
          _slide('1', <Map<String, dynamic>>[single]),
          _slide('2'),
        ],
        <Map<String, dynamic>>[_slide('3')],
      ]),
    );
    final question = find.text('Q mini_poll single_choice');
    // The right third over the card does not go forward.
    await tester.tapAt(
      Offset(_screen.width - 30, tester.getCenter(question).dy),
    );
    await tester.pump();
    expect(find.text('Slide 1'), findsOneWidget);
    // Swipes neither turn the story nor close the viewer.
    await tester.dragFrom(tester.getCenter(question), const Offset(-300, 0));
    await _settle(tester);
    expect(find.text('Slide 1'), findsOneWidget);
    await tester.dragFrom(tester.getCenter(question), const Offset(0, 400));
    await _settle(tester);
    expect(find.text('Slide 1'), findsOneWidget);
    // A hold pauses the slide; a long press on an option is still a press.
    final gesture = await tester.startGesture(
      tester.getCenter(find.text('Маме')),
    );
    await _wait(tester, const Duration(milliseconds: 1500));
    expect(find.text('Slide 1'), findsOneWidget);
    await gesture.up();
    await tester.pump();
    expect(transport.bodies.single['option_ids'], <int>[2]);
    // Sending holds it too.
    await _wait(tester, const Duration(milliseconds: 1500));
    expect(find.text('Slide 1'), findsOneWidget);
    transport.pending.single.complete(const StoryPollReply());
    await _replied(tester);
    expect(find.text('Спасибо!'), findsOneWidget);
    await _wait(tester, const Duration(milliseconds: 1100));
    expect(find.text('Slide 2'), findsOneWidget, reason: 'goes on after');
    // Outside the card the right third goes forward.
    await tester.tapAt(Offset(_screen.width - 30, 150));
    await _settle(tester);
    expect(find.text('Slide 3'), findsOneWidget);
  });

  testWidgets(
    'the poll pause goes away with the campaign; a late reply is kept',
    (tester) async {
      final stories = _stories(<List<Map<String, dynamic>>>[
        <Map<String, dynamic>>[
          _slide('1', <Map<String, dynamic>>[single]),
        ],
        <Map<String, dynamic>>[_slide('3'), _slide('4')],
      ]);
      await open(tester, stories);
      await tester.tap(find.text('Себе'));
      await tester.pump();
      expect(
        transport.pending,
        hasLength(1),
        reason: 'sending holds the slide',
      );
      requests.add(1);
      await tester.pump();
      await _settle(tester);
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Slide 3'), findsOneWidget);
      await _wait(tester, const Duration(milliseconds: 1100));
      expect(
        find.text('Slide 4'),
        findsOneWidget,
        reason: 'not held by the poll',
      );
      transport.pending.single.complete(
        const StoryPollReply(answer: StoryPollAnswer(optionIds: <int>[1])),
      );
      await tester.pump();
      await close(tester);
      await open(tester, stories);
      expect(
        find.text('Спасибо!'),
        findsOneWidget,
        reason: 'the store kept it',
      );
      expect(transport.bodies, hasLength(1));
    },
  );

  group('text', () {
    final text = _poll('mini_poll', kind: 'text', maxLength: 10);
    final stories = _stories(<List<Map<String, dynamic>>>[
      <Map<String, dynamic>>[
        _slide('1', <Map<String, dynamic>>[text]),
        _slide('2'),
      ],
    ]);
    const keyboard = 336.0;

    Future<void> showKeyboard(WidgetTester tester) async {
      tester.view.viewInsets = const FakeViewPadding(bottom: keyboard * 3);
      addTearDown(tester.view.resetViewInsets);
      await tester.pump();
    }

    testWidgets(
      'keyboard: the card above it, the slide stays; limit, error, retry',
      (tester) async {
        await open(tester, stories);
        final slideText = tester.getRect(find.text('Slide 1'));
        final down = tester.getRect(card);
        await tester.tap(find.byType(TextField));
        await tester.pump();
        await showKeyboard(tester);
        final up = tester.getRect(card);
        expect(up.bottom, _screen.height - keyboard - 16);
        expect(up.size, down.size);
        expect(
          tester.getRect(find.text('Slide 1')),
          slideText,
          reason: 'not resized',
        );
        // Focused — the slide waits.
        await _wait(tester, const Duration(milliseconds: 1500));
        expect(find.text('Slide 1'), findsOneWidget);

        expect(find.text('0/10'), findsOneWidget);
        await tester.enterText(find.byType(TextField), ' Мастер и Маргарита ');
        await tester.pump();
        expect(find.text('10/10'), findsOneWidget);
        expect(find.text(' Мастер и '), findsOneWidget);
        await tester.tap(find.text('Send'));
        await tester.pump();
        expect(transport.bodies.single['text'], 'Мастер и');

        transport.pending.single.completeError(Exception('HTTP 429'));
        await _replied(tester);
        expect(find.text('Ошибка'), findsOneWidget);
        expect(find.byType(TextField), findsOneWidget);
        await tester.tap(find.text('Send'));
        await tester.pump();
        expect(transport.bodies, hasLength(2));
        expect(find.text('Ошибка'), findsNothing);
        transport.pending.last.complete(
          const StoryPollReply(answer: StoryPollAnswer(text: 'Мастер и')),
        );
        await _replied(tester);
        expect(find.text('Спасибо!'), findsOneWidget);
        expect(find.text('Мастер и'), findsOneWidget);
        expect(find.byType(TextField), findsNothing);
        tester.view.resetViewInsets();
        await tester.pump();
        expect(tester.getRect(card).top, down.top, reason: 'back in place');
        await _wait(tester, const Duration(milliseconds: 1100));
        expect(find.text('Slide 2'), findsOneWidget, reason: 'goes on');
      },
    );

    testWidgets('a tap past the card with the keyboard only hides it', (
      tester,
    ) async {
      await open(tester, stories);
      await tester.tap(find.byType(TextField));
      await tester.pump();
      await showKeyboard(tester);
      expect(FocusManager.instance.primaryFocus?.debugLabel, 'story poll');
      await tester.tapAt(Offset(_screen.width - 30, 150));
      await tester.pump();
      expect(find.text('Slide 1'), findsOneWidget, reason: 'no step forward');
      expect(
        FocusManager.instance.primaryFocus?.debugLabel,
        isNot('story poll'),
      );
      tester.view.resetViewInsets();
      await tester.pump();
      await _wait(tester, const Duration(milliseconds: 1100));
      expect(find.text('Slide 2'), findsOneWidget, reason: 'resumed');
    });
  });

  testWidgets(
    'the system hides the keyboard (back): the field lets go, the slide goes on',
    (tester) async {
      await open(
        tester,
        _stories(<List<Map<String, dynamic>>>[
          <Map<String, dynamic>>[
            _slide('1', <Map<String, dynamic>>[
              _poll('mini_poll', kind: 'text', maxLength: 10),
            ]),
            _slide('2'),
          ],
        ]),
      );
      await tester.tap(find.byType(TextField));
      await tester.pump();
      tester.view.viewInsets = const FakeViewPadding(bottom: 336 * 3);
      addTearDown(tester.view.resetViewInsets);
      await tester.pump();
      expect(FocusManager.instance.primaryFocus?.debugLabel, 'story poll');
      // «Назад» прячет клавиатуру мимо приложения: остаётся только отступ 0.
      tester.view.resetViewInsets();
      await tester.pump();
      await tester.pump();
      expect(
        FocusManager.instance.primaryFocus?.debugLabel,
        isNot('story poll'),
      );
      expect(find.text('Slide 1'), findsOneWidget);
      await _wait(tester, const Duration(milliseconds: 1100));
      expect(find.text('Slide 2'), findsOneWidget, reason: 'not held');
    },
  );

  testWidgets('a hardware keyboard (no inset) keeps the focus', (tester) async {
    await open(
      tester,
      _stories(<List<Map<String, dynamic>>>[
        <Map<String, dynamic>>[
          _slide('1', <Map<String, dynamic>>[
            _poll('mini_poll', kind: 'text', maxLength: 10),
          ]),
          _slide('2'),
        ],
      ]),
    );
    await tester.tap(find.byType(TextField));
    await tester.pump();
    await _wait(tester, const Duration(milliseconds: 1500));
    expect(FocusManager.instance.primaryFocus?.debugLabel, 'story poll');
    expect(find.text('Slide 1'), findsOneWidget, reason: 'held while focused');
  });

  testWidgets('answered from the feed: bars, percents, re-answer from labels', (
    tester,
  ) async {
    await open(
      tester,
      _stories(<List<Map<String, dynamic>>>[
        <Map<String, dynamic>>[
          _slide('1', <Map<String, dynamic>>[
            _poll(
              'mini_poll',
              kind: 'single_choice',
              allowReanswer: true,
              labels: <String, dynamic>{'reanswer': 'Ответить заново'},
              answer: <String, dynamic>{
                'option_ids': <int>[2],
              },
              results: <String, dynamic>{
                'total': 120,
                'options': <Map<String, dynamic>>[
                  <String, dynamic>{'id': 1, 'percent': 40},
                  <String, dynamic>{'id': 2, 'percent': 60},
                ],
              },
            ),
          ]),
        ],
      ]),
    );
    await tester.pump(const Duration(milliseconds: 700));
    expect(find.text('40%'), findsOneWidget);
    expect(find.text('60%'), findsOneWidget);
    expect(find.text('0%'), findsOneWidget);
    expect(find.text('Спасибо!'), findsOneWidget);
    await tester.tap(find.text('Ответить заново'));
    await tester.pump();
    expect(find.text('60%'), findsNothing);
    expect(find.text('Ответить заново'), findsNothing);
    await tester.tap(find.text('Себе'));
    await tester.pump();
    expect(transport.bodies.single['option_ids'], <int>[1]);
  });

  testWidgets(
    'a product slide has its card; NPS sends a rate, shows its band',
    (tester) async {
      await open(
        tester,
        _stories(<List<Map<String, dynamic>>>[
          <Map<String, dynamic>>[
            <String, dynamic>{
              'id': '39_0',
              'type': '',
              'duration': 1,
              'elements': <Map<String, dynamic>>[
                <String, dynamic>{
                  'type': 'product',
                  'item': <String, dynamic>{
                    'id': 'p1',
                    'name': 'Product 1',
                    'price': 1,
                  },
                },
                _poll('nps', yOffset: '30'),
              ],
            },
          ],
        ]),
      );
      expect(find.text('Product 1'), findsOneWidget);
      expect(find.text('Q nps'), findsOneWidget);
      for (var rate = 0; rate <= 10; rate++) {
        expect(
          find.descendant(of: card, matching: find.text('$rate')),
          findsOneWidget,
        );
      }
      await tester.tap(find.descendant(of: card, matching: find.text('9')));
      await tester.pump();
      expect(transport.bodies.single, <String, Object>{
        'channel': 'stories',
        'category': 'code_nps',
        'rate': 9,
      });
      transport.pending.single.complete(const StoryPollReply());
      await _replied(tester);
      expect(find.text('Band thanks'), findsOneWidget);
    },
  );

  testWidgets('RTL: the scale and the result bars mirror', (tester) async {
    Widget poll(Map<String, dynamic> json) => MaterialApp(
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Center(
          child: SizedBox(
            width: 370,
            child: PersonalizationStoryPoll(
              key: ValueKey<Object?>(json['poll_type']),
              poll: StoryPollElement.tryParse(json)!,
              storyId: '1',
              slideId: '1',
              transport: transport,
            ),
          ),
        ),
      ),
    );
    await tester.pumpWidget(poll(_poll('nps')));
    expect(
      tester.getCenter(find.text('0')).dx,
      greaterThan(tester.getCenter(find.text('10')).dx),
    );
    await tester.pumpWidget(
      poll(
        _poll(
          'mini_poll',
          kind: 'single_choice',
          answer: <String, dynamic>{
            'option_ids': <int>[1],
          },
          results: <String, dynamic>{
            'options': <Map<String, dynamic>>[
              <String, dynamic>{'id': 1, 'percent': 50},
            ],
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    final row = tester.getRect(
      find.ancestor(of: find.text('Себе'), matching: find.byType(Stack)).first,
    );
    final bar = tester.getRect(
      find
          .descendant(
            of: find
                .ancestor(of: find.text('Себе'), matching: find.byType(Stack))
                .first,
            matching: find.byType(ColoredBox),
          )
          .first,
    );
    expect(
      bar.right,
      row.right,
      reason: 'grows from the start — the right in RTL',
    );
    expect(bar.width, closeTo(row.width / 2, 1));
    expect(
      tester.getCenter(find.text('50%')).dx,
      lessThan(tester.getCenter(find.text('Себе')).dx),
    );
  });

  /// The card alone, as wide as on a phone slide.
  Widget alone(
    Map<String, dynamic> json, {
    StoryPollTexts texts = const StoryPollTexts(),
  }) => MaterialApp(
    home: Center(
      child: SizedBox(
        width: 370,
        child: PersonalizationStoryPoll(
          key: UniqueKey(),
          poll: StoryPollElement.tryParse(json)!,
          storyId: '1',
          slideId: '1',
          transport: transport,
          texts: texts,
        ),
      ),
    ),
  );

  testWidgets('the submit label: submit_label > labels.submit > host > Send', (
    tester,
  ) async {
    await tester.pumpWidget(alone(_poll('mini_poll', kind: 'multiple_choice')));
    await tester.tap(find.text('Send'));
    await tester.pump();
    expect(transport.bodies, isEmpty, reason: 'off while nothing is chosen');
    await tester.tap(find.text('Папе'));
    await tester.tap(find.text('Себе'));
    await tester.pump();
    await tester.tap(find.text('Send'));
    await tester.pump();
    expect(transport.bodies.single['option_ids'], <int>[1, 3]);

    const host = StoryPollTexts(submit: 'Go');
    await tester.pumpWidget(
      alone(_poll('mini_poll', kind: 'multiple_choice'), texts: host),
    );
    expect(find.text('Go'), findsOneWidget);
    await tester.pumpWidget(
      alone(
        _poll(
          'mini_poll',
          kind: 'multiple_choice',
          labels: <String, dynamic>{'submit': 'Отправить'},
        ),
        texts: host,
      ),
    );
    expect(find.text('Отправить'), findsOneWidget);
    await tester.pumpWidget(
      alone(
        _poll(
          'mini_poll',
          kind: 'text',
          labels: <String, dynamic>{'submit': 'Отправить'},
          fields: <String, dynamic>{'submit_label': 'Готово'},
        ),
        texts: host,
      ),
    );
    expect(find.text('Готово'), findsOneWidget);
  });

  testWidgets(
    'text without max_length: no counter, no limit; the placeholder',
    (tester) async {
      await tester.pumpWidget(
        alone(
          _poll(
            'mini_poll',
            kind: 'text',
            fields: <String, dynamic>{'placeholder': 'Ваш ответ'},
          ),
        ),
      );
      expect(find.text('Ваш ответ'), findsOneWidget);
      expect(find.textContaining('/'), findsNothing);
      final long = 'а' * 300;
      await tester.enterText(find.byType(TextField), long);
      await tester.pump();
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        long,
      );
      expect(find.textContaining('/'), findsNothing);
    },
  );

  testWidgets('answered: percents rounded; no options array — no percents', (
    tester,
  ) async {
    Map<String, dynamic> answered(Object? options) => _poll(
      'mini_poll',
      kind: 'single_choice',
      answer: <String, dynamic>{
        'option_ids': <int>[2],
      },
      results: <String, dynamic>{'total': 3, 'options': options},
    );
    await tester.pumpWidget(
      alone(
        answered(<Map<String, dynamic>>[
          <String, dynamic>{'id': 1, 'percent': 40.5},
          <String, dynamic>{'id': 2, 'percent': '59.4'},
        ]),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('41%'), findsOneWidget);
    expect(find.text('59%'), findsOneWidget);
    expect(find.text('0%'), findsOneWidget, reason: 'not in the results');
    await tester.pumpWidget(alone(answered(null)));
    await tester.pumpAndSettle();
    expect(find.textContaining('%'), findsNothing);
    expect(find.text('Спасибо!'), findsOneWidget);
  });

  group('the view', () {
    Map<String, dynamic> answered({
      String thanks = '',
      int total = 1248,
      String kind = 'single_choice',
    }) => _poll(
      'mini_poll',
      kind: kind,
      answer: <String, dynamic>{
        'option_ids': <int>[2],
      },
      results: <String, dynamic>{
        'total': total,
        'options': <Map<String, dynamic>>[
          <String, dynamic>{'id': 1, 'percent': 52},
          <String, dynamic>{'id': 2, 'percent': 31},
          <String, dynamic>{'id': 3, 'percent': 17},
        ],
      },
      fields: <String, dynamic>{'thanks_text': thanks},
    );

    testWidgets('an answered choice: the results header, my answer checked, '
        '«Thank you! Vote counted» and the votes', (tester) async {
      await tester.pumpWidget(alone(answered()));
      await tester.pumpAndSettle();
      expect(find.text('RESULTS'), findsOneWidget);
      expect(find.text('A'), findsOneWidget);
      expect(find.text('B'), findsNothing, reason: 'a check instead');
      expect(find.text('C'), findsOneWidget);
      expect(find.text('Thank you! Vote counted'), findsOneWidget);
      expect(find.text('1,248 votes'), findsOneWidget);
      // The header is above the question, the votes on the right of the thanks.
      final question = tester.getRect(find.text('Q mini_poll single_choice'));
      expect(
        tester.getRect(find.text('RESULTS')).bottom,
        lessThan(question.top),
      );
      expect(
        tester.getRect(find.text('1,248 votes')).right,
        tester.getRect(card).right - 20,
      );

      // Its own thanks replaces the pair; no total — no votes.
      await tester.pumpWidget(
        alone(answered(thanks: 'Спасибо за ответ!', total: 0)),
      );
      await tester.pumpAndSettle();
      expect(find.text('Спасибо за ответ!'), findsOneWidget);
      expect(find.text('Thank you! Vote counted'), findsNothing);
      expect(find.textContaining('vote'), findsNothing);

      await tester.pumpWidget(alone(answered(kind: 'multiple_choice')));
      await tester.pumpAndSettle();
      expect(find.text('RESULTS'), findsOneWidget);
    });

    testWidgets('the results texts follow the device language', (tester) async {
      tester.platformDispatcher.localeTestValue = const Locale('ru', 'RU');
      addTearDown(tester.platformDispatcher.clearLocaleTestValue);
      await tester.pumpWidget(alone(answered(total: 21)));
      await tester.pumpAndSettle();
      expect(find.text('РЕЗУЛЬТАТЫ'), findsOneWidget);
      expect(find.text('Спасибо! Голос учтён'), findsOneWidget);
      expect(find.text('21 голос'), findsOneWidget);
    });

    testWidgets('no results header in a form, on a scale or a text', (
      tester,
    ) async {
      for (final json in <Map<String, dynamic>>[
        _poll('mini_poll', kind: 'single_choice'),
        _poll('mini_poll', kind: 'multiple_choice'),
        _poll('nps', answer: <String, dynamic>{'rate': 9}),
        _poll(
          'mini_poll',
          kind: 'text',
          answer: <String, dynamic>{'text': 'x'},
        ),
      ]) {
        await tester.pumpWidget(alone(json));
        await tester.pumpAndSettle();
        expect(find.text('RESULTS'), findsNothing, reason: '$json');
        expect(find.textContaining('Vote counted'), findsNothing);
      }
      await tester.pumpWidget(alone(_poll('mini_poll', kind: 'single_choice')));
      expect(
        <String>['A', 'B', 'C'].map((letter) => find.text(letter)),
        everyElement(findsOneWidget),
      );
    });

    testWidgets('sizes: left-aligned text, rows 56 and 8 apart, the track, '
        'the field and the button 52', (tester) async {
      await tester.pumpWidget(alone(_poll('mini_poll', kind: 'single_choice')));
      final box = tester.getRect(card);
      expect(
        tester.getRect(find.text('Q mini_poll single_choice')).left,
        box.left + 20,
      );
      Rect row(String label) => tester.getRect(
        find
            .ancestor(of: find.text(label), matching: find.byType(Container))
            .first,
      );
      expect(row('Себе').height, 56);
      expect(row('Маме').top - row('Себе').bottom, 8);
      expect(
        tester.getRect(find.text('Себе')).left,
        box.left + 20 + 12 + 32 + 12,
        reason: 'the letter square and its gaps',
      );

      await tester.pumpWidget(alone(_poll('nps')));
      final track = find
          .ancestor(of: find.text('0'), matching: find.byType(Container))
          .first;
      expect(tester.getSize(track).height, 52);
      expect(tester.getRect(track).width, box.width - 40);

      await tester.pumpWidget(alone(_poll('mini_poll', kind: 'text')));
      expect(
        tester
            .getSize(
              find
                  .ancestor(
                    of: find.byType(TextField),
                    matching: find.byType(Container),
                  )
                  .first,
            )
            .height,
        greaterThanOrEqualTo(52),
      );
      expect(
        tester
            .getSize(
              find
                  .ancestor(
                    of: find.text('Send'),
                    matching: find.byType(Container),
                  )
                  .first,
            )
            .height,
        52,
      );
    });

    testWidgets('a chosen row is filled only before sending; my answer in the '
        'results keeps the usual background, the accent border and bar; text '
        'on the accent by contrast', (tester) async {
      const accent = Color(0xFF22C55E);
      Container row(String label) => tester.widget<Container>(
        find
            .ancestor(of: find.text(label), matching: find.byType(Container))
            .first,
      );
      Color? fill(String label) =>
          (row(label).decoration! as BoxDecoration).color;
      Color? border(String label) =>
          ((row(label).foregroundDecoration as BoxDecoration?)?.border
                  as Border?)
              ?.top
              .color;

      await tester.pumpWidget(
        alone(_poll('mini_poll', kind: 'multiple_choice')),
      );
      await tester.tap(find.text('Маме'));
      await tester.pump();
      expect((fill('Маме'), border('Маме')), (const Color(0x3322C55E), accent));
      expect((fill('Себе'), border('Себе')), (const Color(0x0F000000), null));
      expect(
        tester.widget<Text>(find.text('Send')).style!.color,
        const Color(0xFF000000),
        reason: 'dark is the contrast on the accent',
      );

      await tester.pumpWidget(alone(answered()));
      await tester.pumpAndSettle();
      expect((fill('Маме'), border('Маме')), (const Color(0x0F000000), accent));
      expect((fill('Себе'), border('Себе')), (const Color(0x0F000000), null));
      Color bar(String label) => tester
          .widget<ColoredBox>(
            find.descendant(
              of: find
                  .ancestor(of: find.text(label), matching: find.byType(Stack))
                  .first,
              matching: find.byType(ColoredBox),
            ),
          )
          .color;
      expect(bar('Маме'), const Color(0x4022C55E));
      expect(bar('Себе'), const Color(0x14000000));
    });

    testWidgets('the scale: the chosen digit in a capsule of its band colour, '
        'the accent without bands; the rest dimmed once answered', (
      tester,
    ) async {
      Color? capsule(String digit) {
        final decoration =
            tester
                    .widget<DecoratedBox>(
                      find
                          .ancestor(
                            of: find.text(digit),
                            matching: find.byType(DecoratedBox),
                          )
                          .first,
                    )
                    .decoration
                as BoxDecoration;
        return decoration.color;
      }

      double opacity(String digit) => tester
          .widget<Opacity>(
            find
                .ancestor(of: find.text(digit), matching: find.byType(Opacity))
                .first,
          )
          .opacity;

      await tester.pumpWidget(
        alone(_poll('nps', answer: <String, dynamic>{'rate': 9})),
      );
      expect(capsule('9'), storyPollScaleColor(StoryPollType.nps, 9, 0, 10));
      expect(capsule('5'), isNull);
      expect((opacity('9'), opacity('5')), (1.0, 0.55));
      expect(
        tester.widget<Text>(find.text('9')).style!.color,
        const Color(0xFF000000),
        reason: 'dark is the contrast on a light green',
      );

      await tester.pumpWidget(
        alone(
          _poll(
            'csat',
            answer: <String, dynamic>{'rate': 3},
            fields: <String, dynamic>{'bands': <Object>[]},
          ),
        ),
      );
      expect(capsule('3'), const Color(0xFF22C55E));
    });
  });

  testWidgets('text re-answer: an empty field in focus, the slide held', (
    tester,
  ) async {
    await open(
      tester,
      _stories(<List<Map<String, dynamic>>>[
        <Map<String, dynamic>>[
          _slide('1', <Map<String, dynamic>>[
            _poll(
              'mini_poll',
              kind: 'text',
              maxLength: 10,
              allowReanswer: true,
            ),
          ]),
          _slide('2'),
        ],
      ]),
    );
    await tester.enterText(find.byType(TextField), 'Книга');
    await tester.pump();
    await tester.tap(find.text('Send'));
    await tester.pump();
    transport.pending.single.complete(const StoryPollReply());
    await _replied(tester);
    expect(find.byType(TextField), findsNothing);
    expect(find.text('Книга'), findsOneWidget, reason: 'the answer');
    await tester.tap(find.text('Answer again'));
    await tester.pump();
    await tester.pump();
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      isEmpty,
      reason: 'the previous text is not put back',
    );
    expect(find.text('0/10'), findsOneWidget);
    expect(FocusManager.instance.primaryFocus?.debugLabel, 'story poll');
    await _wait(tester, const Duration(milliseconds: 1500));
    expect(find.text('Slide 1'), findsOneWidget, reason: 'held while focused');
  });

  testWidgets('y_offset is a share of the whole slide, system bars included', (
    tester,
  ) async {
    tester.view
      ..padding = const FakeViewPadding(top: 50 * 3, bottom: 34 * 3)
      ..viewPadding = const FakeViewPadding(top: 50 * 3, bottom: 34 * 3);
    await open(
      tester,
      _stories(<List<Map<String, dynamic>>>[
        <Map<String, dynamic>>[
          _slide('1', <Map<String, dynamic>>[_poll('nps', yOffset: 50)]),
        ],
        <Map<String, dynamic>>[
          _slide('2', <Map<String, dynamic>>[_poll('nps', yOffset: 0)]),
        ],
      ]),
    );
    expect(tester.getRect(card).top, _screen.height / 2);
    requests.add(1);
    await tester.pump();
    await _settle(tester);
    expect(find.text('Slide 2'), findsOneWidget);
    expect(
      tester.getRect(card).top,
      greaterThan(50 + 16),
      reason: 'moved under the header',
    );
  });

  testWidgets('y_offset: none, below 0 or not a number — right under the '
      'header; over 100 — down to the bottom', (tester) async {
    final offsets = <Object?>[0, null, -20, 'NaN', 100, 150];
    await open(
      tester,
      _stories(<List<Map<String, dynamic>>>[
        for (final offset in offsets)
          <Map<String, dynamic>>[
            _slide('$offset', <Map<String, dynamic>>[
              _poll('nps', yOffset: offset),
            ]),
          ],
      ]),
    );
    final rects = <Rect>[];
    for (var index = 0; index < offsets.length; index++) {
      if (index > 0) {
        requests.add(index);
        await tester.pump();
        await _settle(tester);
      }
      expect(find.text('Slide ${offsets[index]}'), findsOneWidget);
      rects.add(tester.getRect(card));
    }
    expect(rects.first.top, greaterThan(16), reason: 'under the header');
    expect(
      rects.sublist(1, 4).map((rect) => rect.top),
      everyElement(rects.first.top),
    );
    expect(rects[4].bottom, _screen.height - 16);
    expect(rects[5], rects[4]);
  });

  group('PersonalizationStories', () {
    late _HostApi api;
    late PersonalizationSdk sdk;
    late List<String> calls;
    late List<Map<String, dynamic>> posts;
    final payload = <String, dynamic>{
      'id': 35,
      'stories': <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 1,
          'name': 'Polls',
          'avatar': '',
          'slides': <Map<String, dynamic>>[
            _slide('1', <Map<String, dynamic>>[single]),
            _slide('2'),
          ],
        },
      ],
    };

    setUp(() {
      StoriesSeenStore.instance = StoriesSeenStore();
      api = _HostApi()..bridgeFeed = jsonEncode(payload);
      sdk = PersonalizationSdk(api: api, shopId: 'shop');
      calls = <String>[];
      posts = <Map<String, dynamic>>[];
      StoriesApiV3.send = (method, uri, body) async {
        calls.add('$method ${uri.host}${uri.path}');
        if (method == 'GET') {
          return (
            status: 200,
            body: jsonEncode(<String, dynamic>{
              'status': 'success',
              'payload': payload,
            }),
          );
        }
        posts.add(jsonDecode(body!) as Map<String, dynamic>);
        return (status: 200, body: '{"status":"success"}');
      };
    });

    Future<void> openBlock(
      WidgetTester tester, {
      required String apiV3Domain,
      bool own = true,
    }) async {
      tester.view
        ..physicalSize = _screen * 3
        ..devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: 400,
                child: PersonalizationStoriesV3(
                  apiV3Domain: apiV3Domain,
                  pollsTransport: own ? transport : null,
                  child: PersonalizationStories(
                    key: UniqueKey(),
                    code: 'block',
                    sdk: sdk,
                    iconBuilder: _icon,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      await tester.tap(find.text('Polls'));
      await _settle(tester);
    }

    Future<void> closeViewer(WidgetTester tester) async {
      Navigator.of(
        tester.element(find.byType(PersonalizationStoryViewer)),
      ).pop();
      await _settle(tester);
    }

    testWidgets('a transport only with API v3; polls send no events', (
      tester,
    ) async {
      await openBlock(tester, apiV3Domain: '');
      expect(find.text('Slide 1'), findsOneWidget);
      expect(
        card,
        findsNothing,
        reason: 'the old API: its own transport does not turn polls on',
      );
      expect(calls, isEmpty);
      await closeViewer(tester);

      // Slide 1 is seen now: the viewer would start from slide 2.
      StoriesSeenStore.instance = StoriesSeenStore();

      await openBlock(tester, apiV3Domain: 'app.example');
      expect(card, findsOneWidget);
      await tester.tap(find.text('Маме'));
      await tester.pump();
      expect(transport.bodies.single['option_ids'], <int>[2]);
      transport.pending.single.complete(const StoryPollReply());
      await _replied(tester);
      expect(find.text('Спасибо!'), findsOneWidget);
      expect(calls.where((call) => call.contains('/polls/')), isEmpty);
      expect(posts.map((post) => post['event']).toSet(), <String>{
        'view',
      }, reason: 'no events for polls');
      await closeViewer(tester);
    });

    testWidgets('without its own transport — HTTP to the host of the block', (
      tester,
    ) async {
      await openBlock(tester, apiV3Domain: 'app.example', own: false);
      await tester.tap(find.text('Маме'));
      for (var i = 0; i < 5; i++) {
        await tester.pump();
      }
      expect(
        calls.last,
        'POST app.example/api/v3/polls/mini_polls/code_mini_pollsingle_choice/answers',
      );
      expect(posts.last, <String, dynamic>{
        'shop_id': 'shop',
        'did': 'did-1',
        'sid': 'sid-1',
        'option_ids': <int>[2],
        'story_id': 1,
        'slide_id': '1',
      });
      expect(find.text('Спасибо!'), findsOneWidget);
      await closeViewer(tester);
    });
  });
}

/// The SDK bridge for a block: the old feed, seen slides and tracking do nothing.
class _HostApi extends pigeon.PersonalizationHostApi {
  /// What the old-API feed through the bridge answers.
  String bridgeFeed = '';

  @override
  Future<String?> getDid(String? shopId) async => 'did-1';

  @override
  Future<String> getSid(String? shopId) async => 'sid-1';

  @override
  Future<String> getStories(String code, String? shopId) async => bridgeFeed;

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
  ) async {}

  @override
  Future<void> trackStoryClick(
    String storyId,
    String slideId,
    String? code,
    String? shopId,
  ) async {}

  @override
  Future<void> trackSetSource(
    pigeon.TrackingSourceWire source,
    String? shopId,
  ) async {}
}
