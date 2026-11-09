import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:rees46_sdk/rees46_sdk.dart';
// v3 (popups of the new builder, stories over API v3) is not public API; its gate is
// lifted when v3 goes public. The example reaches it directly, which the analyzer
// flags as an implementation import on purpose.
// ignore: implementation_imports
import 'package:rees46_sdk/src/v3/personalization_v3.dart';

import 'demo_app.dart';

/// "Stories V2 polls (offline)" of the UI Kit showcase: campaign 9001 of the shared poll
/// feed (`assets/uikit/stories_polls_feed.json` — every poll kind, an answered choice
/// with results and an unknown kind that is not drawn) in the V2 viewer over API v3,
/// with [DemoPollsTransport] instead of the network. Slide pictures still come from the
/// CDN. No SDK: nothing is tracked.
Future<void> openStoriesPollsDemo(
  BuildContext context, {
  required Widget Function(
    BuildContext context,
    String asset,
    double size,
    Color color,
  )
  iconBuilder,
}) async {
  final json =
      jsonDecode(
            await rootBundle.loadString('assets/uikit/stories_polls_feed.json'),
          )
          as Map<String, dynamic>;
  final stories = StoriesBlock.fromJson(
    json['payload'] as Map<String, dynamic>,
  ).stories;
  if (!context.mounted) return;
  await Navigator.of(context, rootNavigator: true).push(
    PersonalizationStoryViewer.route(
      // API v3 mode turns the polls on; the transport keeps them offline.
      PersonalizationStoriesV3(
        apiV3Domain: demoStoriesApiV3Domain,
        pollsTransport: DemoPollsTransport(stories),
        child: PersonalizationStoryViewer(
          stories: stories,
          iconBuilder: iconBuilder,
        ),
      ),
    ),
  );
}

/// Poll answers without the network: each one takes [delay]. Mini polls with
/// `show_results` get results (the chosen options get more, 100 in total); the first
/// answer of `demo_text` fails, the next ones go through; scales always go through.
class DemoPollsTransport implements StoryPollsTransport {
  DemoPollsTransport(List<Story> stories)
    : _polls = <String, StoryPollElement>{
        for (final story in stories)
          for (final slide in story.slides)
            for (final element in slide.elements)
              if (element is StoryPollElement) element.code: element,
      };

  static const Duration delay = Duration(milliseconds: 600);

  /// The code of the poll whose first answer fails.
  static const String failingCode = 'demo_text';

  final Map<String, StoryPollElement> _polls;
  bool _failed = false;

  @override
  Future<StoryPollReply> answerMiniPoll(
    String code,
    Map<String, Object> body,
  ) async {
    await Future<void>.delayed(delay);
    if (code == failingCode && !_failed) {
      _failed = true;
      throw StateError('demo: the first answer of "$code" fails');
    }
    final ids = (body['option_ids'] as List<Object?>?)?.cast<int>();
    final text = body['text'] as String?;
    final poll = _polls[code];
    return StoryPollReply(
      answer: StoryPollAnswer(optionIds: ids, text: text),
      results:
          poll != null &&
              poll.showResults &&
              poll.options.isNotEmpty &&
              ids != null
          ? _results(poll, ids.toSet())
          : null,
    );
  }

  @override
  Future<StoryPollReply> review(
    StoryPollType kind,
    Map<String, Object> body,
  ) async {
    await Future<void>.delayed(delay);
    return const StoryPollReply();
  }

  /// A chosen option weighs 3, the others 1; percents add up to 100 (the rest of the
  /// rounding goes to the first chosen one).
  StoryPollResults _results(StoryPollElement poll, Set<int> chosen) {
    final weights = <int, int>{
      for (final option in poll.options)
        option.id: chosen.contains(option.id) ? 3 : 1,
    };
    final total = weights.values.fold<int>(0, (sum, weight) => sum + weight);
    final percents = <int, int>{
      for (final entry in weights.entries)
        entry.key: entry.value * 100 ~/ total,
    };
    final rest =
        100 - percents.values.fold<int>(0, (sum, value) => sum + value);
    final first = poll.options
        .map((option) => option.id)
        .firstWhere(chosen.contains, orElse: () => weights.keys.first);
    percents[first] = percents[first]! + rest;
    return StoryPollResults(
      total: total * 10,
      options: <({int id, double percent})>[
        for (final entry in percents.entries)
          (id: entry.key, percent: entry.value.toDouble()),
      ],
    );
  }
}
