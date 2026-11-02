import '../../stories/stories_response.dart';

/// Параметры ссылки «Поделиться» сторис (API v3): код блока, кампания и слайд.
const String storiesShareParamBlock = 'r46_stories';
const String storiesShareParamStory = 'r46_story';
const String storiesShareParamSlide = 'r46_slide';

/// Ссылка «Поделиться» сторис:
/// `https://<сайт>/<путь>?r46_stories=<code>&r46_story=<id>[&r46_slide=<id>]`, другие
/// параметры допустимы.
class StoriesShareLink {
  const StoriesShareLink({
    required this.code,
    required this.storyId,
    this.slideId,
  });

  /// Код блока сторис.
  final String code;

  /// Id кампании — число до 10 цифр.
  final String storyId;

  /// Id слайда: число или виртуальный слайд товарной кампании (`39_0`); нет или неверный —
  /// `null`, кампания открывается со своего `start_position`.
  final String? slideId;

  /// Ключ дублей: та же ссылка — тот же блок, кампания и слайд.
  String get key => '$code/$storyId/${slideId ?? ''}';

  @override
  bool operator ==(Object other) =>
      other is StoriesShareLink && other.key == key;

  @override
  int get hashCode => key.hashCode;

  @override
  String toString() => 'StoriesShareLink($key)';
}

final RegExp _storyIdFormat = RegExp(r'^\d{1,10}$');

// Слайд: число или виртуальный слайд товарной кампании «{story_id}_{index}».
final RegExp _slideIdFormat = RegExp(r'^\d{1,10}(_\d{1,4})?$');

final RegExp _httpLink = RegExp(r'^https?://', caseSensitive: false);

/// Ссылка сторис из адреса [url], как `parseShareLink` JS SDK: `r46_stories` не пустой,
/// `r46_story` — 1–10 цифр, `r46_slide` — число или `число_индекс` (неверный — `null`,
/// кампания всё равно открывается). Иначе — не ссылка сторис, `null`. Из повторов
/// параметра берётся первый.
StoriesShareLink? parseStoriesShareLink(String url) {
  final Map<String, List<String>> params;
  try {
    final uri = Uri.tryParse(url.trim());
    if (uri == null) return null;
    params = uri.queryParametersAll;
  } on FormatException {
    // Битое %-кодирование в запросе.
    return null;
  }
  String? first(String key) {
    final values = params[key];
    return values == null || values.isEmpty ? null : values.first;
  }

  final code = first(storiesShareParamBlock);
  final storyId = first(storiesShareParamStory);
  if (code == null ||
      code.isEmpty ||
      storyId == null ||
      !_storyIdFormat.hasMatch(storyId)) {
    return null;
  }
  final slideId = first(storiesShareParamSlide);
  return StoriesShareLink(
    code: code,
    storyId: storyId,
    slideId: slideId != null && _slideIdFormat.hasMatch(slideId)
        ? slideId
        : null,
  );
}

/// Ссылка «Поделиться» слайда [slide] кампании [story]: кампания запрещает делиться
/// (`shareable: false`) — нет; иначе своя ссылка слайда, без неё — ссылка кампании.
/// Только `http://` и `https://`; иначе нет. Нет ссылки — нет и кнопки на слайде.
String? storySlideShareUrl(Story story, StorySlide slide) {
  if (!story.shareable) return null;
  final url = slide.shareUrl.isNotEmpty ? slide.shareUrl : story.shareUrl;
  return _httpLink.hasMatch(url) ? url : null;
}
