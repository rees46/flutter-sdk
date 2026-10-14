import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rees46_sdk/src/ui/widgets/stories_image.dart';

// No test binding here: the loader talks to a real loopback server.
void main() {
  group('StoriesImageBytes', () {
    late List<String> fetched;
    late Map<String, Completer<Uint8List>> pending;

    StoriesImageBytes loader({int maxEntries = 4, int maxBytes = 1 << 20}) {
      fetched = <String>[];
      pending = <String, Completer<Uint8List>>{};
      return StoriesImageBytes(
        maxEntries: maxEntries,
        maxBytes: maxBytes,
        fetch: (uri) {
          fetched.add(uri.path);
          return (pending[uri.path] = Completer<Uint8List>()).future;
        },
      );
    }

    Uint8List bytes(int size) => Uint8List(size);

    test(
      'one request per address; a slide background stays in memory',
      () async {
        final images = loader();
        final first = images.load('https://cdn.example/a.gif', keep: true);
        final second = images.load('https://cdn.example/a.gif');
        expect(fetched, <String>['/a.gif']);
        pending['/a.gif']!.complete(bytes(3));
        expect(await first, hasLength(3));
        expect(await second, hasLength(3));

        // Kept: a restart or a return to the slide does not download again.
        expect(await images.load('https://cdn.example/a.gif'), hasLength(3));
        expect(fetched, <String>['/a.gif']);

        // Evicted (Retry): downloaded again.
        images.evict('https://cdn.example/a.gif');
        unawaited(images.load('https://cdn.example/a.gif'));
        expect(fetched, <String>['/a.gif', '/a.gif']);
      },
    );

    test('a cover is not kept; a later keep request is honoured', () async {
      final images = loader();
      final cover = images.load('https://cdn.example/c.jpg');
      final slide = images.load('https://cdn.example/c.jpg', keep: true);
      pending['/c.jpg']!.complete(bytes(1));
      await cover;
      await slide;
      await images.load('https://cdn.example/c.jpg');
      expect(fetched, <String>['/c.jpg'], reason: 'kept for the slide');

      unawaited(images.load('https://cdn.example/d.jpg'));
      pending['/d.jpg']!.complete(bytes(1));
      await Future<void>.delayed(Duration.zero);
      unawaited(images.load('https://cdn.example/d.jpg'));
      expect(fetched, <String>['/c.jpg', '/d.jpg', '/d.jpg']);
    });

    test('memory keeps the newest entries within both limits', () async {
      final images = loader(maxEntries: 2, maxBytes: 10);
      for (final name in <String>['a', 'b', 'c']) {
        final load = images.load('https://cdn.example/$name', keep: true);
        pending['/$name']!.complete(bytes(4));
        await load;
      }
      await images.load('https://cdn.example/c');
      await images.load('https://cdn.example/b');
      expect(fetched, <String>['/a', '/b', '/c'], reason: 'b and c kept');
      unawaited(images.load('https://cdn.example/a'));
      expect(fetched.last, '/a', reason: 'a was the oldest');

      final big = images.load('https://cdn.example/big', keep: true);
      pending['/big']!.complete(bytes(11));
      await big;
      unawaited(images.load('https://cdn.example/big'));
      expect(fetched.last, '/big', reason: 'over the byte limit');
    });

    test('a failure is not remembered', () async {
      final images = loader();
      final failed = images.load('https://cdn.example/x', keep: true);
      pending['/x']!.completeError(StateError('offline'));
      await expectLater(failed, throwsStateError);
      unawaited(images.load('https://cdn.example/x'));
      expect(fetched, <String>['/x', '/x']);
    });

    test(
      'downloads like NetworkImage: a non-200 or empty answer fails',
      () async {
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        addTearDown(() => server.close(force: true));
        server.listen((request) {
          final response = request.response;
          switch (request.uri.path) {
            case '/ok.gif':
              response.add(<int>[0x47, 0x49, 0x46]);
            case '/empty.gif':
              break;
            default:
              response.statusCode = HttpStatus.notFound;
          }
          response.close();
        });
        final base = 'http://127.0.0.1:${server.port}';
        final images = StoriesImageBytes();
        expect(await images.load('$base/ok.gif'), <int>[0x47, 0x49, 0x46]);
        await expectLater(
          images.load('$base/missing.gif'),
          throwsA(isA<NetworkImageLoadException>()),
        );
        await expectLater(images.load('$base/empty.gif'), throwsException);
      },
    );
  });
}
