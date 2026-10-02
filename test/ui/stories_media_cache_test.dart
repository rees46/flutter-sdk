import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rees46_sdk/src/ui/widgets/stories_media_cache.dart';

void main() {
  late HttpServer server;
  late Directory root;
  final requests = <String>[];

  setUp(() async {
    requests.clear();
    root = await Directory.systemTemp.createTemp('stories_cache_test');
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) {
      requests.add(request.uri.path);
      final size = int.parse(request.uri.queryParameters['size'] ?? '10');
      final response = request.response;
      // Chunked: the length is not known up front.
      if (request.uri.queryParameters['chunked'] != null) {
        response.headers.chunkedTransferEncoding = true;
      } else {
        response.contentLength = size;
      }
      response
        ..add(List<int>.filled(size, 7))
        ..close();
    });
  });

  tearDown(() async {
    await server.close(force: true);
    await root.delete(recursive: true);
  });

  String url(String name, {int size = 10, bool chunked = false}) =>
      'http://127.0.0.1:${server.port}/$name.mp4?size=$size'
      '${chunked ? '&chunked=1' : ''}';

  test('each file downloads once, also when asked twice at once', () async {
    final cache = StoriesMediaCache(directory: () async => root);
    final results = await Future.wait([
      cache.fetch(url('a')),
      cache.fetch(url('a')),
    ]);
    expect(results[0]!.path, results[1]!.path);
    expect(results[0]!.path, endsWith('.mp4'));
    expect(await results[0]!.length(), 10);

    await cache.fetch(url('a'));
    expect(requests, ['/a.mp4'], reason: 'the second fetch reads the file');
  });

  test('over the limit, the least recently opened files go', () async {
    final cache = StoriesMediaCache(maxBytes: 250, directory: () async => root);
    final a = await cache.fetch(url('a', size: 100));
    await Future<void>.delayed(const Duration(milliseconds: 20));
    final b = await cache.fetch(url('b', size: 100));
    await Future<void>.delayed(const Duration(milliseconds: 20));
    await cache.fetch(url('a', size: 100)); // a is fresh again
    await Future<void>.delayed(const Duration(milliseconds: 20));
    await cache.fetch(url('c', size: 100));

    expect(await a!.exists(), isTrue);
    expect(await b!.exists(), isFalse);
  });

  test('a lookup never downloads; a filled file is found next time', () async {
    final cache = StoriesMediaCache(directory: () async => root);
    expect(await cache.cached(url('a')), isNull);
    expect(requests, isEmpty);

    cache.fill(url('a'));
    cache.fill(url('a'));
    final file = await cache.fetch(url('a'));
    expect(await cache.cached(url('a')), isNotNull);
    expect((await cache.cached(url('a')))!.path, file!.path);
    expect(requests, ['/a.mp4'], reason: 'one download per address');
  });

  test('a file over the limit is cut short and never fetched again', () async {
    final cache = StoriesMediaCache(maxBytes: 250, directory: () async => root);
    expect(await cache.fetch(url('big', size: 300)), isNull);
    expect(await cache.fetch(url('big', size: 300)), isNull);
    expect(requests, ['/big.mp4']);

    // Without a length up front, the download stops on the first byte too many.
    expect(await cache.fetch(url('chunk', size: 300, chunked: true)), isNull);
    expect(await cache.fetch(url('chunk', size: 300, chunked: true)), isNull);
    expect(requests, ['/big.mp4', '/chunk.mp4']);
    expect(root.listSync(), isEmpty, reason: 'no part files are left');
  });

  test('HLS is left to the player', () async {
    final cache = StoriesMediaCache(directory: () async => root);
    expect(await cache.fetch('https://cdn.example/clip.m3u8'), isNull);
    expect(await cache.cached('https://cdn.example/clip.m3u8'), isNull);
    expect(StoriesMediaCache.cacheable('https://cdn.example/clip.mp4'), isTrue);
  });
}
