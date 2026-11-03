import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rees46_sdk/src/stories/stories_response.dart';

/// The shared feed of every platform: campaign 9001 with all six kinds, an answered
/// choice with results and an unknown `quiz`; numbers partly come as strings.
StoriesBlock _fixture() {
  final json =
      jsonDecode(
            File('test/fixtures/stories_polls_feed.json').readAsStringSync(),
          )
          as Map<String, dynamic>;
  return StoriesBlock.fromJson(json['payload'] as Map<String, dynamic>);
}

StoryPollElement? _poll(StorySlide slide) =>
    slide.elements.whereType<StoryPollElement>().firstOrNull;

StorySlide _slide(List<Map<String, dynamic>> elements, {String id = '1'}) =>
    StorySlide.fromJson(<String, dynamic>{
      'id': id,
      'type': 'image',
      'elements': elements,
    });

void main() {
  test(
    'the fixture: all six kinds, an answered one, the unknown one dropped',
    () {
      final slides = _fixture().stories.single.slides;
      expect(slides, hasLength(8));
      final polls = slides.map(_poll).toList();
      expect(
        polls.map((poll) => (poll?.pollType, poll?.kind)).toList(),
        <(StoryPollType?, StoryMiniPollKind?)>[
          (StoryPollType.miniPoll, StoryMiniPollKind.singleChoice),
          (StoryPollType.miniPoll, StoryMiniPollKind.multipleChoice),
          (StoryPollType.miniPoll, StoryMiniPollKind.text),
          (StoryPollType.nps, null),
          (StoryPollType.csat, null),
          (StoryPollType.ces, null),
          (StoryPollType.miniPoll, StoryMiniPollKind.singleChoice),
          (null, null),
        ],
      );
      expect(slides.last.elements, isEmpty, reason: '"quiz" is not drawn');
      expect(polls.map((poll) => poll?.yOffset).toList(), <double?>[
        50, 40, 30, 60, 90, 5, 50, null, //
      ]);
    },
  );

  test('a single choice with labels', () {
    final poll = _poll(_fixture().stories.single.slides[0])!;
    expect(poll.code, 'demo_single');
    expect(poll.question, 'Что вам больше нравится?');
    expect(poll.allowReanswer, isTrue);
    expect(poll.showResults, isTrue);
    expect(poll.submitLabel, isEmpty);
    expect(poll.thanksText, 'Спасибо за ответ!');
    expect(poll.options.map((option) => (option.id, option.label)), [
      (1, 'Кроссовки'),
      (2, 'Ботинки'),
      (3, 'Сандалии'),
    ]);
    expect(poll.labels.reanswer, 'Ответить заново');
    expect(poll.labels.error, 'Не удалось отправить ответ. Попробуйте еще раз');
    expect(poll.labels.submit, isNull);
    expect(poll.answer, isNull);
    expect(poll.results, isNull);
  });

  test('numbers as strings: y_offset, max_length, rate_min / rate_max', () {
    final slides = _fixture().stories.single.slides;
    expect(_poll(slides[1])!.yOffset, 40);
    final text = _poll(slides[2])!;
    expect(text.maxLength, 120);
    expect(text.placeholder, 'Ваш ответ');
    expect(text.showResults, isFalse);
    final ces = _poll(slides[5])!;
    expect((ces.rateMin, ces.rateMax), (1, 7));
    expect(ces.bands, isEmpty);
    expect(ces.channel, 'stories');
  });

  test('scales: channel, ranges and bands; nulls stay unset', () {
    final slides = _fixture().stories.single.slides;
    final nps = _poll(slides[3])!;
    expect(nps.code, 'test');
    expect(nps.channel, 'test');
    expect((nps.rateMin, nps.rateMax), (0, 10));
    expect(nps.bands.map((band) => (band.from, band.to, band.success)), [
      (0, 6, 'Спасибо, мы станем лучше'),
      (7, 8, 'Спасибо за оценку'),
      (9, 10, 'Спасибо, мы рады!'),
    ]);
    final csat = _poll(slides[4])!;
    expect(csat.channel, isEmpty);
    expect((csat.rateMin, csat.rateMax), (null, null));
    expect(csat.labels.reanswer, isNull);
    expect(csat.allowReanswer, isFalse);
  });

  test('an answer and results from the feed', () {
    final poll = _poll(_fixture().stories.single.slides[6])!;
    expect(poll.answer!.id, 77);
    expect(poll.answer!.optionIds, <int>[2]);
    expect(poll.answer!.text, isNull);
    expect(poll.answer!.isAnswered, isTrue);
    expect(poll.results!.total, 120);
    expect(poll.results!.percentOf(1), 40);
    expect(poll.results!.percentOf(2), 60);
    expect(poll.results!.percentOf(3), 0);
  });

  test('isAnswered: options, text or a rate', () {
    expect(const StoryPollAnswer().isAnswered, isFalse);
    expect(const StoryPollAnswer(optionIds: <int>[]).isAnswered, isFalse);
    expect(const StoryPollAnswer(text: '').isAnswered, isFalse);
    expect(const StoryPollAnswer(optionIds: <int>[1]).isAnswered, isTrue);
    expect(const StoryPollAnswer(text: 'a').isAnswered, isTrue);
    expect(const StoryPollAnswer(rate: 0).isAnswered, isTrue);
    expect(StoryPollAnswer.tryParse(<String, dynamic>{'rate': '3'})!.rate, 3);
    expect(StoryPollAnswer.tryParse('x'), isNull);
    // A blank text is still an answer: only "" is empty.
    expect(const StoryPollAnswer(text: ' ').isAnswered, isTrue);
  });

  test('any numeric rate is an answer, a fractional one too', () {
    StoryPollAnswer? rate(Object? value) =>
        StoryPollAnswer.tryParse(<String, dynamic>{'rate': value});
    expect(rate(9.5)!.rate, 9.5);
    expect(rate(9.5)!.isAnswered, isTrue);
    expect(rate('6.5')!.rate, 6.5);
    expect(rate('7')!.rate, 7);
    for (final value in <Object?>[null, 'x', 'NaN', true]) {
      expect(rate(value)!.isAnswered, isFalse, reason: '$value');
    }
  });

  test('blank strings are not empty: shown, sent and override', () {
    final poll = StoryPollElement.tryParse(<String, dynamic>{
      'type': 'poll',
      'poll_type': 'mini_poll',
      'labels': <String, dynamic>{'reanswer': ' ', 'error': '', 'submit': ' '},
      'poll': <String, dynamic>{
        'code': 'x',
        'kind': 'text',
        'question': ' ',
        'placeholder': ' ',
        'submit_label': ' ',
        'thanks_text': ' ',
      },
    })!;
    expect(<String>[
      poll.question,
      poll.placeholder,
      poll.submitLabel,
      poll.thanksText,
    ], everyElement(' '));
    expect(
      (poll.labels.reanswer, poll.labels.error, poll.labels.submit),
      (' ', null, ' '),
    );
    final scale = StoryPollElement.tryParse(<String, dynamic>{
      'type': 'poll',
      'poll_type': 'nps',
      'poll': <String, dynamic>{
        'code': 'x',
        'channel': ' ',
        'bands': <Object?>[
          <String, dynamic>{'from': 0, 'to': 10, 'success': ' '},
        ],
      },
    })!;
    expect(scale.channel, ' ');
    expect(scale.bands.single.success, ' ');
  });

  test('a product slide keeps its poll; broken elements do not break it', () {
    final slide = _slide(id: '39_0', <Map<String, dynamic>>[
      <String, dynamic>{'type': 'poll', 'poll_type': 'nps', 'poll': null},
      <String, dynamic>{'type': 'poll', 'poll_type': 'mini_poll', 'poll': 5},
      <String, dynamic>{
        'type': 'poll',
        'poll_type': 'mini_poll',
        'poll': <String, dynamic>{'code': 'x', 'kind': 'rating'},
      },
      <String, dynamic>{
        'type': 'poll',
        'poll_type': 'mini_poll',
        'y_offset': 'top',
        'allow_reanswer': null,
        'labels': <String, dynamic>{'reanswer': '', 'submit': 7},
        'poll': <String, dynamic>{
          'code': 15,
          'kind': 'multiple_choice',
          'max_length': 0,
          'options': <Object?>[
            <String, dynamic>{'id': '4', 'label': 'Four'},
            <String, dynamic>{'label': 'no id'},
            null,
          ],
        },
        'answer': <String, dynamic>{
          'option_ids': <Object?>['4', null],
        },
        'results': <String, dynamic>{
          'options': <Object?>[
            <String, dynamic>{'id': 4, 'percent': '99.6'},
          ],
        },
      },
    ]);
    expect(slide.id, '39_0');
    final poll = _poll(slide)!;
    expect(slide.elements, hasLength(1));
    expect(poll.code, '15');
    expect(poll.yOffset, isNull);
    expect(poll.allowReanswer, isFalse);
    expect(poll.maxLength, isNull);
    expect(poll.options.map((option) => option.id), <int>[4]);
    expect(poll.labels.reanswer, isNull);
    expect(poll.labels.submit, isNull);
    expect(poll.answer!.optionIds, <int>[4]);
    expect(poll.results!.percentOf(4), 100);
  });

  test('every optional field null: a mini poll and a scale still parse', () {
    final mini = StoryPollElement.tryParse(<String, dynamic>{
      'type': 'poll',
      'poll_type': 'mini_poll',
      'y_offset': null,
      'allow_reanswer': null,
      'labels': null,
      'poll': <String, dynamic>{
        'code': null,
        'kind': 'text',
        'question': null,
        'placeholder': null,
        'max_length': null,
        'submit_label': null,
        'thanks_text': null,
        'show_results': null,
        'options': null,
      },
      'answer': null,
      'results': null,
    })!;
    expect(mini.kind, StoryMiniPollKind.text);
    expect(mini.code, isEmpty, reason: 'no code — an empty one, still drawn');
    expect(mini.yOffset, isNull);
    expect(mini.allowReanswer, isFalse);
    expect(mini.showResults, isFalse);
    expect(<String>[
      mini.question,
      mini.placeholder,
      mini.submitLabel,
      mini.thanksText,
    ], everyElement(isEmpty));
    expect(mini.maxLength, isNull);
    expect(mini.options, isEmpty);
    expect(mini.answer, isNull);
    expect(mini.results, isNull);
    expect(
      (mini.labels.reanswer, mini.labels.error, mini.labels.submit),
      (null, null, null),
    );

    final scale = StoryPollElement.tryParse(<String, dynamic>{
      'type': 'poll',
      'poll_type': 'ces',
      'poll': <String, dynamic>{
        'code': 'support',
        'channel': null,
        'name': null,
        'rate_min': null,
        'rate_max': null,
        'question': null,
        'bands': <Object?>[
          <String, dynamic>{'from': 1, 'to': 7, 'success': null},
          null,
        ],
      },
      'answer': <String, dynamic>{'rate': null},
    })!;
    expect(scale.kind, isNull);
    expect((scale.channel, scale.name, scale.question), ('', '', ''));
    expect((scale.rateMin, scale.rateMax), (null, null));
    expect(scale.bands.single.success, isNull);
    expect(scale.answer!.isAnswered, isFalse);
  });

  test('flags: only true, 1 or "true"', () {
    bool reanswer(Object? value) => StoryPollElement.tryParse(<String, dynamic>{
      'type': 'poll',
      'poll_type': 'nps',
      'allow_reanswer': value,
      'poll': <String, dynamic>{'code': 'x'},
    })!.allowReanswer;
    expect(<Object?>[true, 1, 1.0, 'true'].map(reanswer), everyElement(isTrue));
    expect(
      <Object?>[
        false,
        0,
        2,
        '1',
        'yes',
        'True',
        'TRUE',
        ' true',
        null,
        <Object?>[],
      ].map(reanswer),
      everyElement(isFalse),
    );
  });

  test('scale bounds: whole numbers only, also as strings', () {
    (int?, int?) bounds(Object? min, Object? max) {
      final poll = StoryPollElement.tryParse(<String, dynamic>{
        'type': 'poll',
        'poll_type': 'nps',
        'poll': <String, dynamic>{
          'code': 'x',
          'rate_min': min,
          'rate_max': max,
        },
      })!;
      return (poll.rateMin, poll.rateMax);
    }

    expect(bounds(2, '9'), (2, 9));
    expect(bounds(1.0, '7.0'), (1, 7));
    expect(bounds(2.5, '3.5'), (null, null), reason: 'not whole — defaults');
    expect(bounds('x', true), (null, null));
  });

  test('results: percents rounded and clamped, a missing one 0', () {
    final results = StoryPollResults.tryParse(<String, dynamic>{
      'total': '7',
      'options': <Object?>[
        <String, dynamic>{'id': 1, 'percent': 40.5},
        <String, dynamic>{'id': 2, 'percent': 120},
        <String, dynamic>{'id': 3, 'percent': -3},
        <String, dynamic>{'id': 4, 'percent': 'NaN'},
        <String, dynamic>{'id': 5, 'percent': 'Infinity'},
        <String, dynamic>{'id': 6, 'percent': null},
        <String, dynamic>{'id': '7', 'percent': '33.4'},
      ],
    })!;
    expect(results.total, 7);
    expect(
      <int?>[for (var id = 1; id <= 8; id++) results.percentOf(id)],
      <int?>[41, 100, 0, 0, 100, 0, 33, 0],
    );
  });

  test('results without an options array have no percents', () {
    for (final options in <Object?>[null, 'x', <String, dynamic>{}]) {
      final results = StoryPollResults.tryParse(<String, dynamic>{
        'total': 3,
        'options': options,
      })!;
      expect(results.options, isNull);
      expect(results.percentOf(1), isNull);
    }
    expect(const StoryPollResults().percentOf(1), isNull);
    expect(
      const StoryPollResults(
        options: <({int id, double percent})>[],
      ).percentOf(1),
      0,
    );
  });

  test('y_offset: a number or a numeric string, otherwise unset', () {
    double? offset(Object? value) =>
        StoryPollElement.tryParse(<String, dynamic>{
          'type': 'poll',
          'poll_type': 'csat',
          'y_offset': value,
          'poll': <String, dynamic>{'code': 'x'},
        })!.yOffset;
    expect(<Object?>[35, '35', 35.0].map(offset), everyElement(35));
    expect(
      <Object?>[null, 'top', 'NaN', 'Infinity', double.nan].map(offset),
      everyElement(isNull),
    );
    expect(offset(-20), -20, reason: 'clamped when laid out');
  });

  test('poll_type and kind as they are: no trimming, case matters', () {
    StoryPollElement? parse(String type, [String? kind]) =>
        StoryPollElement.tryParse(<String, dynamic>{
          'type': 'poll',
          'poll_type': type,
          'poll': <String, dynamic>{'code': 'x', 'kind': kind},
        });
    expect(parse('nps'), isNotNull);
    expect(parse('mini_poll', 'single_choice'), isNotNull);
    for (final type in <String>[' nps', 'NPS', 'csat ']) {
      expect(parse(type), isNull, reason: type);
    }
    for (final kind in <String>['Single_choice', 'text ', ' text']) {
      expect(parse('mini_poll', kind), isNull, reason: kind);
    }
  });

  test('options: a whole id stays, no label is an empty one', () {
    final poll = StoryPollElement.tryParse(<String, dynamic>{
      'type': 'poll',
      'poll_type': 'mini_poll',
      'poll': <String, dynamic>{
        'code': 'x',
        'kind': 'single_choice',
        'options': <Object?>[
          <String, dynamic>{'id': 1},
          <String, dynamic>{'id': '2', 'label': null},
          <String, dynamic>{'id': 3.0, 'label': 'Three'},
          <String, dynamic>{'id': 1.5, 'label': 'Half'},
          <String, dynamic>{'id': '2.5', 'label': 'Half'},
          <String, dynamic>{'id': 'x', 'label': 'X'},
          <String, dynamic>{'label': 'No id'},
        ],
      },
      'answer': <String, dynamic>{
        'option_ids': <Object?>[2, 1.5, '3'],
      },
    })!;
    expect(poll.options.map((option) => (option.id, option.label)), [
      (1, ''),
      (2, ''),
      (3, 'Three'),
    ]);
    expect(poll.answer!.optionIds, <int>[2, 3]);
  });

  test('unknown kinds and types are logged and dropped', () {
    final logs = <String>[];
    final print = debugPrint;
    debugPrint = (message, {wrapWidth}) => logs.add(message ?? '');
    addTearDown(() => debugPrint = print);
    final slide = _slide(<Map<String, dynamic>>[
      <String, dynamic>{
        'type': 'poll',
        'poll_type': 'emoji',
        'poll': <String, dynamic>{'code': 'x'},
      },
      <String, dynamic>{
        'type': 'poll',
        'poll_type': 'mini_poll',
        'poll': <String, dynamic>{'code': 'x', 'kind': 'quiz'},
      },
      <String, dynamic>{'type': 'text_block', 'text_input': 'Hi'},
    ]);
    expect(slide.elements.single, isA<StoryTextBlockElement>());
    expect(logs, hasLength(2));
    expect(logs.first, contains('"emoji"'));
    expect(logs.last, contains('"quiz"'));
  });
}
