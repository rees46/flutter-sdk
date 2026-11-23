import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../pigeon/personalization_api.g.dart' as pigeon;

/// Звук сторис на весь процесс.
///
/// - При первом открытии звук выключен; выбор пользователя помнится до конца процесса и
///   переходит на следующие открытия ([muted]).
/// - Просмотр новой ленты держит свой звук ([mutedV3]), отдельно от старых просмотров: как
///   веб, он берёт выбор кнопки звука с устройства — у каждого магазина свой, как у веба у
///   каждого сайта ([restore]; нет выбора — без звука), и хранит там только выбор кнопки
///   ([toggleV3]).
/// - Кнопка громкости «вверх» включает звук верхнего открытого просмотра (у новой ленты —
///   не сохраняя): на Android клавиша сама доходит до Flutter ([HardwareKeyboard]), на iOS
///   плагин следит за громкостью аудиосессии и сообщает о росте через
///   `PersonalizationStoriesFlutterApi`.
/// - iOS: пока идёт видео, сессия `ambient` без звука (музыка пользователя не
///   прерывается) и `playback` со звуком; при закрытии просмотра возвращается сессия
///   приложения. Android: видео играет с `mixWithOthers` и фокус не забирает.
class StoriesSound implements pigeon.PersonalizationStoriesFlutterApi {
  StoriesSound._();

  static final StoriesSound instance = StoriesSound._();

  /// Хост-API плагина. Тесты подменяют его.
  @visibleForTesting
  static pigeon.PersonalizationHostApi api = pigeon.PersonalizationHostApi();

  /// Звук выключен. Общий для всех просмотров старой ленты процесса.
  final ValueNotifier<bool> muted = ValueNotifier<bool>(true);

  /// Звук выключен у просмотров новой ленты: свой, старые просмотры его не видят.
  final ValueNotifier<bool> mutedV3 = ValueNotifier<bool>(true);

  /// Звук просмотра новой ленты ([v3]) или старой.
  ValueNotifier<bool> of({required bool v3}) => v3 ? mutedV3 : muted;

  /// Звуки открытых просмотров по порядку открытия: верхний — последний.
  final List<ValueNotifier<bool>> _open = <ValueNotifier<bool>>[];
  bool _session = false;

  /// Звук верхнего открытого просмотра; нет открытых — старой ленты.
  ValueNotifier<bool> get _current => _open.isEmpty ? muted : _open.last;

  /// Просмотр открылся: слушать кнопку громкости. [v3] — просмотр новой ленты.
  void attach({bool v3 = false}) {
    final sound = of(v3: v3);
    _open.add(sound);
    sound.addListener(_apply);
    if (_open.length > 1) return;
    HardwareKeyboard.instance.addHandler(_onKey);
    pigeon.PersonalizationStoriesFlutterApi.setUp(this);
  }

  /// Просмотр закрылся. Последний — вернуть сессию приложения.
  void detach({bool v3 = false}) {
    final sound = of(v3: v3);
    final index = _open.lastIndexOf(sound);
    if (index < 0) return;
    _open.removeAt(index);
    sound.removeListener(_apply);
    if (_open.isNotEmpty) {
      // Сверху теперь просмотр с другим звуком — сессия по нему.
      if (index == _open.length && !identical(_open.last, sound)) _apply();
      return;
    }
    HardwareKeyboard.instance.removeHandler(_onKey);
    pigeon.PersonalizationStoriesFlutterApi.setUp(null);
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

  /// После готовности плеера: сессия по звуку верхнего просмотра (iOS). Плеер при
  /// создании сам трогает категорию, поэтому — после каждого.
  Future<void> afterVideo() => _session
      ? _call(() => api.updateStoriesAudio(_current.value))
      : Future<void>.value();

  /// Ключ выбора кнопки звука магазина [shopId] на устройстве.
  static String mutedKey(String shopId) =>
      'personalization.stories.muted.$shopId';

  /// Кнопка звука старой ленты: переключить на весь процесс.
  void toggle() => muted.value = !muted.value;

  /// Кнопка звука новой ленты: переключить и сохранить выбор магазина [shopId] на
  /// устройстве (пустой магазин — не сохранять).
  void toggleV3(String shopId) {
    mutedV3.value = !mutedV3.value;
    if (shopId.isNotEmpty) unawaited(_remember(shopId, mutedV3.value));
  }

  /// Взять в [mutedV3] выбор кнопки звука магазина [shopId] с устройства; его нет — звук
  /// выключен, как у веба. Устройство не ответило — звук как был.
  Future<void> restore(String shopId) async {
    try {
      final preferences = await SharedPreferences.getInstance();
      mutedV3.value = preferences.getBool(mutedKey(shopId)) ?? true;
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

  /// Сколько ждать ответа платформы о звуке видео: мост сам сдаётся раньше (Android —
  /// 5 с), это — последняя граница.
  static const Duration probeTimeout = Duration(seconds: 6);

  /// Есть ли звук у видео [source] (адрес или файл кэша); не прочитать или нет ответа за
  /// [probeTimeout] — `null`.
  Future<bool?> hasAudio(String source) async {
    try {
      return await api.storiesVideoHasAudio(source).timeout(probeTimeout);
    } catch (error) {
      debugPrint('PersonalizationStories: audio of $source — $error');
      return null;
    }
  }

  @override
  void onStoriesVolumeUp() => _current.value = false;

  bool _onKey(KeyEvent event) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.audioVolumeUp) {
      _current.value = false;
    }
    // Клавиша идёт дальше: громкость системы меняется как обычно.
    return false;
  }

  void _apply() {
    if (_session) _call(() => api.updateStoriesAudio(_current.value));
  }

  static Future<void> _call(Future<void> Function() body) async {
    try {
      await body();
    } catch (error) {
      debugPrint('PersonalizationStories: audio session — $error');
    }
  }
}
