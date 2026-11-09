import 'package:flutter_test/flutter_test.dart';
import 'package:rees46_sdk/src/popups_v3/popup_v3.dart';

import 'fixtures.dart';

void main() {
  group('list-response.json', () {
    final fixture = popupsV3Fixture('list-response.json');
    final expectations = popupsV3Expect(fixture);
    final list = PopupsV3List.parse(fixture['payload'] as Map<String, Object?>);

    test('ttl as a string', () {
      expect(list.ttl, Duration(seconds: expectations['ttl_seconds'] as int));
    });

    test('mobile triggers are armed, manual is only manual', () {
      final byTrigger = <int>[
        for (final popup in list.popups)
          if (popup.trigger != PopupV3Trigger.manual) popup.id,
      ];
      expect(byTrigger, expectations['armed']);
      expect(<int>[
        for (final popup in list.popups)
          if (popup.trigger == PopupV3Trigger.manual) popup.id,
      ], expectations['manual_only']);
    });

    test('a web trigger and a web layout are skipped with a reason', () {
      final skipped = expectations['skipped_logged'] as Map<String, Object?>;
      expect(
        list.skipped.keys.map((id) => '$id').toSet(),
        skipped.keys.toSet(),
      );
      expect(list.skipped[517], contains('trigger'));
      expect(list.skipped[518], contains('layout'));
    });

    test('nulls take the defaults', () {
      final manual = list.popups.firstWhere((popup) => popup.id == 516);
      expect(manual.frequency, PopupV3Frequency.onceSession);
      expect(manual.targetScreens, isEmpty);
      final event = list.popups.firstWhere((popup) => popup.id == 515);
      expect(event.cooldownMinutes, 0);
      expect(event.triggerEvent, 'promo_view');
      final time = list.popups.firstWhere((popup) => popup.id == 514);
      expect(time.triggerDelay, const Duration(seconds: 10));
      expect(time.placement, PopupV3Placement.bottom);
      expect(time.isModal, isFalse);
    });

    test('excluded popups are kept for the debug log', () {
      expect(<Map<String, Object?>>[
        for (final item in list.excluded)
          <String, Object?>{'id': item.id, 'reason': item.reason},
      ], expectations['excluded_logged_in_debug']);
    });

    test('a promo list without {{promo_code}} needs no code', () {
      final promo = list.popups.firstWhere((popup) => popup.id == 519);
      expect(promo.promoCodeListId, '7');
      expect(promo.needsPromoCode, isFalse);
    });
  });

  test('popup-response.json: the manual popup', () {
    final fixture = popupsV3Fixture('popup-response.json');
    final popup = PopupV3.tryParse(
      (fixture['payload'] as Map<String, Object?>)['popup'],
    )!;
    expect(popup.id, popupsV3Expect(fixture)['id']);
    expect(popup.layout, PopupV3Layout.fullscreen);
    expect(popup.isModal, isTrue);
  });

  test('element-promo-code.json: a personal code element needs the code', () {
    final popup = PopupV3.tryParse(popupsV3Fixture('element-promo-code.json'))!;
    expect(popup.needsPromoCode, isTrue);
    expect(
      PopupV3(
        id: 1,
        layout: PopupV3Layout.modal,
        placement: PopupV3Placement.center,
        trigger: PopupV3Trigger.manual,
        promoCodeListId: '7',
        design: const <String, Object?>{
          'elements': <Object?>[
            <String, Object?>{
              'type': 'promoCode',
              'style': <String, Object?>{'promoSource': 'static'},
            },
          ],
        },
      ).needsPromoCode,
      isFalse,
    );
  });

  test('live-list-181-182.json: the banner and the modal of the demo shop', () {
    final fixture = popupsV3Fixture('live-list-181-182.json');
    final list = PopupsV3List.parse(fixture['payload'] as Map<String, Object?>);
    expect(list.popups.map((popup) => popup.id), <int>[181, 182]);
    final banner = list.popups.first;
    expect(banner.layout, PopupV3Layout.banner);
    expect(banner.placement, PopupV3Placement.top);
    expect(banner.trigger, PopupV3Trigger.appStart);
    expect(banner.frequency, PopupV3Frequency.onceSession);
    expect(banner.needsPromoCode, isFalse);
    final modal = list.popups.last;
    expect(modal.layout, PopupV3Layout.modal);
    expect(modal.placement, PopupV3Placement.center);
    expect(modal.isModal, isTrue);
  });

  test('ids as strings, unknown frequency, bad screens', () {
    final popup = PopupV3.tryParse(<String, Object?>{
      'id': '42',
      'layout': 'banner',
      'placement': 'center',
      'trigger_type': 'screen_open',
      'frequency': 'sometimes',
      'target_screens': <Object?>[' home ', '', null, 5],
      'cooldown_minutes': '15',
    })!;
    expect(popup.id, 42);
    expect(popup.placement, PopupV3Placement.top);
    expect(popup.frequency, PopupV3Frequency.onceSession);
    expect(popup.targetScreens, <String>['home', '5']);
    expect(popup.cooldownMinutes, 15);
    expect(popup.matchesScreen('home'), isTrue);
    expect(popup.matchesScreen(null), isFalse);
    expect(PopupV3.tryParse(<String, Object?>{'layout': 'modal'}), isNull);
  });
}
