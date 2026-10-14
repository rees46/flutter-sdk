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

      expect(playback.settle(1), isTrue);
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
      expect(playback.settle(0), isFalse);
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
