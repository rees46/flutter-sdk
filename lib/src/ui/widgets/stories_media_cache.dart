import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../pigeon/personalization_api.g.dart' as pigeon;

/// Дисковый кэш видео сторис: LRU на 50 МБ в папке `personalization_stories` кэша
/// приложения, один на процесс — общий для всех просмотров.
///
/// Видео не ждёт кэша: просмотр берёт готовый файл ([cached]), а нет его — играет по
/// сети и тем временем заполняет кэш в фоне ([fill]); в следующий раз видео идёт из файла.
/// Каждый адрес качается одним потоком: повторный запрос, пока файл ещё качается, ждёт ту
/// же загрузку. Файл сначала пишется во временный `.part` и только целиком
/// переименовывается, поэтому оборванная загрузка в кэш не попадает. Файл больше лимита
/// бросается на первом лишнем байте (тело не дочитывается) и до конца процесса больше не
/// качается. После загрузки самые давно открытые файлы удаляются, пока кэш не уложится в
/// лимит. Без зависимостей: `dart:io`.
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

  /// Адреса, которые в кэш не помещаются: второй раз их не качаем.
  final Set<String> _oversized = <String>{};

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

  /// Готовый файл [url] из кэша; нет — `null`. Ничего не качает.
  Future<File?> cached(String url) async {
    if (!cacheable(url)) return null;
    try {
      final file = await _file(url);
      if (!await file.exists()) return null;
      await _touch(file);
      return file;
    } catch (error) {
      debugPrint('PersonalizationStories: cache lookup $url — $error');
      return null;
    }
  }

  /// Файл [url] из кэша или загруженный сейчас; `null` — не вышло (тогда плеер берёт
  /// адрес из сети).
  Future<File?> fetch(String url) {
    if (!cacheable(url) || _oversized.contains(url)) {
      return Future<File?>.value();
    }
    // Блок, а не стрелка: `remove` вернул бы саму загрузку, и whenComplete ждал бы её
    // же — вечно.
    return _downloads[url] ??= _fetch(url).whenComplete(() {
      _downloads.remove(url);
    });
  }

  /// Положить [url] в кэш в фоне — пока видео играет по сети или для следующего слайда.
  void fill(String url) => unawaited(fetch(url));

  /// То же, что [fill]: заранее для следующего слайда.
  void preload(String url) => fill(url);

  Future<File> _file(String url) async {
    final root = await (_root ??= _directory());
    return File('${root.path}/${_name(url)}');
  }

  /// Отметка для LRU: открытый файл — свежий.
  Future<void> _touch(File file) async {
    final now = DateTime.now();
    _opened[file.path] = now;
    await file.setLastModified(now);
  }

  Future<File?> _fetch(String url) async {
    try {
      final file = await _file(url);
      if (await file.exists()) {
        await _touch(file);
        return file;
      }
      final part = File('${file.path}.part');
      if (!await _download(url, part)) return null;
      await part.rename(file.path);
      _opened[file.path] = DateTime.now();
      await _trim(file.parent, keep: file.path);
      return file;
    } catch (error) {
      debugPrint('PersonalizationStories: cannot cache $url — $error');
      return null;
    }
  }

  /// Скачать [url] в [part]. Ответ не 200 или файл больше лимита — `false`, соединение
  /// рвётся сразу, без дочитывания тела.
  Future<bool> _download(String url, File part) async {
    final client = HttpClient();
    try {
      final request = await client.getUrl(Uri.parse(url));
      final response = await request.close();
      if (response.statusCode != HttpStatus.ok) return false;
      if (response.contentLength > maxBytes) {
        _oversized.add(url);
        return false;
      }
      final sink = part.openWrite();
      var bytes = 0;
      try {
        // Длина бывает не известна заранее: считаем байты по ходу.
        await for (final chunk in response) {
          bytes += chunk.length;
          if (bytes > maxBytes) break;
          sink.add(chunk);
        }
      } finally {
        await sink.close();
      }
      if (bytes <= maxBytes) return true;
      _oversized.add(url);
      await part.delete();
      return false;
    } finally {
      // force: недочитанное тело не тянется до конца.
      client.close(force: true);
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
