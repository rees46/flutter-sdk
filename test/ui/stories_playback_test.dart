import 'package:flutter_test/flutter_test.dart';
import 'package:rees46_sdk/src/stories/stories_response.dart';
import 'package:rees46_sdk/src/ui/widgets/stories_playback.dart';

/// A story with [count] slides `<id>0`, `<id>1`, … lasting 5 s each.
Story _story(String id, int count, {bool viewed = false, int start = 0}) =>
    Story(
      id: id,
      name: id,
      avatar: '',
      viewed: viewed,
      startPosition: start,
      slides: <StorySlide>[
        for (var i = 0; i < count; i++)
          StorySlide(
            id: '$id$i',
            type: StorySlideType.image,
            duration: const Duration(seconds: 5),
          ),
      ],
    );

/// A story of the new feed: `m` — a media slide, `s` — a skipped one (no media, no
/// product), in [kinds] order; ids `<id>0`, `<id>1`, …
Story _feedStory(String id, String kinds, {int start = 0}) => Story(
  id: id,
  name: id,
  avatar: '',
  startPosition: start,
  slides: <StorySlide>[
    for (var i = 0; i < kinds.length; i++)
      StorySlide(
        id: '$id$i',
        type: kinds[i] == 'm' ? StorySlideType.image : StorySlideType.product,
        duration: const Duration(seconds: 5),
      ),
  ],
);

/// Opens [playback] the way the viewer does: the first page settles, media is ready.
StoriesPlayback _open(StoriesPlayback playback) {
  playback.settle(playback.storyIndex);
  playback.mediaReady(playback.generation);
  return playback;
}

void main() {
  group('start slide', () {
    test('nothing seen: the server start_position, clamped', () {
      expect(StoriesPlayback.startSlideOf(_story('a', 3, start: 2), {}), 2);
      expect(StoriesPlayback.startSlideOf(_story('a', 3, start: 9), {}), 2);
      expect(StoriesPlayback.startSlideOf(_story('a', 3, start: -1), {}), 0);
    });

    test('partly seen: the first unseen slide in order', () {
      final story = _story('a', 4, start: 3);
      expect(StoriesPlayback.startSlideOf(story, {'a0', 'a2'}), 1);
      expect(StoriesPlayback.startSlideOf(story, {'a1'}), 0);
    });

    test('viewed by the server or fully seen: the first slide', () {
      expect(
        StoriesPlayback.startSlideOf(_story('a', 3, viewed: true), {'a0'}),
        0,
      );
      final story = _story('a', 2, start: 1);
      expect(StoriesPlayback.startSlideOf(story, {'a0', 'a1'}), 0);
      expect(StoriesPlayback.isViewed(story, {'a0', 'a1'}), isTrue);
      expect(StoriesPlayback.isViewed(story, {'a0'}), isFalse);
    });
  });

  group('navigation', () {
    test('slides, then the next story on settle, then close', () {
      final playback = _open(
        StoriesPlayback(stories: [_story('a', 2), _story('b', 1)]),
      );
      expect(playback.slide.id, 'a0');

      expect(playback.next(), StoriesStep.slide);
      expect(playback.slide.id, 'a1');

      expect(playback.next(), StoriesStep.turn);
      expect(playback.turnTarget, 1);
      expect(playback.pausedBy(StoriesPauseReason.drag), isTrue);
      expect(playback.next(), StoriesStep.none, reason: 'turning');
      expect(
        playback.seenOf('b'),
        isEmpty,
        reason: 'not entered before settle',
      );

      expect(playback.settle(1), StoriesStep.slide);
      expect(playback.slide.id, 'b0');
      expect(playback.seenOf('b'), {'b0'});
      playback.mediaReady(playback.generation);

      expect(playback.next(), StoriesStep.close);
    });

    test('back on the first slide of the first story restarts it', () {
      final playback = _open(StoriesPlayback(stories: [_story('a', 2)]));
      playback.mediaReady(playback.generation);
      playback.tick(const Duration(seconds: 2));
      final generation = playback.generation;

      expect(playback.previous(), StoriesStep.restart);
      expect(playback.slide.id, 'a0');
      expect(playback.generation, generation, reason: 'no new entry');
      expect(playback.elapsed, Duration.zero);
      expect(playback.running, isTrue, reason: 'the media stays ready');
    });

    test('back into the previous story opens its start slide', () {
      final playback = _open(
        StoriesPlayback(
          stories: [_story('a', 3), _story('b', 1)],
          initialStory: 1,
          seen: {
            'a': {'a0'},
          },
        ),
      );
      expect(playback.slide.id, 'b0');
      expect(playback.previous(), StoriesStep.turn);
      expect(playback.turnTarget, 0);
      playback.settle(0);
      expect(playback.slide.id, 'a1', reason: 'the first unseen');
    });

    test('a peeked page that springs back is not entered', () {
      final playback = _open(
        StoriesPlayback(stories: [_story('a', 1), _story('b', 1)]),
      );
      playback.pause(StoriesPauseReason.drag);
      expect(playback.settle(0), StoriesStep.none);
      expect(playback.running, isTrue);
      expect(playback.seenOf('b'), isEmpty);
    });

    test('stories without slides are dropped, the index follows', () {
      final playback = StoriesPlayback(
        stories: [_story('a', 1), _story('empty', 0), _story('b', 1)],
        initialStory: 2,
      );
      expect(playback.stories.map((story) => story.id), ['a', 'b']);
      expect(playback.storyIndex, 1);
      expect(StoriesPlayback(stories: [_story('x', 0)]).isEmpty, isTrue);
    });
  });

  group('the new feed: slides with nothing to show are skipped', () {
    StoriesPlayback feed(List<Story> stories, {int initial = 0, int? slide}) =>
        StoriesPlayback(
          stories: stories,
          initialStory: initial,
          initialSlide: slide,
          serverStart: true,
        );

    test('forward passes them, back steps over them', () {
      final playback = _open(feed(<Story>[_feedStory('a', 'msm')]));
      expect(playback.slide.id, 'a0');
      expect(playback.next(), StoriesStep.slide);
      expect(playback.slide.id, 'a2');
      playback.mediaReady(playback.generation);
      expect(playback.previous(), StoriesStep.slide);
      expect(playback.slide.id, 'a0', reason: 'not bounced forward');
      expect(playback.seenOf('a'), {'a0', 'a2'}, reason: 'no entry on a1');
    });

    test('start_position on a skipped slide opens the next shown one', () {
      final playback = _open(feed(<Story>[_feedStory('a', 'msm', start: 1)]));
      expect(playback.slide.id, 'a2');
    });

    test('nothing shown after the start: finished, viewed, the next story', () {
      final a = _feedStory('a', 'ms', start: 1);
      final b = _feedStory('b', 'm');
      final playback = _open(feed(<Story>[a, b]));
      expect(playback.storyIndex, 1);
      expect(playback.slide.id, 'b0');
      expect(StoriesServerProgress.viewedOf(a), isTrue);
      expect(StoriesServerProgress.startOf(a), 0, reason: 'starts over');
    });

    test('a story of skipped slides only stays in the feed; opening it opens '
        'the next one and marks it viewed', () {
      final a = _feedStory('a', 'ss');
      final b = _feedStory('b', 'm');
      final playback = feed(<Story>[a, b]);
      expect(playback.stories, <Story>[a, b]);
      _open(playback);
      expect(playback.story, b);
      expect(StoriesServerProgress.viewedOf(a), isTrue);
      expect(StoriesServerProgress.viewedOf(b), isFalse);
    });

    test('the last one: nothing to show, the viewer is empty', () {
      final a = _feedStory('a', 'm');
      final b = _feedStory('b', 's');
      final playback = feed(<Story>[a, b], initial: 1);
      expect(playback.isEmpty, isTrue);
      expect(StoriesServerProgress.viewedOf(b), isTrue);
      expect(StoriesServerProgress.viewedOf(a), isFalse);
    });

    test(
      'forward over such a story marks it viewed; past the last — close',
      () {
        final a = _feedStory('a', 'm');
        final b = _feedStory('b', 'ss');
        final c = _feedStory('c', 'm');
        final playback = _open(feed(<Story>[a, b, c]));
        expect(playback.next(), StoriesStep.turn);
        expect(playback.turnTarget, 2);
        expect(StoriesServerProgress.viewedOf(b), isTrue);
        expect(playback.settle(2), StoriesStep.slide);
        expect(playback.story, c);

        final last = _open(
          feed(<Story>[_feedStory('x', 'm'), _feedStory('y', 's')]),
        );
        expect(last.next(), StoriesStep.close);
      },
    );

    test('a swipe onto such a story turns on to the next one, or closes', () {
      final a = _feedStory('a', 'm');
      final b = _feedStory('b', 's');
      final c = _feedStory('c', 'm');
      final playback = _open(feed(<Story>[a, b, c]));
      expect(playback.settle(1), StoriesStep.turn);
      expect(playback.turnTarget, 2);
      expect(StoriesServerProgress.viewedOf(a), isTrue, reason: 'left forward');
      expect(StoriesServerProgress.viewedOf(b), isTrue);

      final back = _open(
        feed(<Story>[_feedStory('x', 's'), _feedStory('y', 'm')]),
      );
      expect(back.story.id, 'y');
      expect(back.settle(0), StoriesStep.close, reason: 'nothing before it');
    });

    test('back over such a story marks it viewed, as forward does; nothing '
        'before it — close', () {
      final a = _feedStory('a', 'm');
      final b = _feedStory('b', 'ss');
      final c = _feedStory('c', 'm');
      final playback = _open(feed(<Story>[a, b, c], initial: 2));
      expect(playback.story, c);
      expect(playback.previous(), StoriesStep.turn);
      expect(playback.turnTarget, 0);
      expect(StoriesServerProgress.viewedOf(b), isTrue);
      expect(StoriesServerProgress.viewedOf(a), isFalse);

      final x = _feedStory('x', 's');
      final first = _open(feed(<Story>[x, _feedStory('y', 'm')], initial: 1));
      expect(first.previous(), StoriesStep.close);
      expect(StoriesServerProgress.viewedOf(x), isTrue);
    });

    test('leaving forward past the last story marks it viewed', () {
      final a = _feedStory('a', 'mm');
      final playback = _open(feed(<Story>[a]));
      playback.leaveForward();
      expect(StoriesServerProgress.viewedOf(a), isTrue);
      expect(StoriesServerProgress.startOf(a), 0, reason: 'not finished');

      final legacy = _story('l', 1);
      _open(StoriesPlayback(stories: <Story>[legacy])).leaveForward();
      expect(StoriesServerProgress.viewedOf(legacy), isFalse);
    });

    test('a link slide only sets the first open', () {
      final a = _feedStory('a', 'mmm');
      final playback = _open(feed(<Story>[a], slide: 1));
      expect(playback.slide.id, 'a1');
      expect(StoriesServerProgress.startOf(a), 1);
      playback.mediaReady(playback.generation);
      playback.next();
      expect(StoriesServerProgress.startOf(a), 2, reason: 'where it was left');

      final skipped = _feedStory('b', 'msm');
      expect(_open(feed(<Story>[skipped], slide: 1)).slide.id, 'b2');
    });
  });

  group('pause reasons and the clock', () {
    test('the clock runs only with no reason, in real deltas', () {
      final playback = StoriesPlayback(stories: [_story('a', 2)]);
      playback.settle(0);
      expect(playback.pausedBy(StoriesPauseReason.loading), isTrue);
      expect(playback.tick(const Duration(seconds: 9)), isFalse);
      expect(playback.elapsed, Duration.zero, reason: 'loading');

      playback.mediaReady(playback.generation);
      playback.pause(StoriesPauseReason.hold);
      playback.pause(StoriesPauseReason.background);
      expect(playback.tick(const Duration(seconds: 1)), isFalse);
      playback.resume(StoriesPauseReason.hold);
      expect(playback.running, isFalse, reason: 'still in the background');
      playback.resume(StoriesPauseReason.background);
      expect(playback.running, isTrue);

      // A frame gap (e.g. right after returning) counts for at most a second.
      playback.tick(const Duration(minutes: 5));
      expect(playback.elapsed, StoriesPlayback.maxTick);
      expect(playback.progress, closeTo(0.2, 1e-9));
      for (var i = 0; i < 3; i++) {
        expect(playback.tick(const Duration(seconds: 1)), isFalse);
      }
      expect(playback.tick(const Duration(seconds: 1)), isTrue);
    });

    test('a video slide lasts the video and follows its position', () {
      final playback = _open(StoriesPlayback(stories: [_story('a', 1)]));
      playback.useVideoDuration(const Duration(seconds: 30));
      expect(playback.followsVideo, isTrue);
      playback.syncVideoPosition(const Duration(seconds: 15));
      expect(playback.progress, closeTo(0.5, 1e-9));
      playback.syncVideoPosition(const Duration(seconds: 30));
      expect(
        playback.tick(const Duration(seconds: 1)),
        isFalse,
        reason: 'the video itself ends the slide',
      );
      playback.useVideoDuration(Duration.zero);
      expect(playback.duration, const Duration(seconds: 30));
    });

    test(
      'a GIF slide lasts the server time or one loop, whichever is longer',
      () {
        // The server says 5 s; an 8 s loop plays exactly once.
        final playback = _open(StoriesPlayback(stories: [_story('a', 2)]));
        playback.useGifLoop(const Duration(seconds: 8));
        expect(playback.duration, const Duration(seconds: 8));
        expect(playback.followsVideo, isFalse, reason: 'the clock ends it');
        for (var i = 0; i < 7; i++) {
          expect(playback.tick(const Duration(seconds: 1)), isFalse);
        }
        expect(playback.tick(const Duration(seconds: 1)), isTrue);

        // A 700 ms loop repeats until the server's 5 s are up.
        playback.next();
        playback.mediaReady(playback.generation);
        playback.useGifLoop(const Duration(milliseconds: 700));
        expect(playback.duration, const Duration(seconds: 5));

        // An unknown loop (a host image, a broken GIF): the server time.
        playback.useGifLoop(const Duration(seconds: 8));
        playback.useGifLoop(null);
        expect(playback.duration, const Duration(seconds: 5));
      },
    );

    test('a paused GIF slide keeps its time; retry measures it again', () {
      final playback = _open(StoriesPlayback(stories: [_story('a', 1)]));
      playback.useGifLoop(const Duration(seconds: 8));
      playback.tick(const Duration(seconds: 1));
      for (final reason in <StoriesPauseReason>[
        StoriesPauseReason.hold,
        StoriesPauseReason.sheet,
        StoriesPauseReason.background,
        StoriesPauseReason.host,
      ]) {
        playback.pause(reason);
        expect(playback.running, isFalse, reason: '$reason stops the clock');
        expect(playback.tick(const Duration(seconds: 1)), isFalse);
        playback.resume(reason);
      }
      expect(playback.elapsed, const Duration(seconds: 1));

      playback.mediaFailed(playback.generation);
      playback.retry();
      expect(
        playback.duration,
        const Duration(seconds: 5),
        reason: 'unmeasured',
      );
    });

    test('a failed load pauses until retry; old loads are ignored', () {
      final playback = StoriesPlayback(stories: [_story('a', 1)]);
      playback.settle(0);
      final first = playback.generation;
      playback.mediaFailed(first);
      expect(playback.pausedBy(StoriesPauseReason.error), isTrue);

      final second = playback.retry();
      expect(second, greaterThan(first));
      expect(playback.pausedBy(StoriesPauseReason.error), isFalse);
      expect(playback.pausedBy(StoriesPauseReason.loading), isTrue);
      playback.mediaReady(first);
      expect(playback.running, isFalse, reason: 'a stale load');
      playback.mediaReady(second);
      expect(playback.running, isTrue);
      expect(playback.seenOf('a'), {'a0'});
    });
  });

  group('products sheet', () {
    test('pauses, blocks navigation, resets on a slide change', () {
      final playback = _open(
        StoriesPlayback(stories: [_story('a', 2), _story('b', 1)]),
      );
      expect(playback.openSheet(), isTrue);
      expect(playback.running, isFalse);
      expect(playback.next(), StoriesStep.none);
      expect(playback.previous(), StoriesStep.none);
      expect(playback.slide.id, 'a0');

      expect(playback.closeSheet(), isTrue);
      expect(playback.running, isTrue);
      playback.openSheet();
      // A programmatic jump to another story closes it.
      expect(playback.turnTo(1), StoriesStep.turn);
      expect(playback.sheetOpen, isFalse);
      playback.settle(1);
      expect(playback.sheetOpen, isFalse);
    });

    test('entering a slide closes an open sheet', () {
      final playback = _open(StoriesPlayback(stories: [_story('a', 2)]));
      playback.openSheet();
      playback.closeSheet();
      playback.next();
      playback.mediaReady(playback.generation);
      playback.openSheet();
      playback.settle(0);
      expect(playback.sheetOpen, isTrue, reason: 'same story: no new entry');
      playback.closeSheet();
      playback.previous();
      expect(playback.sheetOpen, isFalse);
      expect(playback.reasons, {StoriesPauseReason.loading});
    });
  });
}
