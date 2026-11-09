import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rees46_sdk/rees46_sdk.dart';
// ignore: implementation_imports
import 'package:rees46_sdk/src/v3/personalization_v3.dart';
import 'package:rees46_sdk_example/stories_polls_demo.dart';

List<Story> _stories() {
  final json =
      jsonDecode(
            File('assets/uikit/stories_polls_feed.json').readAsStringSync(),
          )
          as Map<String, dynamic>;
  return StoriesBlock.fromJson(json['payload'] as Map<String, dynamic>).stories;
}

void main() {
  test(
    'the demo feed: one campaign, seven polls drawn, the unknown dropped',
    () {
      final slides = _stories().single.slides;
      expect(slides, hasLength(8));
      expect(
        slides.where(
          (slide) => slide.elements.whereType<StoryPollElement>().isNotEmpty,
        ),
        hasLength(7),
      );
    },
  );

  testWidgets(
    'the fake transport: results add up to 100, demo_text fails once',
    (tester) async {
      final transport = DemoPollsTransport(_stories());
      StoryPollReply? reply;
      unawaited(
        transport
            .answerMiniPoll('demo_multi', <String, Object>{
              'option_ids': <int>[1, 3],
            })
            .then((value) => reply = value),
      );
      await tester.pump(DemoPollsTransport.delay);
      expect(reply!.answer!.optionIds, <int>[1, 3]);
      final options = reply!.results!.options!;
      expect(
        options.fold<double>(0, (sum, option) => sum + option.percent),
        100,
      );
      expect(
        reply!.results!.percentOf(1),
        greaterThan(reply!.results!.percentOf(2)!),
      );

      Object? error;
      unawaited(
        transport
            .answerMiniPoll('demo_text', <String, Object>{'text': 'a'})
            .then<void>((_) {}, onError: (Object e) => error = e),
      );
      await tester.pump(DemoPollsTransport.delay);
      expect(error, isNotNull);
      unawaited(
        transport
            .answerMiniPoll('demo_text', <String, Object>{'text': 'a'})
            .then((value) => reply = value),
      );
      await tester.pump(DemoPollsTransport.delay);
      expect(reply!.answer!.text, 'a');
      expect(reply!.results, isNull, reason: 'no show_results');
    },
  );
}
