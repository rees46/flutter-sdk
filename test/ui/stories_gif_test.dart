import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:rees46_sdk/src/ui/widgets/stories_gif.dart';

/// The fixture all four SDKs test with: 2×2, 3 frames, delays 10 / 0 / 50 hundredths
/// of a second → 100 + 100 + 500 = 700 ms per loop.
final Uint8List gifFixture = base64Decode(
  'R0lGODlhAgACAIEAAP8AAAD/AAAA/////yH/C05FVFNDQVBFMi4wAwEAAAAh+QQACgAAACwAAAAAAgACAAA'
  'CAoRRACH5BAAAAAAALAAAAAACAAIAAAICjFMAIfkEADIAAAAsAAAAAAIAAgAAAgKUVQA7',
);

void main() {
  group('StoryGif', () {
    test('the shared fixture: 3 frames, 100/100/500 ms, a 700 ms loop', () {
      expect(StoryGif.isGif(gifFixture), isTrue);
      final gif = StoryGif.parse(gifFixture)!;
      expect(gif.width, 2);
      expect(gif.height, 2);
      expect(gif.delays, const <Duration>[
        Duration(milliseconds: 100),
        Duration(milliseconds: 100),
        Duration(milliseconds: 500),
      ]);
      expect(gif.loop, const Duration(milliseconds: 700));
    });

    test('GIF87a is a GIF too; other bytes are not', () {
      final old = Uint8List.fromList(gifFixture)..[4] = 0x37; // "GIF87a"
      expect(StoryGif.isGif(old), isTrue);
      expect(StoryGif.parse(old)!.loop, const Duration(milliseconds: 700));

      const png = <int>[0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0, 0];
      expect(StoryGif.isGif(png), isFalse);
      expect(StoryGif.parse(png), isNull);
      expect(StoryGif.isGif(ascii.encode('GIF90a')), isFalse);
      expect(
        StoryGif.isGif(ascii.encode('GIF8')),
        isFalse,
        reason: 'too short',
      );
      expect(StoryGif.parse(<int>[]), isNull);
    });

    test('a delay below 20 ms counts as 100 ms, the browser rule', () {
      expect(StoryGif.frameDelay(Duration.zero), StoryGif.shortDelay);
      expect(
        StoryGif.frameDelay(const Duration(milliseconds: 10)),
        const Duration(milliseconds: 100),
      );
      expect(
        StoryGif.frameDelay(const Duration(milliseconds: 19)),
        const Duration(milliseconds: 100),
      );
      expect(
        StoryGif.frameDelay(const Duration(milliseconds: 20)),
        const Duration(milliseconds: 20),
      );
    });

    test('a broken GIF has no known loop', () {
      // Cut inside the second frame.
      final cut = StoryGif.parse(gifFixture.sublist(0, 80))!;
      expect(StoryGif.isGif(gifFixture.sublist(0, 80)), isTrue);
      expect(cut.loop, isNull);
      // An unknown block.
      final garbled = Uint8List.fromList(gifFixture)..[0x2C] = 0x99;
      expect(StoryGif.parse(garbled)!.loop, isNull);
      // A header alone: no frames.
      expect(StoryGif.parse(gifFixture.sublist(0, 13))!.loop, isNull);
    });

    test(
      'a GIF that ends after its last frame without a trailer still counts',
      () {
        final noTrailer = gifFixture.sublist(0, gifFixture.length - 1);
        expect(
          StoryGif.parse(noTrailer)!.loop,
          const Duration(milliseconds: 700),
        );
      },
    );
  });
}
