import 'package:flutter/foundation.dart';

/// GIF по его байтам: размер и задержки кадров — без декодирования картинки.
///
/// GIF узнаётся только по подписи `GIF87a` / `GIF89a` в начале байтов — не по адресу и
/// не по типу слайда. Задержка кадра — из его Graphic Control Extension; меньше 20 мс (и
/// 0, и кадр без расширения) считается 100 мс — как в браузерах. Один круг анимации
/// ([loop]) — сумма задержек всех кадров. Правила общие для всех платформ.
@immutable
class StoryGif {
  const StoryGif._({
    required this.width,
    required this.height,
    required this.delays,
    required bool complete,
  }) : _complete = complete;

  /// Размер холста GIF в пикселях.
  final int width;
  final int height;

  /// Задержки кадров по порядку, уже с поправкой на короткие ([frameDelay]).
  final List<Duration> delays;

  /// Разбор дошёл до конца без ошибок.
  final bool _complete;

  /// Короче этого задержка кадра не бывает: такая считается [shortDelay].
  static const Duration minDelay = Duration(milliseconds: 20);

  /// Задержка вместо слишком короткой.
  static const Duration shortDelay = Duration(milliseconds: 100);

  /// Длина одного круга анимации; `null` — неизвестна: байты битые или кадров нет.
  Duration? get loop {
    if (!_complete || delays.isEmpty) return null;
    return delays.fold<Duration>(Duration.zero, (sum, delay) => sum + delay);
  }

  /// Задержка кадра по правилу браузеров: меньше 20 мс (и 0) — 100 мс.
  static Duration frameDelay(Duration delay) =>
      delay < minDelay ? shortDelay : delay;

  /// Байты начинаются с подписи GIF.
  static bool isGif(List<int> bytes) {
    if (bytes.length < 6) return false;
    // «GIF8», затем «7a» или «9a».
    return bytes[0] == 0x47 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[3] == 0x38 &&
        (bytes[4] == 0x37 || bytes[4] == 0x39) &&
        bytes[5] == 0x61;
  }

  /// Разобрать [bytes]; не GIF — `null`. Битый GIF разбирается до первой ошибки, а его
  /// круг неизвестен ([loop] — `null`).
  static StoryGif? parse(List<int> bytes) {
    if (!isGif(bytes)) return null;
    final delays = <Duration>[];
    if (bytes.length < 13) {
      return StoryGif._(width: 0, height: 0, delays: delays, complete: false);
    }
    final width = bytes[6] | bytes[7] << 8;
    final height = bytes[8] | bytes[9] << 8;
    // Заголовок 6 байт, описание экрана 7 байт, за ним общая палитра.
    var at = 13 + _paletteSize(bytes[10]);
    var delay = Duration.zero;
    var complete = true;
    while (at < bytes.length) {
      final block = bytes[at++];
      if (block == 0x3B) break; // Конец файла.
      if (block == 0x21) {
        // Расширение: метка, затем подблоки до пустого.
        if (at >= bytes.length) {
          complete = false;
          break;
        }
        final label = bytes[at++];
        // Graphic Control Extension: размер 4, флаги, задержка в сотых секунды (LE).
        if (label == 0xF9 && at + 3 < bytes.length && bytes[at] >= 4) {
          final hundredths = bytes[at + 2] | bytes[at + 3] << 8;
          delay = Duration(milliseconds: hundredths * 10);
        }
        at = _skipSubBlocks(bytes, at);
      } else if (block == 0x2C) {
        // Кадр: 9 байт описания, своя палитра, размер кода LZW, подблоки данных.
        if (at + 9 > bytes.length) {
          complete = false;
          break;
        }
        at += 9 + _paletteSize(bytes[at + 8]) + 1;
        at = _skipSubBlocks(bytes, at);
        if (at >= 0) {
          delays.add(frameDelay(delay));
          delay = Duration.zero;
        }
      } else {
        at = -1; // Неизвестный блок.
      }
      if (at < 0) {
        complete = false;
        break;
      }
    }
    return StoryGif._(
      width: width,
      height: height,
      delays: List<Duration>.unmodifiable(delays),
      complete: complete,
    );
  }

  /// Байт палитры по флагам: есть палитра — 3 × 2^(N+1).
  static int _paletteSize(int flags) =>
      flags & 0x80 == 0 ? 0 : 3 * (1 << ((flags & 0x07) + 1));

  /// Позиция после подблоков, начиная с [at]; байты кончились раньше — `-1`.
  static int _skipSubBlocks(List<int> bytes, int at) {
    var position = at;
    while (position < bytes.length) {
      final size = bytes[position++];
      if (size == 0) return position;
      position += size;
    }
    return -1;
  }
}
