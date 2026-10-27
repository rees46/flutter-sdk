import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:rees46_sdk/rees46_sdk.dart';
import 'package:rees46_sdk/src/pigeon/personalization_api.g.dart' as pigeon;
import 'package:rees46_sdk/src/popups/popup_dispatcher.dart';
import 'package:rees46_sdk/src/popups/popup_presenter.dart';

class _FakeApi extends pigeon.PersonalizationHostApi {
  final List<(int, String?)> tracked = <(int, String?)>[];

  @override
  Future<void> initialize(pigeon.InitConfig config) async {}

  @override
  Future<void> trackPopupShown(int popupId, String? shopId) async =>
      tracked.add((popupId, shopId));
}

String _json(int id) => jsonEncode(<String, Object?>{
  'id': id,
  'position': 'centered',
  'delay': 0,
  'components': <String, Object?>{'header': 'Popup $id'},
});

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(PopupDispatcher.instance.reset);
  tearDown(PopupPresenter.reset);

  Future<(PersonalizationSdk, _FakeApi, List<InAppPopup>)> initialized(
    String shopId, {
    bool ownHandler = true,
  }) async {
    final api = _FakeApi();
    final sdk = PersonalizationSdk(api: api, shopId: shopId);
    final taken = <InAppPopup>[];
    if (ownHandler) sdk.onPopup = taken.add;
    await sdk.initialize(SdkInitConfig(shopId: shopId));
    return (sdk, api, taken);
  }

  testWidgets('a popup reaches the handle of the shop it came for', (
    tester,
  ) async {
    final (_, _, takenA) = await initialized('shop-a');
    final (_, _, takenB) = await initialized('shop-b');

    PopupDispatcher.instance
      ..onPopup('shop-b', _json(2))
      ..onPopup('shop-c', _json(3))
      ..onPopup('shop-a', 'not json');
    await tester.pump(Duration.zero);

    expect(takenA, isEmpty);
    expect(takenB.map((popup) => popup.title), <String>['Popup 2']);
    expect(takenB.single.shopId, 'shop-b');
  });

  testWidgets(
    'REES46.onPopup takes popups of shops without a handler of their own',
    (tester) async {
      await initialized('shop-a', ownHandler: false);
      final (_, _, takenB) = await initialized('shop-b');
      final shared = <InAppPopup>[];
      REES46.onPopup = shared.add;

      PopupDispatcher.instance
        ..onPopup('shop-a', _json(1))
        ..onPopup('shop-b', _json(2));
      await tester.pump(Duration.zero);

      expect(shared.map((popup) => (popup.id, popup.shopId)), <(int, String?)>[
        (1, 'shop-a'),
      ]);
      expect(takenB.map((popup) => popup.id), <int>[2]);
    },
  );

  testWidgets('tracking.popupShown reports for the shop and stops a repeat', (
    tester,
  ) async {
    final (sdk, api, taken) = await initialized('shop-a');

    PopupDispatcher.instance.onPopup('shop-a', _json(5));
    await tester.pump(Duration.zero);
    await sdk.tracking.popupShown(taken.single.id);
    PopupDispatcher.instance.onPopup('shop-a', _json(5));
    await tester.pump(Duration.zero);

    expect(api.tracked, <(int, String?)>[(5, 'shop-a')]);
    expect(taken, hasLength(1));
  });
}
