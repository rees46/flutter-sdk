import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rees46_sdk/src/ui/components/personalization_story_poll.dart';
import 'package:rees46_sdk/src/ui/personalization_ui.dart';
import 'package:rees46_sdk/src/v3/personalization_v3.dart';
import 'package:rees46_sdk/src/ui/widgets/stories_poll.dart';

/// A transport that never answers: the card only has to be drawn.
class _Transport implements StoryPollsTransport {
  @override
  Future<StoryPollReply> answerMiniPoll(
    String code,
    Map<String, Object> body,
  ) => Completer<StoryPollReply>().future;

  @override
  Future<StoryPollReply> review(StoryPollType kind, Map<String, Object> body) =>
      Completer<StoryPollReply>().future;
}

Map<String, dynamic> _text(String text, Object? yOffset) => <String, dynamic>{
  'type': 'text_block',
  'text_input': text,
  'y_offset': yOffset,
};

Map<String, dynamic> _poll(Object? yOffset) => <String, dynamic>{
  'type': 'poll',
  'poll_type': 'nps',
  'y_offset': yOffset,
  'poll': <String, dynamic>{'code': 'nps', 'question': 'How likely?'},
};

/// One story of one slide without media.
List<Story> _stories(List<Map<String, dynamic>> elements) =>
    StoriesBlock.fromJson(<String, dynamic>{
      'id': 1,
      'stories': <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 40,
          'name': 'Story',
          'avatar': '',
          'slides': <Map<String, dynamic>>[
            <String, dynamic>{
              'id': '38',
              'type': 'image',
              'background': '',
              'duration': 10,
              'elements': elements,
            },
          ],
        },
      ],
    }).stories;

Widget _icon(BuildContext context, String asset, double size, Color color) =>
    SizedBox.square(key: ValueKey<String>(asset), dimension: size);

/// The phone: 402 × 874, status bar 50, home indicator 34.
const Size _screen = Size(402, 874);
const double _statusBar = 50;
const double _homeIndicator = 34;

/// Top of the place for slide blocks: the status bar, then the header at 16 and 8 below.
const double _areaTop =
    _statusBar + 16 + PersonalizationStoryNavigation.height + 8;

/// Bottom of that place on a slide without buttons and products: 16 above the bar.
const double _areaBottom = 874 - _homeIndicator - 16;

Future<void> _open(WidgetTester tester, List<Story> stories) async {
  tester.view
    ..physicalSize = _screen * 3
    ..devicePixelRatio = 3
    ..padding = const FakeViewPadding(
      top: _statusBar * 3,
      bottom: _homeIndicator * 3,
    )
    ..viewPadding = const FakeViewPadding(
      top: _statusBar * 3,
      bottom: _homeIndicator * 3,
    );
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Center(
          child: GestureDetector(
            onTap: () => Navigator.of(context).push(
              PersonalizationStoryViewer.route(
                PersonalizationStoriesV3(
                  apiV3Domain: 'app.example',
                  pollsTransport: _Transport(),
                  child: PersonalizationStoryViewer(
                    stories: stories,
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
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pump();
}

Rect _block(WidgetTester tester, String text) => tester.getRect(
  find.ancestor(
    of: find.text(text),
    matching: find.byType(PersonalizationStoryTextBlock),
  ),
);

void main() {
  setUp(() => StoryPollStore.instance = StoryPollStore());

  testWidgets('text block: y_offset of the whole slide, then inside the place '
      'between the header and the bottom', (tester) async {
    await _open(
      tester,
      _stories(<Map<String, dynamic>>[
        _text('none', null),
        _text('not a number', 'NaN'),
        _text('five', 5),
        _text('half', 50),
        _text('ninety-five', '95'),
      ]),
    );
    final header = tester.getRect(find.byType(PersonalizationStoryNavigation));

    // None or not a number — 0: at the top of the place, under the header.
    expect(_block(tester, 'none').top, _areaTop);
    expect(_block(tester, 'not a number').top, _areaTop);

    // 5% of the slide is under the status bar and the header: moved down to the place.
    final five = _block(tester, 'five');
    expect(_screen.height * 0.05, lessThan(header.bottom));
    expect(five.top, _areaTop);
    expect(five.top, greaterThan(header.bottom), reason: 'not on the header');

    // 50% of the whole slide, system bars included.
    expect(_block(tester, 'half').top, _screen.height / 2);

    // 95% does not fit: the bottom stays at the bottom of the place.
    final last = _block(tester, 'ninety-five');
    expect(last.bottom, _areaBottom);
    expect(last.top, lessThan(_screen.height * 0.95));

    // Sides stay as they were.
    expect((last.left, last.right), (16, _screen.width - 16));
  });

  testWidgets('a text block and a poll with one y_offset stand at one height', (
    tester,
  ) async {
    for (final offset in <Object?>[5, 30, 50]) {
      await _open(
        tester,
        _stories(<Map<String, dynamic>>[_text('text', offset), _poll(offset)]),
      );
      final card = tester.getRect(find.byType(PersonalizationStoryPoll));
      expect(_block(tester, 'text').top, card.top, reason: 'y_offset $offset');
      Navigator.of(tester.element(find.text('open'))).pop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();
    }
  });
}
