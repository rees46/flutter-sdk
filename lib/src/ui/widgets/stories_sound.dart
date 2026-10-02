import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../pigeon/personalization_api.g.dart' as pigeon;

/// Звук сторис на весь процесс.
///
/// - При первом открытии звук выключен; выбор пользователя помнится до конца процесса и
///   переходит на следующие открытия ([muted]).
/// - Кнопка громкости «вверх» включает звук: на Android клавиша сама доходит до
///   Flutter ([HardwareKeyboard]), на iOS плагин следит за громкостью аудиосессии и
///   сообщает о росте через `PersonalizationStoriesFlutterApi`.
/// - iOS: пока идёт видео, сессия `ambient` без звука (музыка пользователя не
///   прерывается) и `playback` со звуком; при закрытии просмотра возвращается сессия
///   приложения. Android: видео играет с `mixWithOthers` и фокус не забирает.
class StoriesSound implements pigeon.PersonalizationStoriesFlutterApi {
  StoriesSound._();

  static final StoriesSound instance = StoriesSound._();

  /// Хост-API плагина. Тесты подменяют его.
  @visibleForTesting
  static pigeon.PersonalizationHostApi api = pigeon.PersonalizationHostApi();

  /// Звук выключен. Общий для всех просмотров процесса.
  final ValueNotifier<bool> muted = ValueNotifier<bool>(true);

  int _viewers = 0;
  bool _session = false;

  /// Просмотр открылся: слушать кнопку громкости.
  void attach() {
    if (_viewers++ > 0) return;
    HardwareKeyboard.instance.addHandler(_onKey);
    pigeon.PersonalizationStoriesFlutterApi.setUp(this);
    muted.addListener(_apply);
  }

  /// Просмотр закрылся. Последний — вернуть сессию приложения.
  void detach() {
    if (_viewers == 0 || --_viewers > 0) return;
    HardwareKeyboard.instance.removeHandler(_onKey);
    pigeon.PersonalizationStoriesFlutterApi.setUp(null);
    muted.removeListener(_apply);
    if (_session) {
      _session = false;
      _call(api.endStoriesAudio);
    }
  }

  /// Перед созданием первого плеера: запомнить сессию приложения (iOS).
  Future<void> beforeVideo() async {
    if (_session) return;
    _session = true;
    await _call(api.beginStoriesAudio);
  }

  /// После готовности плеера: сессия по [muted] (iOS). Плеер при создании сам трогает
  /// категорию, поэтому — после каждого.
  Future<void> afterVideo() => _session
      ? _call(() => api.updateStoriesAudio(muted.value))
      : Future<void>.value();

  void toggle() => muted.value = !muted.value;

  @override
  void onStoriesVolumeUp() => muted.value = false;

  bool _onKey(KeyEvent event) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.audioVolumeUp) {
      muted.value = false;
    }
    // Клавиша идёт дальше: громкость системы меняется как обычно.
    return false;
  }

  void _apply() {
    if (_session) _call(() => api.updateStoriesAudio(muted.value));
  }

  static Future<void> _call(Future<void> Function() body) async {
    try {
      await body();
    } catch (error) {
      debugPrint('PersonalizationStories: audio session — $error');
    }
  }
}
