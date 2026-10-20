import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rees46_sdk/rees46_sdk.dart';

Map<String, Object?> _popup({
  Object? position = 'centered',
  Map<String, Object?>? components,
  Map<String, Object?>? actions,
}) => <String, Object?>{
  'id': 42,
  'position': position,
  'delay': 3,
  'components': ?components,
  'popup_actions': ?actions,
};

void main() {
  test('positions from the admin; anything else is unknown', () {
    InAppPopupPosition position(Object? value) =>
        InAppPopup.fromJson(_popup(position: value)).position;

    expect(position('centered'), InAppPopupPosition.center);
    expect(position('top'), InAppPopupPosition.top);
    expect(position('fixed_bottom'), InAppPopupPosition.bottom);
    expect(position(''), InAppPopupPosition.unknown);
    expect(position('slide_left'), InAppPopupPosition.unknown);
    expect(position(null), InAppPopupPosition.unknown);
  });

  test('id, delay and components', () {
    final popup = InAppPopup.fromJson(
      _popup(
        components: <String, Object?>{
          'header': 'Sale',
          'text': 'Up to 50%',
          'image': 'https://example.com/a.jpg',
        },
      ),
    );

    expect(popup.id, 42);
    expect(popup.delay, const Duration(seconds: 3));
    expect(popup.title, 'Sale');
    expect(popup.text, 'Up to 50%');
    expect(popup.imageUrl, 'https://example.com/a.jpg');
  });

  test('blank texts count as missing', () {
    final popup = InAppPopup.fromJson(
      _popup(
        components: <String, Object?>{'header': ' ', 'image': ''},
        actions: <String, Object?>{
          'close': <String, Object?>{'button_text': ''},
        },
      ),
    );

    expect(popup.title, isNull);
    expect(popup.imageUrl, isNull);
    expect(popup.closeText, isNull);
  });

  group('link', () {
    final json = _popup(
      actions: <String, Object?>{
        'link': <String, Object?>{
          'button_text': 'Open',
          'link_android': 'app://android',
          'link_ios': 'app://ios',
          'link_web': 'https://example.com',
        },
        'close': <String, Object?>{'button_text': 'Later'},
      },
    );

    test('this platform first', () {
      expect(
        InAppPopup.fromJson(json, platform: TargetPlatform.android).linkUrl,
        'app://android',
      );
      expect(
        InAppPopup.fromJson(json, platform: TargetPlatform.iOS).linkUrl,
        'app://ios',
      );
    });

    test('then the web one, then the other platform', () {
      final web = _popup(
        actions: <String, Object?>{
          'link': <String, Object?>{
            'link_ios': 'app://ios',
            'link_web': 'https://example.com',
          },
        },
      );
      final otherOnly = _popup(
        actions: <String, Object?>{
          'link': <String, Object?>{'link_ios': 'app://ios'},
        },
      );

      expect(
        InAppPopup.fromJson(web, platform: TargetPlatform.android).linkUrl,
        'https://example.com',
      );
      expect(
        InAppPopup.fromJson(
          otherOnly,
          platform: TargetPlatform.android,
        ).linkUrl,
        'app://ios',
      );
    });

    test('buttons', () {
      final popup = InAppPopup.fromJson(json);

      expect(popup.linkText, 'Open');
      expect(popup.actionText, 'Open');
      expect(popup.closeText, 'Later');
      expect(popup.pushSubscribeText, isNull);
    });
  });

  test('the push subscription takes the place of the link button', () {
    final popup = InAppPopup.fromJson(
      _popup(
        actions: <String, Object?>{
          'link': <String, Object?>{'button_text': 'Open'},
          'system_mobile_push_subscribe': <String, Object?>{
            'button_text': 'Subscribe',
          },
        },
      ),
    );

    expect(popup.pushSubscribeText, 'Subscribe');
    expect(popup.actionText, 'Subscribe');
  });

  test('numbers sent as strings and unexpected types', () {
    final popup = InAppPopup.fromJson(<String, Object?>{
      'id': '7',
      'delay': 2.0,
      'components': 'not a map',
      'popup_actions': <String, Object?>{'link': 5},
    });

    expect(popup.id, 7);
    expect(popup.delay, const Duration(seconds: 2));
    expect(popup.title, isNull);
    expect(popup.linkUrl, isNull);
  });

  test('components and actions sent as JSON inside a string', () {
    final popup = InAppPopup.fromJson(<String, Object?>{
      'id': 3,
      'components': '{"header":"Sale","text":"Up to 50%"}',
      'popup_actions': '{"close":{"button_text":"Later"}}',
    });

    expect(popup.title, 'Sale');
    expect(popup.closeText, 'Later');
    expect(popup.hasContent, isTrue);
    expect(InAppPopup.fromJson(<String, Object?>{'id': 0}).hasContent, isFalse);
  });
}
