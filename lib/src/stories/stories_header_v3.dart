part of 'stories_response.dart';

/// The `payload` of API v3 (`/api/v3/storefront/stories/{code}`): the keys of the old
/// feed plus what only API v3 has — the `header` element and its text block rules. Behind
/// the v3 gate; the old feed ([StoriesBlock.fromJson]) reads none of it.
StoriesBlock parseStoriesBlockV3(Map<String, dynamic> json) =>
    StoriesBlock._parse(json, v3: true);

/// `header` of a slide (API v3): the icon, the title and the subtitle of the shop or the
/// campaign over the slide, with a link. Behind the v3 gate (`src/v3/personalization_v3.dart`),
/// not the kit's; the old feed draws none.
class StoryHeaderElement extends StoryElement {
  const StoryHeaderElement({
    this.icon = '',
    this.title = '',
    this.subtitle = '',
    this.link = '',
    this.linkAndroid = '',
    this.linkIos = '',
  });

  /// Icon URL; empty when not sent.
  final String icon;
  final String title;
  final String subtitle;

  /// Where a tap leads; the platform's own link wins over it, as with buttons.
  final String link;
  final String linkAndroid;
  final String linkIos;

  /// The header shows something: an icon, a title or a subtitle.
  bool get isNotEmpty =>
      icon.trim().isNotEmpty ||
      title.trim().isNotEmpty ||
      subtitle.trim().isNotEmpty;

  factory StoryHeaderElement.fromJson(Map<String, dynamic> json) =>
      StoryHeaderElement(
        icon: _text(json['icon']),
        title: _text(json['title']),
        subtitle: _text(json['subtitle']),
        link: _text(json['link']),
        linkAndroid: _text(json['link_android']),
        linkIos: _text(json['link_ios']),
      );
}

/// Text blocks over API v3, as the web SDK reads them: `bold` (else the old `text_bold`)
/// and `italic` (else `text_italic`) take `true`, `1` and `"true"`; the background
/// opacity is percents as calculateOpacity reads them (`"0.5"` — 0.5 %, `"50"` and `"50%"`
/// — 50 %), and a background colour without an opacity is opaque; `font_type` is read
/// regardless of case, `monospace` too. Behind the v3 gate, not the kit's.
extension StoryTextBlockV3 on StoryTextBlockElement {
  /// The server sent `font_size`; without it API v3 takes the kit's body text size.
  bool get hasFontSize => _hasFontSize;
}
