import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rees46_sdk/src/stories/stories_response.dart';
import 'package:rees46_sdk/src/ui/widgets/stories_api_v3.dart';
import 'package:rees46_sdk/src/ui/widgets/stories_playback.dart';
import 'package:rees46_sdk/src/ui/widgets/stories_poll.dart';
import 'package:rees46_sdk/src/ui/widgets/stories_polls_api.dart';

/// A transport answering by hand: each request waits in [pending].
class _Transport implements StoryPollsTransport {
  final List<(String, Object, Map<String, Object>)> calls =
      <(String, Object, Map<String, Object>)>[];
  final List<Completer<StoryPollReply>> pending = <Completer<StoryPollReply>>[];

  Future<StoryPollReply> _wait() {
    final completer = Completer<StoryPollReply>();
    pending.add(completer);
    return completer.future;
  }

  @override
  Future<StoryPollReply> answerMiniPoll(String code, Map<String, Object> body) {
    calls.add(('answerMiniPoll', code, body));
    return _wait();
  }

  @override
  Future<StoryPollReply> review(StoryPollType kind, Map<String, Object> body) {
    calls.add(('review', kind, body));
    return _wait();
  }
}

/// A mini poll like the web fixtures: «Кому выбираете подарок?» with three options.
StoryPollElement _mini(
  StoryMiniPollKind kind, {
  bool allowReanswer = false,
  StoryPollAnswer? answer,
  StoryPollResults? results,
  String submitLabel = 'Отправить',
  StoryPollLabels labels = const StoryPollLabels(),
  String code = 'gift_recipient',
}) => StoryPollElement(
  pollType: StoryPollType.miniPoll,
  kind: kind,
  code: code,
  yOffset: 40,
  allowReanswer: allowReanswer,
  question: 'Кому выбираете подарок?',
  placeholder: kind == StoryMiniPollKind.text ? 'Название или автор' : '',
  maxLength: kind == StoryMiniPollKind.text ? 10 : null,
  submitLabel: submitLabel,
  thanksText: 'Спасибо!',
  showResults: true,
  options: const <StoryPollOption>[
    StoryPollOption(id: 1, label: 'Себе'),
    StoryPollOption(id: 2, label: 'Маме'),
    StoryPollOption(id: 3, label: 'Папе'),
  ],
  answer: answer,
  results: results,
  labels: labels,
);

StoryPollElement _scale(
  StoryPollType type, {
  bool allowReanswer = false,
  StoryPollAnswer? answer,
  String channel = 'stories',
  List<StoryPollBand>? bands,
  int? rateMin,
  int? rateMax,
}) => StoryPollElement(
  pollType: type,
  code: 'delivery',
  yOffset: 50,
  allowReanswer: allowReanswer,
  channel: channel,
  question: 'Как вам доставка?',
  rateMin: rateMin,
  rateMax: rateMax,
  bands:
      bands ??
      const <StoryPollBand>[
        StoryPollBand(from: 0, to: 6, success: 'Спасибо, мы станем лучше'),
        StoryPollBand(from: 7, to: 8, success: 'Спасибо!'),
        StoryPollBand(from: 9, to: 10, success: 'Спасибо, рады стараться!'),
      ],
  answer: answer,
);

const StoryPollAnswer _answered = StoryPollAnswer(optionIds: <int>[2]);
const StoryPollResults _results = StoryPollResults(
  total: 120,
  options: <({int id, double percent})>[
    (id: 1, percent: 40),
    (id: 2, percent: 60),
  ],
);

void main() {
  late _Transport transport;
  late List<bool> holds;

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    StoryPollStore.instance = StoryPollStore();
    transport = _Transport();
    holds = <bool>[];
  });

  StoryPollController mount(
    StoryPollElement poll, {
    StoryPollTexts texts = const StoryPollTexts(),
    String shopId = 'shop',
  }) => StoryPollController(
    poll: poll,
    storyId: '5',
    slideId: '101',
    transport: transport,
    shopId: shopId,
    texts: texts,
    onHold: holds.add,
  );

  Future<void> reply(
    int index, [
    StoryPollReply value = const StoryPollReply(),
  ]) async {
    transport.pending[index].complete(value);
    await pumpEventQueue();
  }

  Future<void> fail(int index) async {
    transport.pending[index].completeError(Exception('Too many requests'));
    await pumpEventQueue();
  }

  group('single choice', () {
    test('sends on tap, then thanks and results', () async {
      final poll = mount(_mini(StoryMiniPollKind.singleChoice));
      expect(poll.answered, isFalse);
      poll.choose(2);
      expect(transport.calls.single.$1, 'answerMiniPoll');
      expect(transport.calls.single.$2, 'gift_recipient');
      expect(transport.calls.single.$3, <String, Object>{
        'option_ids': <int>[2],
        'source_type': 'stories',
        'source_id': '5',
        'source_item_id': '101',
      });
      expect(poll.sending, isTrue);
      expect(poll.selected, <int>{2});
      await reply(
        0,
        const StoryPollReply(
          answer: StoryPollAnswer(id: 77, optionIds: <int>[2]),
          results: StoryPollResults(
            total: 121,
            options: <({int id, double percent})>[
              (id: 1, percent: 40),
              (id: 2, percent: 60),
            ],
          ),
        ),
      );
      expect(poll.answered, isTrue);
      expect(poll.sending, isFalse);
      expect(poll.answer!.optionIds, <int>[2]);
      expect(
        <int?>[
          for (final id in <int>[1, 2, 3]) poll.results!.percentOf(id),
        ],
        <int>[40, 60, 0],
      );
    });

    test('does not send twice while the request is pending', () {
      final poll = mount(_mini(StoryMiniPollKind.singleChoice));
      poll
        ..choose(1)
        ..choose(1)
        ..choose(3);
      expect(transport.calls, hasLength(1));
    });

    test('an error rolls the choice back and allows a retry', () async {
      final poll = mount(_mini(StoryMiniPollKind.singleChoice));
      poll.choose(1);
      await fail(0);
      expect(poll.failed, isTrue);
      expect(poll.sending, isFalse);
      expect(poll.selected, isEmpty);
      poll.choose(1);
      expect(transport.calls, hasLength(2));
      expect(poll.failed, isFalse);
      await reply(
        1,
        const StoryPollReply(answer: StoryPollAnswer(optionIds: <int>[1])),
      );
      expect(poll.answered, isTrue);
      expect(poll.results, isNull, reason: 'no percent without results');
    });

    test('the sent answer when the server returns none', () async {
      final poll = mount(_mini(StoryMiniPollKind.singleChoice));
      poll.choose(3);
      await reply(0);
      expect(poll.answer!.optionIds, <int>[3]);
    });

    test('an answer of the reply without ids is still the answer', () async {
      final poll = mount(_mini(StoryMiniPollKind.singleChoice))..choose(2);
      await reply(0, const StoryPollReply(answer: StoryPollAnswer(id: 77)));
      expect(poll.answered, isTrue, reason: 'answered after any success');
      expect(poll.answer!.id, 77);
      expect(poll.answer!.optionIds, isNull, reason: 'not the sent one');
    });

    test(
      'no code: the card works, the answer goes with an empty one',
      () async {
        final poll = mount(_mini(StoryMiniPollKind.singleChoice, code: ''));
        poll.choose(2);
        expect(transport.calls.single.$2, '');
        await fail(0);
        expect(poll.failed, isTrue, reason: 'the server rejects it');
        poll.choose(2);
        await reply(1);
        expect(poll.answered, isTrue, reason: 'the empty code is a code');
      },
    );

    test('the card does not log a failed send: the transport does', () async {
      final logs = <String>[];
      final print = debugPrint;
      debugPrint = (message, {wrapWidth}) => logs.add(message ?? '');
      addTearDown(() => debugPrint = print);
      final poll = mount(_mini(StoryMiniPollKind.singleChoice))..choose(1);
      transport.pending.single.completeError(
        StoriesV3Exception('HTTP 429: Too many requests', status: 429),
      );
      await pumpEventQueue();
      expect(poll.failed, isTrue);
      expect(logs, isEmpty);
    });
  });

  group('multiple choice', () {
    test(
      'chips do not send; the button sends in the order of the options',
      () async {
        final poll = mount(_mini(StoryMiniPollKind.multipleChoice));
        expect(poll.canSubmit, isFalse);
        poll
          ..toggle(3)
          ..toggle(1);
        expect(poll.selected, <int>{1, 3});
        expect(poll.canSubmit, isTrue);
        expect(transport.calls, isEmpty, reason: 'chips do not send');
        poll
          ..toggle(3)
          ..toggle(3)
          ..submitChoices();
        expect(transport.calls.single.$3, <String, Object>{
          'option_ids': <int>[1, 3],
          'source_type': 'stories',
          'source_id': '5',
          'source_item_id': '101',
        });
        await reply(
          0,
          const StoryPollReply(answer: StoryPollAnswer(optionIds: <int>[1, 3])),
        );
        expect(poll.answered, isTrue);
        expect(poll.answer!.optionIds, <int>[1, 3]);
      },
    );

    test('the button is off again when every chip is off', () {
      final poll = mount(_mini(StoryMiniPollKind.multipleChoice))
        ..toggle(1)
        ..toggle(1)
        ..submitChoices();
      expect(poll.canSubmit, isFalse);
      expect(transport.calls, isEmpty);
    });
  });

  group('text', () {
    test('sends the trimmed text; blank does not send', () async {
      final poll = mount(_mini(StoryMiniPollKind.text));
      expect(poll.showsField, isTrue);
      poll.text = '   ';
      expect(poll.canSubmit, isFalse);
      poll.submitText();
      expect(transport.calls, isEmpty);
      poll
        ..text = ' Мастер и '
        ..submitText();
      expect(transport.calls.single.$3, <String, Object>{
        'text': 'Мастер и',
        'source_type': 'stories',
        'source_id': '5',
        'source_item_id': '101',
      });
      expect(poll.canSubmit, isFalse, reason: 'off while sending');
      await reply(
        0,
        const StoryPollReply(answer: StoryPollAnswer(id: 1, text: 'Мастер и')),
      );
      expect(poll.answered, isTrue);
      expect(poll.showsField, isFalse);
      expect(poll.answer!.text, 'Мастер и');
    });
  });

  group('follow-up question of a band', () {
    const bands = <StoryPollBand>[
      StoryPollBand(
        from: 0,
        to: 6,
        question: ' Что пошло не так? ',
        success: 'Спасибо, мы станем лучше',
      ),
      StoryPollBand(from: 7, to: 10, question: ' ', success: 'Спасибо!'),
    ];

    test(
      'the question, then the same rate with the comment, then success',
      () async {
        final poll = mount(_scale(StoryPollType.nps, bands: bands))..rate(3);
        expect(poll.followUp, isNull, reason: 'not before the rate is sent');
        await reply(0);
        expect(poll.followUp, 'Что пошло не так?');
        expect(poll.showsField, isTrue);
        expect(poll.fieldLimit, storyPollCommentMaxLength);
        expect(storyPollCommentMaxLength, 5000);
        expect(poll.canSubmit, isFalse);
        poll
          ..text = '  Долго  '
          ..submitComment();
        expect(transport.calls.last.$3, <String, Object>{
          'channel': 'stories',
          'category': 'delivery',
          'rate': 3,
          'comment': 'Долго',
          'source_type': 'stories',
          'source_id': '5',
          'source_item_id': '101',
        });
        expect(poll.sending, isTrue);
        await reply(1);
        expect(poll.answer!.rate, 3);
        expect(poll.answer!.comment, 'Долго');
        expect(poll.followUp, isNull);
        expect(poll.showsField, isFalse);
        expect(
          storyPollBandText(poll.poll, poll.answer!.rate),
          'Спасибо, мы станем лучше',
        );
      },
    );

    test('a blank question — success at once', () async {
      final poll = mount(_scale(StoryPollType.nps, bands: bands))..rate(9);
      await reply(0);
      expect(poll.followUp, isNull);
      expect(storyPollBandQuestion(poll.poll, 9), isNull);
    });

    test('an answer without a comment asks again on the next show', () {
      final poll = mount(
        _scale(
          StoryPollType.nps,
          bands: bands,
          answer: const StoryPollAnswer(rate: 2),
        ),
      );
      expect(poll.answered, isTrue);
      expect(poll.followUp, 'Что пошло не так?');
      expect(
        mount(
          _scale(
            StoryPollType.nps,
            bands: bands,
            answer: const StoryPollAnswer(rate: 2, comment: 'Курьер'),
          ),
        ).followUp,
        isNull,
      );
    });

    test(
      'a re-answer sends the new rate without a comment, asks again',
      () async {
        final poll = mount(
          _scale(
            StoryPollType.nps,
            bands: bands,
            allowReanswer: true,
            answer: const StoryPollAnswer(rate: 2, comment: 'Курьер'),
          ),
        )..reanswer();
        expect(poll.followUp, isNull);
        poll.rate(5);
        expect(transport.calls.single.$3.containsKey('comment'), isFalse);
        await reply(0);
        expect(poll.followUp, 'Что пошло не так?');
        expect(poll.text, isEmpty);
      },
    );

    test('a failed comment keeps the field and the text', () async {
      final poll = mount(_scale(StoryPollType.nps, bands: bands))..rate(1);
      await reply(0);
      poll
        ..text = 'Долго'
        ..submitComment();
      await fail(1);
      expect(poll.failed, isTrue);
      expect(poll.followUp, isNotNull);
      expect(poll.text, 'Долго');
    });

    test('the slide holds while the comment field is focused', () async {
      final poll = mount(_scale(StoryPollType.nps, bands: bands))..rate(1);
      await reply(0);
      holds.clear();
      poll.focused = true;
      expect(holds, <bool>[true]);
      poll.focused = false;
      expect(holds, <bool>[true, false]);
    });
  });

  group('scales', () {
    test('NPS 0..10 sends the rate on tap with its category', () async {
      final poll = mount(_scale(StoryPollType.nps));
      expect(storyPollScaleRange(poll.poll), <int>[
        for (var i = 0; i <= 10; i++) i,
      ]);
      poll.rate(9);
      expect(transport.calls.single.$1, 'review');
      expect(transport.calls.single.$2, StoryPollType.nps);
      expect(transport.calls.single.$3, <String, Object>{
        'channel': 'stories',
        'category': 'delivery',
        'rate': 9,
        'source_type': 'stories',
        'source_id': '5',
        'source_item_id': '101',
      });
      await reply(0);
      expect(poll.answered, isTrue);
      expect(poll.rateValue, 9);
      expect(
        storyPollBandText(poll.poll, poll.answer!.rate),
        'Спасибо, рады стараться!',
      );
    });

    test(
      'CSAT 1..5 and CES 1..7 with campaign; no channel — stories',
      () async {
        final csat = mount(
          _scale(
            StoryPollType.csat,
            bands: const <StoryPollBand>[
              StoryPollBand(from: 1, to: 3, success: 'Жаль'),
              StoryPollBand(from: 4, to: 5, success: 'Ура'),
            ],
          ),
        );
        expect(storyPollScaleRange(csat.poll), <int>[1, 2, 3, 4, 5]);
        csat.rate(1);
        expect(transport.calls.single.$3, <String, Object>{
          'channel': 'stories',
          'campaign': 'delivery',
          'rate': 1,
          'source_type': 'stories',
          'source_id': '5',
          'source_item_id': '101',
        });
        await reply(0);
        expect(storyPollBandText(csat.poll, csat.answer!.rate), 'Жаль');

        final ces = mount(_scale(StoryPollType.ces, channel: ''));
        expect(storyPollScaleRange(ces.poll), <int>[1, 2, 3, 4, 5, 6, 7]);
        ces.rate(7);
        expect(transport.calls.last.$3, <String, Object>{
          'channel': 'stories',
          'campaign': 'delivery',
          'rate': 7,
          'source_type': 'stories',
          'source_id': '5',
          'source_item_id': '101',
        });
      },
    );

    test('ranges: defaults, own bounds, no more than 21 values', () {
      expect(storyPollScaleRange(_scale(StoryPollType.csat)), <int>[
        1,
        2,
        3,
        4,
        5,
      ]);
      expect(storyPollScaleRange(_scale(StoryPollType.nps)), hasLength(11));
      expect(
        storyPollScaleRange(_scale(StoryPollType.ces, rateMin: 2, rateMax: 4)),
        <int>[2, 3, 4],
      );
      final long = storyPollScaleRange(
        _scale(StoryPollType.nps, rateMin: 0, rateMax: 100),
      );
      expect(long, hasLength(21));
      expect(long.last, 20);
      expect(
        storyPollScaleRange(_scale(StoryPollType.nps, rateMin: 5, rateMax: 1)),
        isEmpty,
      );
    });

    test('a fractional rate: answered, no cell lit, its own band', () {
      final poll = mount(
        _scale(StoryPollType.nps, answer: const StoryPollAnswer(rate: 9.5)),
      );
      expect(poll.answered, isTrue);
      expect(storyPollScaleRange(poll.poll).contains(poll.rateValue), isFalse);
      expect(storyPollBandText(poll.poll, 9.5), 'Спасибо, рады стараться!');
      expect(
        storyPollBandText(poll.poll, 6.5),
        isNull,
        reason: 'between bands',
      );
    });

    test('blank texts of the host and labels override; trim only for text', () {
      final texts = const StoryPollTexts(reanswer: ' ', error: ' ').forPoll(
        _mini(
          StoryMiniPollKind.text,
          labels: const StoryPollLabels(submit: ' '),
        ),
      );
      expect((texts.reanswer, texts.error, texts.submit), (' ', ' ', ' '));
      final poll = mount(_mini(StoryMiniPollKind.text))..text = '  ';
      expect(poll.canSubmit, isFalse);
    });

    test('bands: inclusive bounds, a miss is null', () {
      final poll = _scale(
        StoryPollType.nps,
        bands: const <StoryPollBand>[
          StoryPollBand(from: 0, to: 6, success: 'A'),
        ],
      );
      expect(storyPollBandText(poll, 0), 'A');
      expect(storyPollBandText(poll, 6), 'A');
      expect(storyPollBandText(poll, 7), isNull);
      expect(storyPollBandText(poll, null), isNull);
    });

    test('tones: NPS by groups, the rest by thirds', () {
      const d = StoryPollScaleTone.danger;
      const w = StoryPollScaleTone.warning;
      const g = StoryPollScaleTone.success;
      expect(
        <StoryPollScaleTone>[
          for (var i = 0; i <= 10; i++)
            storyPollScaleTone(StoryPollType.nps, i, 0, 10),
        ],
        <StoryPollScaleTone>[d, d, d, d, d, d, d, w, w, g, g],
      );
      expect(
        <StoryPollScaleTone>[
          for (var i = 1; i <= 5; i++)
            storyPollScaleTone(StoryPollType.csat, i, 1, 5),
        ],
        <StoryPollScaleTone>[d, d, w, g, g],
      );
      expect(
        storyPollScaleTone(StoryPollType.nps, 3, 1, 5),
        w,
        reason: 'NPS on its own range — by thirds',
      );
      expect(storyPollScaleTone(StoryPollType.ces, 4, 4, 4), g);
    });

    test('a scale keeps only its rate, whatever the reply has', () async {
      final poll = mount(_scale(StoryPollType.csat))..rate(4);
      await reply(
        0,
        const StoryPollReply(
          answer: StoryPollAnswer(rate: 1, optionIds: <int>[1]),
          results: _results,
        ),
      );
      expect(poll.answer!.rate, 4);
      expect(poll.answer!.optionIds, isNull);
      expect(poll.results, isNull);
    });

    test('ranges of parsed bounds: not whole — the defaults', () {
      List<int> range(Object? min, Object? max) => storyPollScaleRange(
        StoryPollElement.tryParse(<String, dynamic>{
          'type': 'poll',
          'poll_type': 'ces',
          'poll': <String, dynamic>{
            'code': 'x',
            'rate_min': min,
            'rate_max': max,
          },
        })!,
      );
      expect(range(1.5, 3.5), <int>[1, 2, 3, 4, 5, 6, 7]);
      expect(range('2', '4'), <int>[2, 3, 4]);
      expect(range(9, null), isEmpty, reason: 'min over the default max');
    });

    test('an answered scale from the feed does not send', () {
      final poll = mount(
        _scale(StoryPollType.nps, answer: const StoryPollAnswer(rate: 3)),
      );
      expect(poll.answered, isTrue);
      expect(poll.rateValue, 3);
      expect(storyPollBandText(poll.poll, 3), 'Спасибо, мы станем лучше');
      poll.rate(5);
      expect(transport.calls, isEmpty);
    });
  });

  group('an answer from the feed', () {
    test('answered, no re-answer without allow_reanswer', () {
      final poll = mount(
        _mini(
          StoryMiniPollKind.singleChoice,
          answer: _answered,
          results: _results,
        ),
      );
      expect(poll.answered, isTrue);
      expect(poll.results!.percentOf(1), 40);
      poll
        ..reanswer()
        ..choose(1);
      expect(poll.answered, isTrue);
      expect(transport.calls, isEmpty);
    });

    test(
      're-answer: the form with the previous choice, then answered again',
      () async {
        final poll = mount(
          _mini(
            StoryMiniPollKind.singleChoice,
            allowReanswer: true,
            answer: _answered,
            results: _results,
          ),
        );
        poll.reanswer();
        expect(poll.answered, isFalse);
        expect(poll.selected, <int>{
          2,
        }, reason: 'previous answer is highlighted');
        poll.choose(1);
        expect(poll.selected, <int>{1}, reason: 'only the new option');
        await reply(
          0,
          const StoryPollReply(answer: StoryPollAnswer(optionIds: <int>[1])),
        );
        expect(poll.answered, isTrue);
      },
    );

    test('a failed re-answer restores the previous choice', () async {
      final poll = mount(
        _mini(
          StoryMiniPollKind.singleChoice,
          allowReanswer: true,
          answer: _answered,
        ),
      )..reanswer();
      poll.choose(3);
      await fail(0);
      expect(poll.selected, <int>{2});
    });

    test('multiple choice starts from the previous options', () {
      final poll = mount(
        _mini(
          StoryMiniPollKind.multipleChoice,
          allowReanswer: true,
          answer: const StoryPollAnswer(optionIds: <int>[1, 3]),
        ),
      )..reanswer();
      expect(poll.selected, <int>{1, 3});
      expect(poll.canSubmit, isTrue);
      poll
        ..toggle(1)
        ..submitChoices();
      expect(transport.calls.single.$3['option_ids'], <int>[3]);
    });

    test(
      'a scale keeps the previous rate lit until a new one is sent',
      () async {
        final poll = mount(
          _scale(
            StoryPollType.nps,
            allowReanswer: true,
            answer: const StoryPollAnswer(rate: 3),
          ),
        )..reanswer();
        expect(poll.answered, isFalse);
        expect(poll.rateValue, 3);
        poll.rate(8);
        expect(poll.rateValue, 8);
        await fail(0);
        expect(poll.rateValue, 3, reason: 'restored after an error');
      },
    );

    test('a re-answer: the reply results replace those of the feed', () async {
      final poll = mount(
        _mini(
          StoryMiniPollKind.singleChoice,
          allowReanswer: true,
          answer: _answered,
          results: _results,
        ),
      )..reanswer();
      poll.choose(1);
      await reply(
        0,
        const StoryPollReply(answer: StoryPollAnswer(optionIds: <int>[1])),
      );
      expect(poll.answer!.optionIds, <int>[1]);
      expect(poll.results, isNull, reason: 'no results in the reply');
    });

    test('text: an empty field again', () {
      final poll = mount(
        _mini(
          StoryMiniPollKind.text,
          allowReanswer: true,
          answer: const StoryPollAnswer(text: 'Букварь'),
        ),
      );
      expect(poll.answer!.text, 'Букварь');
      poll.reanswer();
      expect(poll.showsField, isTrue);
      expect(poll.text, isEmpty);
    });
  });

  group('texts', () {
    test('labels of the element > texts of the host > built-in', () {
      const host = StoryPollTexts(
        reanswer: 'Answer again',
        error: 'Ошибка',
        submit: '',
      );
      final texts = host.forPoll(
        _mini(
          StoryMiniPollKind.singleChoice,
          labels: const StoryPollLabels(reanswer: 'Ещё раз'),
        ),
        language: 'en',
      );
      expect(texts.reanswer, 'Ещё раз');
      expect(texts.error, 'Ошибка');
      expect(texts.submit, 'Send', reason: 'an empty host text — built-in');
      final en = const StoryPollTexts().forPoll(
        _scale(StoryPollType.nps),
        language: 'de',
      );
      expect(en, StoryPollTexts.en);
      expect(
        (en.reanswer, en.error, en.submit),
        ('Answer again', 'Failed to send the answer. Please try again', 'Send'),
      );
      final ru = const StoryPollTexts().forPoll(
        _scale(StoryPollType.nps),
        language: 'ru',
      );
      expect(
        (ru.reanswer, ru.error, ru.submit),
        (
          'Ответить заново',
          'Не удалось отправить ответ. Попробуйте еще раз',
          'Отправить',
        ),
      );
      expect(
        mount(_mini(StoryMiniPollKind.text), texts: host).textsFor('ru').error,
        'Ошибка',
      );
      expect(
        mount(_mini(StoryMiniPollKind.text), texts: host).textsFor('ru').submit,
        'Отправить',
        reason: 'no untranslated fallback in a Russian UI',
      );
    });

    test('labels: submit too; null or not an object — the host texts', () {
      StoryPollTexts parse(Object? labels) =>
          const StoryPollTexts(
            reanswer: 'Again',
            error: 'Oops',
            submit: 'Go',
          ).forPoll(
            StoryPollElement.tryParse(<String, dynamic>{
              'type': 'poll',
              'poll_type': 'mini_poll',
              'labels': labels,
              'poll': <String, dynamic>{'code': 'x', 'kind': 'multiple_choice'},
            })!,
          );
      final labelled = parse(<String, dynamic>{
        'reanswer': 'Ответить заново',
        'error': '',
        'submit': 'Отправить',
      });
      expect(
        (labelled.reanswer, labelled.error, labelled.submit),
        ('Ответить заново', 'Oops', 'Отправить'),
      );
      for (final labels in <Object?>[null, 'x', <Object?>[]]) {
        final texts = parse(labels);
        expect(
          (texts.reanswer, texts.error, texts.submit),
          ('Again', 'Oops', 'Go'),
        );
      }
    });
  });

  group('saved answers', () {
    late DateTime now;
    late StoryPollStore store;

    setUp(() async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      now = DateTime(2026, 11, 20);
      store = StoryPollStore.instance = StoryPollStore(clock: () => now);
      await store.load();
    });

    const place = (shopId: 'shop', did: 'did-1', storyId: '5', slideId: '101');
    const key =
        'personalization.storiesPolls.shop.stories_poll_did-1_mini_poll_'
        'gift_recipient_5_101';

    StoryPollController mountAt(
      StoryPollElement poll, {
      String did = 'did-1',
    }) => StoryPollController(
      poll: poll,
      storyId: '5',
      slideId: '101',
      transport: transport,
      shopId: 'shop',
      did: did,
      onHold: holds.add,
    );

    test('the key: did, kind, code, story and slide; no did — no key', () {
      final poll = _mini(StoryMiniPollKind.singleChoice);
      expect(StoryPollStore.keyOf(poll, place), key);
      expect(
        StoryPollStore.keyOf(_scale(StoryPollType.nps), (
          shopId: 'shop',
          did: 'd',
          storyId: '39',
          slideId: '39_0',
        )),
        'personalization.storiesPolls.shop.stories_poll_d_nps_delivery_39_39_0',
      );
      expect(
        StoryPollStore.keyOf(poll, (
          shopId: 'shop',
          did: '',
          storyId: '5',
          slideId: '101',
        )),
        isNull,
      );
    });

    test('a sent answer is saved with its results and the time', () async {
      mountAt(_mini(StoryMiniPollKind.singleChoice)).choose(2);
      await reply(
        0,
        const StoryPollReply(
          answer: StoryPollAnswer(id: 77, optionIds: <int>[2]),
          results: _results,
        ),
      );
      final preferences = await SharedPreferences.getInstance();
      expect(jsonDecode(preferences.getString(key)!), <String, dynamic>{
        'answer': <String, dynamic>{
          'id': 77,
          'option_ids': <int>[2],
        },
        'results': <String, dynamic>{
          'total': 120,
          'options': <Map<String, dynamic>>[
            <String, dynamic>{'id': 1, 'percent': 40.0},
            <String, dynamic>{'id': 2, 'percent': 60.0},
          ],
        },
        'saved_at': now.millisecondsSinceEpoch,
      });
      // A new feed without an answer — the saved one; another slide — none.
      final again = mountAt(_mini(StoryMiniPollKind.singleChoice));
      expect(again.answered, isTrue);
      expect(again.answer!.optionIds, <int>[2]);
      expect(again.results!.percentOf(2), 60);
      expect(
        StoryPollController(
          poll: _mini(StoryMiniPollKind.singleChoice),
          storyId: '5',
          slideId: '102',
          transport: transport,
          shopId: 'shop',
          did: 'did-1',
        ).answered,
        isFalse,
      );
      expect(
        mountAt(_mini(StoryMiniPollKind.singleChoice), did: 'did-2').answered,
        isFalse,
        reason: 'another device',
      );
    });

    test('the answer of the feed wins over the saved one', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        key: jsonEncode(<String, dynamic>{
          'answer': <String, dynamic>{
            'option_ids': <int>[1],
          },
          'results': null,
          'saved_at': now.millisecondsSinceEpoch,
        }),
      });
      store = StoryPollStore.instance = StoryPollStore(clock: () => now);
      await store.load();
      final feed = mountAt(
        _mini(StoryMiniPollKind.singleChoice, answer: _answered),
      );
      expect(feed.answer!.optionIds, <int>[2]);
      final saved = mountAt(_mini(StoryMiniPollKind.singleChoice));
      expect(saved.answer!.optionIds, <int>[1]);
    });

    test(
      'after a send the element shows the sent answer, also over the feed',
      () async {
        final element = _mini(
          StoryMiniPollKind.singleChoice,
          allowReanswer: true,
          answer: _answered,
        );
        mountAt(element)
          ..reanswer()
          ..choose(3);
        await reply(0, const StoryPollReply(results: _results));
        expect(mountAt(element).answer!.optionIds, <int>[3]);
        // A new feed with the answer — the feed's.
        expect(
          mountAt(
            _mini(StoryMiniPollKind.singleChoice, answer: _answered),
          ).answer!.optionIds,
          <int>[2],
        );
      },
    );

    test(
      'without a did nothing is written, the element still shows it',
      () async {
        final element = _mini(StoryMiniPollKind.text);
        mountAt(element, did: '')
          ..text = 'Книга'
          ..submitText();
        await reply(0);
        final preferences = await SharedPreferences.getInstance();
        expect(preferences.getKeys(), isEmpty);
        expect(mountAt(element, did: '').answer!.text, 'Книга');
        expect(
          mountAt(_mini(StoryMiniPollKind.text), did: '').answered,
          isFalse,
        );
      },
    );

    test('90 days: older or undated records are deleted on read', () async {
      Future<StoryPollController> withRecord(Object? savedAt) async {
        SharedPreferences.setMockInitialValues(<String, Object>{
          key: jsonEncode(<String, dynamic>{
            'answer': <String, dynamic>{'text': 'a'},
            'saved_at': ?savedAt,
          }),
        });
        store = StoryPollStore.instance = StoryPollStore(clock: () => now);
        await store.load();
        return mountAt(_mini(StoryMiniPollKind.text));
      }

      final fresh = now.subtract(const Duration(days: 90));
      expect((await withRecord(fresh.millisecondsSinceEpoch)).answered, isTrue);
      expect(
        (await withRecord(fresh.millisecondsSinceEpoch - 1)).answered,
        isFalse,
      );
      expect((await SharedPreferences.getInstance()).getKeys(), isEmpty);
      expect((await withRecord(null)).answered, isFalse, reason: 'undated');
      expect((await SharedPreferences.getInstance()).getKeys(), isEmpty);
      expect((await withRecord('1')).answered, isFalse);
    });

    test(
      'a store opened later shows the saved answer to a pristine card',
      () async {
        SharedPreferences.setMockInitialValues(<String, Object>{
          key: jsonEncode(<String, dynamic>{
            'answer': <String, dynamic>{'text': 'a'},
            'saved_at': now.millisecondsSinceEpoch,
          }),
        });
        StoryPollStore.instance = StoryPollStore(clock: () => now);
        final poll = mountAt(_mini(StoryMiniPollKind.text));
        expect(poll.answered, isFalse);
        await pumpEventQueue();
        expect(poll.answered, isTrue);
        expect(poll.answer!.text, 'a');
      },
    );

    test(
      'a reply after the card is gone: only the store, no hold change',
      () async {
        final poll = mountAt(_mini(StoryMiniPollKind.singleChoice));
        var notified = 0;
        poll
          ..addListener(() => notified++)
          ..choose(1);
        expect(holds, <bool>[true]);
        poll.dispose();
        expect(holds, <bool>[true, false], reason: 'a gone card does not hold');
        notified = 0;
        await reply(0);
        expect(notified, 0);
        expect(holds, <bool>[true, false]);
        expect(mountAt(_mini(StoryMiniPollKind.singleChoice)).answered, isTrue);
      },
    );
  });

  group('hold', () {
    test('while pressed', () {
      final poll = mount(_mini(StoryMiniPollKind.multipleChoice))
        ..pressed = true;
      poll.pressed = true;
      expect(holds, <bool>[true]);
      poll.pressed = false;
      expect(holds, <bool>[true, false]);
    });

    test('while the field is focused, pressing does not resume', () {
      final poll = mount(_mini(StoryMiniPollKind.text))..focused = true;
      expect(holds, <bool>[true]);
      poll
        ..text = 'a'
        ..pressed = true
        ..pressed = false;
      expect(holds, <bool>[true], reason: 'still focused');
      poll.focused = false;
      expect(holds, <bool>[true, false]);
    });

    test('while sending, then resumes', () async {
      final poll = mount(_scale(StoryPollType.nps))..rate(10);
      expect(holds, <bool>[true]);
      await reply(0);
      expect(holds, <bool>[true, false]);
      expect(poll.holding, isFalse);
    });

    test('a sent text resumes: the field is gone with its focus', () async {
      final poll = mount(_mini(StoryMiniPollKind.text))
        ..focused = true
        ..text = 'Книга'
        ..submitText();
      expect(holds, <bool>[true]);
      await reply(0);
      expect(poll.showsField, isFalse);
      expect(holds, <bool>[true, false]);
    });

    test('a failed send lets go when the focus left while sending', () async {
      final poll = mount(_mini(StoryMiniPollKind.text))
        ..focused = true
        ..text = 'Книга'
        ..submitText()
        ..focused = false;
      expect(holds, <bool>[true], reason: 'still sending');
      await fail(0);
      expect(poll.showsField, isTrue);
      expect(holds, <bool>[true, false]);
    });

    test('only on a live slide', () {
      final poll = StoryPollController(
        poll: _mini(StoryMiniPollKind.singleChoice),
        storyId: '5',
        slideId: '101',
        transport: transport,
        onHold: holds.add,
        active: false,
      )..pressed = true;
      expect(holds, isEmpty);
      poll.active = true;
      expect(holds, <bool>[true]);
      poll.active = false;
      expect(holds, <bool>[true, false]);
    });
  });

  test('the poll pause goes away with the slide', () {
    final slides = <StorySlide>[
      for (final id in <String>['1', '2'])
        StorySlide(id: id, type: StorySlideType.image),
    ];
    final playback = StoriesPlayback(
      stories: <Story>[Story(id: 's', name: 's', avatar: '', slides: slides)],
    )..settle(0);
    playback
      ..mediaReady(playback.generation)
      ..pause(StoriesPauseReason.poll);
    expect(playback.running, isFalse);
    expect(playback.next(), StoriesStep.slide);
    expect(playback.pausedBy(StoriesPauseReason.poll), isFalse);
  });
}
