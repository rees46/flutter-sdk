import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rees46_sdk/src/ui/personalization_ui.dart';
import 'package:rees46_sdk/src/ui/widgets/stories_gif.dart';
import 'package:rees46_sdk/src/ui/widgets/stories_image.dart';

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

  group('StoryImage', () {
    setUp(() {
      StoriesImageBytes.instance = StoriesImageBytes(
        fetch: (_) async => gifFixture,
      );
    });
    tearDown(() => StoriesImageBytes.instance = StoriesImageBytes());

    test('a GIF codec gives its first frame only, again and again', () async {
      final codec = await ui.instantiateImageCodec(gifFixture);
      final frames = <List<int>>[
        for (var i = 0; i < 3; i++)
          await _pixel((await codec.getNextFrame()).image),
      ];
      expect(frames[0], isNot(frames[1]), reason: 'the fixture frames differ');

      final still = StoryImage.firstFrame(
        await ui.instantiateImageCodec(gifFixture),
      );
      expect(still.frameCount, 1);
      expect(still.repetitionCount, 0);
      for (var i = 0; i < 4; i++) {
        expect(await _pixel((await still.getNextFrame()).image), frames[0]);
      }
      still.dispose();
    });

    testWidgets('a GIF cover shows its first frame', (tester) async {
      const image = StoryImage('https://cdn.example/cover.gif');
      final emitted = <ui.Image>[];
      final listener = ImageStreamListener(
        (info, _) => emitted.add(info.image),
      );
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: Center(child: PersonalizationStoryCover(image: image)),
        ),
      );
      final stream = image.resolve(ImageConfiguration.empty)
        ..addListener(listener);
      addTearDown(() => stream.removeListener(listener));

      // Decoding is real async; give a 700 ms loop time to come round twice.
      final first = await tester.runAsync(() async {
        await precacheImage(image, tester.element(find.byType(Center)));
        await Future<void>.delayed(const Duration(milliseconds: 1500));
        final codec = await ui.instantiateImageCodec(gifFixture);
        return _pixel((await codec.getNextFrame()).image);
      });
      await tester.pump();

      expect(emitted, hasLength(1), reason: 'one frame, no animation');
      final shown = tester.widget<RawImage>(find.byType(RawImage)).image!;
      expect(await tester.runAsync(() => _pixel(shown)), first);
    });

    testWidgets('other formats stay as NetworkImage draws them', (
      tester,
    ) async {
      final png = base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
      );
      StoriesImageBytes.instance = StoriesImageBytes(fetch: (_) async => png);
      const image = StoryImage('https://cdn.example/photo.png');
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: Center(child: PersonalizationStoryCover(image: image)),
        ),
      );
      await tester.runAsync(
        () => precacheImage(image, tester.element(find.byType(Center))),
      );
      await tester.pump();
      final shown = tester.widget<RawImage>(find.byType(RawImage)).image!;
      expect(shown.width, 1);
      expect(const StoryImage('a'), const StoryImage('a'));
      expect(const StoryImage('a'), isNot(const StoryImage('b')));
    });
  });
}

/// The RGBA of the top-left pixel of [image].
Future<List<int>> _pixel(ui.Image image) async {
  final data = await image.toByteData();
  return data!.buffer.asUint8List(0, 4).toList();
}
