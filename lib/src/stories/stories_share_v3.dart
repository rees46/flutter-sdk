part of 'stories_response.dart';

/// Sharing of a campaign over API v3. Behind the v3 gate (`src/v3/personalization_v3.dart`),
/// not the kit's.
extension StoryShareV3 on Story {
  /// The shop allows sharing the campaign (`shareable`, API v3). A missing field allows it,
  /// only `false` forbids.
  bool get shareable => _shareable;

  /// "Share" link of the campaign (`share_url`, API v3); empty when not sent. Product
  /// campaigns have only this one, their slides have none: a slide shares it with its
  /// id in `r46_slide`.
  String get shareUrl => _shareUrl;
}

/// Sharing of a slide over API v3. Behind the v3 gate (`src/v3/personalization_v3.dart`),
/// not the kit's.
extension StorySlideShareV3 on StorySlide {
  /// "Share" link of the slide (`share_url`, API v3); empty when not sent.
  String get shareUrl => _shareUrl;
}
