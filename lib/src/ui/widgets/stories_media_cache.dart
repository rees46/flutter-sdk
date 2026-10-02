import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../pigeon/personalization_api.g.dart' as pigeon;

/// Дисковый кэш видео сторис: LRU на 50 МБ в папке `personalization_stories` кэша
/// приложения, один на процесс — общий для всех просмотров.
///
/// Каждый файл качается один раз: повторный запрос, пока файл ещё качается, ждёт ту же
/// загрузку. Файл сначала пишется во временный `.part` и только целиком переименовывается,
/// поэтому оборванная загрузка в кэш не попадает. После загрузки самые давно открытые
/// файлы удаляются, пока кэш не уложится в лимит. Без зависимостей: `dart:io`.
class StoriesMediaCache {
  StoriesMediaCache({
    this.maxBytes = 50 * 1024 * 1024,
    Future<Directory> Function()? directory,
  }) : _directory = directory ?? _platformDirectory;

  /// Кэш процесса. Тесты подменяют его.
  static StoriesMediaCache instance = StoriesMediaCache();

  final int maxBytes;
  final Future<Directory> Function() _directory;
  final Map<String, Future<File?>> _downloads = <String, Future<File?>>{};

  /// Когда файл открывали в этом процессе. Время изменения файла — отметка для
  /// следующих запусков, но система пишет его с точностью до секунды.
  final Map<String, DateTime> _opened = <String, DateTime>{};
  Future<Directory>? _root;

  static const String folder = 'personalization_stories';

  static Future<Directory> _platformDirectory() async {
    String base;
    try {
      base = await pigeon.PersonalizationHostApi().getCacheDirectory();
    } catch (_) {
      base = Directory.systemTemp.path;
    }
    return Directory('$base/$folder').create(recursive: true);
  }

  /// Видео можно положить в кэш файлом: HLS (`.m3u8`) — набор кусков, его плеер
  /// грузит сам.
  static bool cacheable(String url) {
    final path = Uri.tryParse(url)?.path.toLowerCase() ?? '';
    return url.isNotEmpty && !path.endsWith('.m3u8');
  }

  /// Файл [url] из кэша или загруженный сейчас; `null` — не вышло (тогда плеер берёт
  /// адрес из сети).
  Future<File?> fetch(String url) {
    if (!cacheable(url)) return Future<File?>.value();
    // Блок, а не стрелка: `remove` вернул бы саму загрузку, и whenComplete ждал бы её
    // же — вечно.
    return _downloads[url] ??= _fetch(url).whenComplete(() {
      _downloads.remove(url);
    });
  }

  /// Загрузить [url] заранее — для следующего слайда.
  void preload(String url) => unawaited(fetch(url));

  Future<File?> _fetch(String url) async {
    try {
      final root = await (_root ??= _directory());
      final file = File('${root.path}/${_name(url)}');
      if (await file.exists()) {
        // Отметка для LRU: открытый файл — свежий.
        final now = DateTime.now();
        _opened[file.path] = now;
        await file.setLastModified(now);
        return file;
      }
      final part = File('${file.path}.part');
      final client = HttpClient();
      try {
        final request = await client.getUrl(Uri.parse(url));
        final response = await request.close();
        if (response.statusCode != HttpStatus.ok ||
            response.contentLength > maxBytes) {
          await response.drain<void>();
          return null;
        }
        await response.pipe(part.openWrite());
      } finally {
        client.close();
      }
      await part.rename(file.path);
      _opened[file.path] = DateTime.now();
      await _trim(root, keep: file.path);
      return file;
    } catch (error) {
      debugPrint('PersonalizationStories: cannot cache $url — $error');
      return null;
    }
  }

  /// Удаляет самые давно открытые файлы, пока кэш больше лимита; [keep] не трогается.
  Future<void> _trim(Directory root, {required String keep}) async {
    final files = <(File, FileStat)>[];
    await for (final entity in root.list()) {
      if (entity is File && !entity.path.endsWith('.part')) {
        files.add((entity, await entity.stat()));
      }
    }
    var total = files.fold<int>(0, (sum, item) => sum + item.$2.size);
    DateTime opened((File, FileStat) item) =>
        _opened[item.$1.path] ?? item.$2.modified;
    files.sort((a, b) => opened(a).compareTo(opened(b)));
    for (final (file, stat) in files) {
      if (total <= maxBytes) break;
      if (file.path == keep) continue;
      try {
        await file.delete();
        _opened.remove(file.path);
        total -= stat.size;
      } catch (_) {}
    }
  }

  /// Имя файла: хэш адреса (FNV-1a, 64 бита) и расширение из пути — по нему AVPlayer
  /// узнаёт формат локального файла.
  static String _name(String url) {
    var hash = 0xcbf29ce484222325;
    for (final byte in utf8.encode(url)) {
      hash ^= byte;
      hash = (hash * 0x100000001b3) & 0xFFFFFFFFFFFFFFFF;
    }
    final path = Uri.tryParse(url)?.path ?? '';
    final dot = path.lastIndexOf('.');
    final extension = dot >= 0 && path.length - dot <= 5
        ? path.substring(dot).toLowerCase()
        : '.mp4';
    return '${hash.toUnsigned(64).toRadixString(16)}$extension';
  }
}
