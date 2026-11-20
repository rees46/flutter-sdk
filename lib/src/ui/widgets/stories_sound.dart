import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../pigeon/personalization_api.g.dart' as pigeon;

/// Звук сторис на весь процесс.
///
/// - При первом открытии звук выключен; выбор пользователя помнится до конца процесса и
///   переходит на следующие открытия ([muted]). Просмотр новой ленты, как веб, ещё и
///   хранит выбор кнопки звука на устройстве — у каждого магазина свой, как у веба у
///   каждого сайта ([restore], [toggle] с `rememberFor`).
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

  /// Ключ выбора кнопки звука магазина [shopId] на устройстве.
  static String mutedKey(String shopId) =>
      'personalization.stories.muted.$shopId';

  /// Кнопка звука: переключить; [rememberFor] — магазин, для которого сохранить выбор на
  /// устройстве (`null` — не сохранять).
  void toggle({String? rememberFor}) {
    muted.value = !muted.value;
    if (rememberFor != null) unawaited(_remember(rememberFor, muted.value));
  }

  /// Взять выбор кнопки звука магазина [shopId] с устройства; его нет — звук выключен,
  /// как у веба. Устройство не ответило — звук как был.
  Future<void> restore(String shopId) async {
    try {
      final preferences = await SharedPreferences.getInstance();
      muted.value = preferences.getBool(mutedKey(shopId)) ?? true;
    } catch (error) {
      debugPrint('PersonalizationStories: sound choice unavailable — $error');
    }
  }

  static Future<void> _remember(String shopId, bool value) async {
    try {
      await (await SharedPreferences.getInstance()).setBool(
        mutedKey(shopId),
        value,
      );
    } catch (error) {
      debugPrint('PersonalizationStories: sound choice not saved — $error');
    }
  }

  /// Есть ли звук у видео [source] (адрес или файл кэша); не прочитать — `null`.
  Future<bool?> hasAudio(String source) async {
    try {
      return await api.storiesVideoHasAudio(source);
    } catch (error) {
      debugPrint('PersonalizationStories: audio of $source — $error');
      return null;
    }
  }

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
