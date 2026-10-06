import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';

import 'stories_gif.dart';

/// Проигрыватель GIF фона слайда: кадры по своим задержкам ([StoryGif.delays]), по
/// кругу, пока слайд идёт.
///
/// - [start] декодирует первый кадр — с ним слайд готов, и его часы могут идти;
/// - время даёт просмотр ([advance]) теми же шагами, что часы слайда: стоят часы — стоит
///   и GIF на текущем кадре, а продолжение идёт с него же и с остатком его задержки;
/// - [restart] — с первого кадра из тех же байтов в памяти, без новой загрузки;
/// - кодек отдаёт кадры по одному: в памяти только показанный кадр и следующий. Кадр
///   крупнее [limit] (площадь слайда в пикселях) уменьшается до неё — движок
///   анимированные картинки при декодировании не ужимает.
class StoryGifPlayer extends ChangeNotifier {
  StoryGifPlayer(this.bytes, this.gif, {this.limit});

  /// Байты GIF — из них же кодек создаётся заново при [restart].
  final Uint8List bytes;
  final StoryGif gif;

  /// Больше этого кадр не держится; `null` — без ограничения.
  final ui.Size? limit;

  /// Как из байтов получить кодек. Тесты подменяют.
  @visibleForTesting
  static Future<ui.Codec> Function(Uint8List bytes) codecOf =
      ui.instantiateImageCodec;

  ui.Codec? _codec;
  ui.Image? _frame;
  ui.Image? _next;
  Duration _nextDuration = Duration.zero;
  int _index = 0;

  /// Сколько ещё показывать текущий кадр; меньше нуля — следующий уже опаздывает.
  Duration _left = Duration.zero;

  /// Номер запуска: декодирование прошлого запуска (до [restart] или [dispose])
  /// отбрасывается.
  int _run = 0;
  bool _disposed = false;

  /// Показанный кадр; `null` — первый ещё не готов.
  ui.Image? get frame => _frame;

  /// Номер показанного кадра.
  int get index => _index;

  /// Задержка кадра [index]: из разбора байтов, а если кодек насчитал другое число
  /// кадров — из самого кодека, с той же поправкой на короткие.
  Duration _delay(int index, Duration decoded) {
    final codec = _codec;
    if (codec != null &&
        gif.delays.length == codec.frameCount &&
        index < gif.delays.length) {
      return gif.delays[index];
    }
    return StoryGif.frameDelay(decoded);
  }

  /// Декодировать первый кадр. Ошибка декодирования — исключение: слайд покажет
  /// «Повторить», как у битого фото.
  Future<void> start() => _open(++_run);

  /// С первого кадра: новый кодек из тех же байтов. Пока он готовится, виден прежний
  /// кадр, а время первого кадра уже идёт — вровень с часами слайда. До первого кадра
  /// перезапускать нечего: [start] его и покажет.
  Future<void> restart() async {
    if (_disposed || _frame == null) return;
    final run = ++_run;
    _next?.dispose();
    _next = null;
    _index = 0;
    _left = gif.delays.isEmpty ? StoryGif.shortDelay : gif.delays.first;
    try {
      await _open(run);
    } catch (error) {
      debugPrint('StoryGifPlayer: restart — $error');
    }
  }

  Future<void> _open(int run) async {
    final codec = await codecOf(bytes);
    if (run != _run) {
      codec.dispose();
      return;
    }
    _codec?.dispose();
    _codec = codec;
    final first = await codec.getNextFrame();
    if (run != _run) {
      first.image.dispose();
      return;
    }
    // После перезапуска время первого кадра уже идёт ([restart]); при старте — с нуля.
    final starting = _frame == null;
    _show(_fit(first.image), 0);
    if (starting) _left = _delay(0, first.duration);
    _decodeNext(run);
  }

  /// Прошло [delta] времени слайда.
  void advance(Duration delta) {
    if (_disposed || _frame == null || (_codec?.frameCount ?? 0) < 2) return;
    _left -= delta;
    _flush();
  }

  /// Время текущего кадра вышло, а следующий готов — показать его.
  void _flush() {
    final next = _next;
    if (next == null || _left > Duration.zero) return;
    _next = null;
    final index = (_index + 1) % _codec!.frameCount;
    _show(next, index);
    _left += _delay(index, _nextDuration);
    _decodeNext(_run);
  }

  void _decodeNext(int run) {
    final codec = _codec;
    if (codec == null || codec.frameCount < 2) return;
    codec.getNextFrame().then(
      (frame) {
        if (run != _run) {
          frame.image.dispose();
          return;
        }
        _next = _fit(frame.image);
        _nextDuration = frame.duration;
        _flush();
      },
      onError: (Object error) {
        // Кадр не декодировался: GIF стоит на текущем, слайд идёт дальше по часам.
        if (run == _run) debugPrint('StoryGifPlayer: frame — $error');
      },
    );
  }

  void _show(ui.Image image, int index) {
    final previous = _frame;
    _frame = image;
    _index = index;
    previous?.dispose();
    notifyListeners();
  }

  /// Кадр крупнее [limit] — уменьшенная копия, пропорции те же.
  ui.Image _fit(ui.Image image) {
    final limit = this.limit;
    if (limit == null || limit.isEmpty) return image;
    final scale = math.min(
      limit.width / image.width,
      limit.height / image.height,
    );
    if (scale >= 1) return image;
    final width = math.max(1, (image.width * scale).round());
    final height = math.max(1, (image.height * scale).round());
    final recorder = ui.PictureRecorder();
    ui.Canvas(recorder).drawImageRect(
      image,
      ui.Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      ui.Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
      ui.Paint()..filterQuality = ui.FilterQuality.medium,
    );
    final picture = recorder.endRecording();
    final small = picture.toImageSync(width, height);
    picture.dispose();
    image.dispose();
    return small;
  }

  @override
  void dispose() {
    _disposed = true;
    _run++;
    _frame?.dispose();
    _frame = null;
    _next?.dispose();
    _next = null;
    _codec?.dispose();
    _codec = null;
    super.dispose();
  }
}
