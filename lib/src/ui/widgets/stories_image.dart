import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import 'stories_gif.dart';

/// Байты картинок сторис из сети — так же, как их качает [NetworkImage]. Один адрес
/// качается одним запросом: повторный, пока идёт загрузка, ждёт её же.
///
/// Байты фонов слайдов ([load] с `keep`) ещё и остаются в памяти — несколько последних
/// ([maxEntries], [maxBytes]): возврат на слайд начинает его GIF с первого кадра без
/// новой загрузки, а фото и GIF одного слайда не качаются дважды. Неудача не запоминается.
class StoriesImageBytes {
  StoriesImageBytes({
    this.maxEntries = 4,
    this.maxBytes = 48 * 1024 * 1024,
    Future<Uint8List> Function(Uri uri)? fetch,
  }) : _fetch = fetch ?? _download;

  /// Загрузчик процесса. Тесты подменяют его.
  static StoriesImageBytes instance = StoriesImageBytes();

  final int maxEntries;
  final int maxBytes;
  final Future<Uint8List> Function(Uri uri) _fetch;
  final Map<String, Future<Uint8List>> _loading = <String, Future<Uint8List>>{};
  final Set<String> _keep = <String>{};

  /// Оставленные байты: последний — самый свежий.
  final LinkedHashMap<String, Uint8List> _kept =
      LinkedHashMap<String, Uint8List>();

  // Как у NetworkImage: сжатие снимает consolidateHttpClientResponseBytes.
  static final HttpClient _client = HttpClient()..autoUncompress = false;

  static Future<Uint8List> _download(Uri uri) async {
    final request = await _client.getUrl(uri);
    final response = await request.close();
    if (response.statusCode != HttpStatus.ok) {
      await response.drain<List<int>>(<int>[]);
      throw NetworkImageLoadException(
        statusCode: response.statusCode,
        uri: uri,
      );
    }
    final bytes = await consolidateHttpClientResponseBytes(response);
    if (bytes.lengthInBytes == 0) {
      throw Exception('PersonalizationStories: empty image $uri');
    }
    return bytes;
  }

  /// Байты [url]: из памяти, из идущей загрузки или скачанные сейчас. [keep] — оставить
  /// их в памяти после загрузки (фон слайда).
  Future<Uint8List> load(String url, {bool keep = false}) {
    final kept = _kept.remove(url);
    if (kept != null) {
      _kept[url] = kept;
      return Future<Uint8List>.value(kept);
    }
    if (keep) _keep.add(url);
    final loading = _loading[url];
    if (loading != null) return loading;
    final future = _fetch(Uri.base.resolve(url))
        .then((bytes) {
          if (_keep.remove(url)) _put(url, bytes);
          return bytes;
        })
        .whenComplete(() {
          _loading.remove(url);
          _keep.remove(url);
        });
    _loading[url] = future;
    return future;
  }

  /// Забыть байты [url] — «Повторить» качает заново.
  void evict(String url) => _kept.remove(url);

  void _put(String url, Uint8List bytes) {
    _kept[url] = bytes;
    var total = _kept.values.fold<int>(0, (sum, kept) => sum + kept.length);
    while (_kept.isNotEmpty &&
        (_kept.length > maxEntries || total > maxBytes)) {
      final oldest = _kept.keys.first;
      total -= _kept.remove(oldest)!.length;
    }
  }
}

/// Картинка сторис по адресу, когда хост не дал своего провайдера: качается как у
/// [NetworkImage] (через [StoriesImageBytes]), но GIF показывается только первым кадром и
/// не анимируется — так рисуются обложки, превью, постеры видео и картинки товаров.
/// Анимирует GIF только фон слайда ([StoryGifPlayer]). Прочие форматы — как у
/// [NetworkImage].
@immutable
class StoryImage extends ImageProvider<StoryImage> {
  const StoryImage(this.url);

  final String url;

  @override
  Future<StoryImage> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture<StoryImage>(this);

  @override
  ImageStreamCompleter loadImage(StoryImage key, ImageDecoderCallback decode) =>
      MultiFrameImageStreamCompleter(
        codec: _codec(key, decode),
        scale: 1,
        debugLabel: url,
        informationCollector: () => <DiagnosticsNode>[
          DiagnosticsProperty<ImageProvider>('Image provider', this),
          DiagnosticsProperty<StoryImage>('Image key', key),
        ],
      );

  Future<ui.Codec> _codec(StoryImage key, ImageDecoderCallback decode) async {
    try {
      final bytes = await StoriesImageBytes.instance.load(url);
      final codec = await decode(await ui.ImmutableBuffer.fromUint8List(bytes));
      return StoryGif.isGif(bytes) ? firstFrame(codec) : codec;
    } catch (_) {
      // Как у NetworkImage: неудача не остаётся в кэше — следующий показ грузит заново.
      scheduleMicrotask(() => PaintingBinding.instance.imageCache.evict(key));
      rethrow;
    }
  }

  /// Кодек, у которого из [codec] остаётся один первый кадр.
  @visibleForTesting
  static ui.Codec firstFrame(ui.Codec codec) => _FirstFrame(codec);

  @override
  bool operator ==(Object other) => other is StoryImage && other.url == url;

  @override
  int get hashCode => url.hashCode;

  @override
  String toString() => '${objectRuntimeType(this, 'StoryImage')}("$url")';
}

/// Кодек с одним кадром — первым: GIF стоит на месте. Декодер после первого кадра
/// закрывается — в памяти остаётся только сам кадр.
class _FirstFrame implements ui.Codec {
  _FirstFrame(this._codec);

  ui.Codec? _codec;
  Future<ui.Image>? _first;

  @override
  int get frameCount => 1;

  @override
  int get repetitionCount => 0;

  @override
  Future<ui.FrameInfo> getNextFrame() async {
    final first = await (_first ??= _decodeFirst());
    return _Frame(first.clone());
  }

  Future<ui.Image> _decodeFirst() async {
    final codec = _codec!;
    final frame = await codec.getNextFrame();
    codec.dispose();
    _codec = null;
    return frame.image;
  }

  @override
  void dispose() {
    _codec?.dispose();
    _codec = null;
    _first?.then((image) => image.dispose(), onError: (Object _) {});
    _first = null;
  }
}

class _Frame implements ui.FrameInfo {
  _Frame(this.image);

  @override
  final ui.Image image;

  @override
  Duration get duration => Duration.zero;
}
