import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rees46_sdk/rees46_sdk.dart';
import 'package:rees46_sdk/src/popups/popup_presenter.dart';
import 'package:rees46_sdk/src/ui/components/personalization_button.dart';
import 'package:rees46_sdk/src/ui/personalization_icons.dart';

// A 1x1 transparent PNG: a picture that loads without the network.
final Uint8List _pixel = Uint8List.fromList(<int>[
  0x89,
  0x50,
  0x4E,
  0x47,
  0x0D,
  0x0A,
  0x1A,
  0x0A,
  0x00,
  0x00,
  0x00,
  0x0D,
  0x49, //
  0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, 0x08, 0x06,
  0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00, 0x0A, 0x49, 0x44,
  0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00, 0x05, 0x00, 0x01, 0x0D,
  0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE, 0x42,
  0x60, 0x82,
]);

class _Harness {
  final List<int> tracked = <int>[];
  final List<String> opened = <String>[];
  int settingsOpened = 0;
  bool failLinks = false;
  DateTime clock = DateTime(2026, 10, 15, 12);
  late final PopupPresenter presenter = PopupPresenter(
    trackShown: (id) async => tracked.add(id),
    openUrl: (url) async {
      if (failLinks) throw StateError('no browser');
      opened.add(url);
      return true;
    },
    openNotificationSettings: () async => settingsOpened++,
    now: () => clock,
    image: (url) => url == 'broken' ? NetworkImage(url) : MemoryImage(_pixel),
  );
}

Future<_Harness> _pumpApp(
  WidgetTester tester, {
  EdgeInsets padding = EdgeInsets.zero,
}) async {
  tester.view
    ..physicalSize = const Size(400, 800)
    ..devicePixelRatio = 1
    ..padding = FakeViewPadding(top: padding.top, bottom: padding.bottom);
  addTearDown(tester.view.reset);
  final harness = _Harness();
  await tester.pumpWidget(
    const MaterialApp(home: Scaffold(body: Text('home'))),
  );
  return harness;
}

InAppPopup _popup({
  int id = 1,
  InAppPopupPosition position = InAppPopupPosition.center,
  Duration delay = Duration.zero,
  String? imageUrl,
  String? linkText,
  String? linkUrl,
  String? pushSubscribeText,
  String? closeText,
}) => InAppPopup(
  id: id,
  position: position,
  delay: delay,
  title: 'Title $id',
  text: 'Text $id',
  imageUrl: imageUrl,
  linkText: linkText,
  linkUrl: linkUrl,
  pushSubscribeText: pushSubscribeText,
  closeText: closeText,
);

final Finder _cross = find.byWidgetPredicate(
  (widget) =>
      widget is PersonalizationButton &&
      widget.iconStart == PersonalizationIcons.crossLarge,
);

void main() {
  testWidgets('shows a popup over the navigator and reports it once', (
    tester,
  ) async {
    final h = await _pumpApp(tester);

    h.presenter.receive(_popup());
    await tester.pumpAndSettle();

    expect(find.text('Title 1'), findsOneWidget);
    expect(find.text('Text 1'), findsOneWidget);
    expect(h.tracked, <int>[1]);

    await tester.tap(_cross);
    await tester.pumpAndSettle();
    expect(find.text('Title 1'), findsNothing);
    expect(h.tracked, <int>[1]);
  });

  testWidgets('a popup with nothing to show is dropped', (tester) async {
    final h = await _pumpApp(tester);
    final taken = <InAppPopup>[];

    h.presenter.receive(const InAppPopup(id: 0));
    h.presenter.onPopup = taken.add;
    h.presenter.receive(const InAppPopup(id: 0));
    await tester.pumpAndSettle();

    expect(find.byType(PersonalizationInAppPopup), findsNothing);
    expect(taken, isEmpty);
    expect(h.tracked, isEmpty);
  });

  testWidgets('waits out the delay the shop set', (tester) async {
    final h = await _pumpApp(tester);

    h.presenter.receive(_popup(delay: const Duration(seconds: 3)));
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('Title 1'), findsNothing);

    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(find.text('Title 1'), findsOneWidget);
  });

  testWidgets('a repeat within a minute is dropped, a later one is shown', (
    tester,
  ) async {
    final h = await _pumpApp(tester);

    h.presenter.receive(_popup());
    await tester.pumpAndSettle();
    await tester.tap(_cross);
    await tester.pumpAndSettle();

    h.clock = h.clock.add(const Duration(seconds: 59));
    h.presenter.receive(_popup());
    await tester.pumpAndSettle();
    expect(find.text('Title 1'), findsNothing);

    h.clock = h.clock.add(const Duration(seconds: 2));
    h.presenter.receive(_popup());
    await tester.pumpAndSettle();
    expect(find.text('Title 1'), findsOneWidget);
    expect(h.tracked, <int>[1, 1]);
  });

  testWidgets('one popup at a time; the next follows when it closes', (
    tester,
  ) async {
    final h = await _pumpApp(tester);

    h.presenter
      ..receive(_popup(id: 1))
      ..receive(_popup(id: 2))
      ..receive(_popup(id: 2));
    await tester.pumpAndSettle();
    expect(find.text('Title 1'), findsOneWidget);
    expect(find.text('Title 2'), findsNothing);

    await tester.tap(_cross);
    await tester.pumpAndSettle();
    expect(find.text('Title 2'), findsOneWidget);
    expect(h.tracked, <int>[1, 2]);
  });

  testWidgets('onPopup takes the popup; the SDK neither shows nor reports it', (
    tester,
  ) async {
    final h = await _pumpApp(tester);
    final taken = <InAppPopup>[];
    h.presenter.onPopup = taken.add;

    h.presenter.receive(_popup());
    await tester.pumpAndSettle();

    expect(taken.map((popup) => popup.id), <int>[1]);
    expect(find.text('Title 1'), findsNothing);
    expect(h.tracked, isEmpty);

    // Not reported by the app — the server's repeat comes through again.
    h.presenter.receive(_popup());
    await tester.pumpAndSettle();
    expect(taken, hasLength(2));

    // Reported — a repeat within a minute is dropped.
    h.presenter
      ..markShown(1)
      ..receive(_popup());
    await tester.pumpAndSettle();
    expect(taken, hasLength(2));
  });

  testWidgets('a popup held back is shown on request', (tester) async {
    final h = await _pumpApp(tester);
    InAppPopup? held;
    h.presenter.onPopup = (popup) => held = popup;

    h.presenter.receive(_popup());
    await tester.pumpAndSettle();
    expect(find.text('Title 1'), findsNothing);

    final closed = h.presenter.present(held!);
    await tester.pumpAndSettle();
    expect(find.text('Title 1'), findsOneWidget);
    expect(h.tracked, <int>[1]);

    var done = false;
    closed.then((_) => done = true);
    await tester.tap(_cross);
    await tester.pumpAndSettle();
    expect(done, isTrue);
  });

  testWidgets('a popup the app asks for is shown again within the minute', (
    tester,
  ) async {
    final h = await _pumpApp(tester);

    for (var i = 0; i < 2; i++) {
      h.presenter.present(_popup());
      await tester.pumpAndSettle();
      expect(find.text('Title 1'), findsOneWidget);
      await tester.tap(_cross);
      await tester.pumpAndSettle();
    }
    expect(h.tracked, <int>[1, 1]);
  });

  testWidgets('automatic presentation off: nothing is shown', (tester) async {
    final h = await _pumpApp(tester);
    h.presenter.autoPresentation = false;

    h.presenter.receive(_popup());
    await tester.pumpAndSettle();

    expect(find.text('Title 1'), findsNothing);
    expect(h.tracked, isEmpty);
  });

  testWidgets('no navigator: dropped after the wait, not reported', (
    tester,
  ) async {
    final h = await _pumpApp(tester);
    await tester.pumpWidget(const SizedBox());

    h.presenter.receive(_popup());
    await tester.pump(PopupPresenter.navigatorWait);
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.byType(PersonalizationInAppPopup), findsNothing);
    expect(h.tracked, isEmpty);
  });

  testWidgets('shown over the root navigator, past a nested one', (
    tester,
  ) async {
    final h = await _pumpApp(tester);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Navigator(
            onGenerateRoute: (_) =>
                MaterialPageRoute<void>(builder: (_) => const Text('tab')),
          ),
        ),
      ),
    );

    final navigators = tester.stateList<NavigatorState>(find.byType(Navigator));
    expect(navigators, hasLength(2));
    expect(PopupPresenter.rootNavigator(), same(navigators.first));

    h.presenter.receive(_popup());
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byWidget(navigators.last.widget),
        matching: find.byType(PersonalizationInAppPopup),
      ),
      findsNothing,
    );
    expect(find.byType(PersonalizationInAppPopup), findsOneWidget);
  });

  testWidgets('the link button opens the link and closes the popup', (
    tester,
  ) async {
    final h = await _pumpApp(tester);

    h.presenter.receive(
      _popup(linkText: 'Open', linkUrl: 'https://example.com'),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(h.opened, <String>['https://example.com']);
    expect(find.text('Title 1'), findsNothing);
  });

  testWidgets('a link that fails to open is logged, not thrown', (
    tester,
  ) async {
    final h = await _pumpApp(tester)
      ..failLinks = true;

    h.presenter.receive(_popup(linkText: 'Open', linkUrl: 'https://x.test'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    // An uncaught error would fail the test on its own.
    expect(find.text('Title 1'), findsNothing);
  });

  testWidgets('the push subscription opens the notification settings', (
    tester,
  ) async {
    final h = await _pumpApp(tester);

    h.presenter.receive(
      _popup(
        linkText: 'Open',
        linkUrl: 'https://example.com',
        pushSubscribeText: 'Subscribe',
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Open'), findsNothing);
    await tester.tap(find.text('Subscribe'));
    await tester.pumpAndSettle();

    expect(h.settingsOpened, 1);
    expect(h.opened, isEmpty);
  });

  testWidgets('the close button closes', (tester) async {
    final h = await _pumpApp(tester);

    h.presenter.receive(_popup(closeText: 'Later'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Later'));
    await tester.pumpAndSettle();

    expect(find.text('Title 1'), findsNothing);
  });

  testWidgets('a tap past the popup closes it only when it has no buttons', (
    tester,
  ) async {
    final h = await _pumpApp(tester);

    h.presenter.receive(_popup(id: 1, closeText: 'Later'));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();
    expect(find.text('Title 1'), findsOneWidget);

    await tester.tap(find.text('Later'));
    await tester.pumpAndSettle();

    h.presenter.receive(_popup(id: 2));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();
    expect(find.text('Title 2'), findsNothing);
  });

  testWidgets(
    'positions: centred, at the top and at the bottom with 16 margin',
    (tester) async {
      final h = await _pumpApp(tester);

      Future<Rect> shown(InAppPopupPosition position, int id) async {
        h.presenter.receive(_popup(id: id, position: position));
        await tester.pumpAndSettle();
        final rect = tester.getRect(find.byType(PersonalizationInAppPopup));
        await tester.tap(_cross);
        await tester.pumpAndSettle();
        return rect;
      }

      final centre = await shown(InAppPopupPosition.center, 1);
      final top = await shown(InAppPopupPosition.top, 2);
      final bottom = await shown(InAppPopupPosition.bottom, 3);

      expect(centre.width, 368); // 400 - 2 * 16, under the 370 cap
      expect(centre.center.dy, closeTo(400, 0.5));
      expect(top.top, 16);
      expect(bottom.bottom, 800 - 16);
    },
  );

  testWidgets(
    'an unknown position is fullscreen, its cross below the status bar',
    (tester) async {
      final h = await _pumpApp(
        tester,
        padding: const EdgeInsets.only(top: 47, bottom: 34),
      );

      h.presenter.receive(
        _popup(position: InAppPopupPosition.unknown, closeText: 'Later'),
      );
      await tester.pumpAndSettle();

      final popup = tester.getRect(find.byType(PersonalizationInAppPopup));
      expect(popup, const Rect.fromLTWH(0, 0, 400, 800));
      expect(tester.getRect(_cross).top, 47 + 24);
      expect(
        tester.getRect(find.text('Later')).bottom,
        lessThan(800 - 34 - 24),
      );
    },
  );

  testWidgets('a picture that loads makes the image view', (tester) async {
    final h = await _pumpApp(tester);
    // Decoding runs outside the fake clock: decode the picture up front, so the
    // presenter finds it in the image cache.
    await tester.runAsync(
      () => precacheImage(
        MemoryImage(_pixel),
        PopupPresenter.rootNavigator()!.context,
      ),
    );

    h.presenter.receive(_popup(imageUrl: 'https://example.com/a.png'));
    await tester.pumpAndSettle();

    final popup = tester.widget<PersonalizationInAppPopup>(
      find.byType(PersonalizationInAppPopup),
    );
    expect(popup.view, PersonalizationInAppPopupView.image);
    expect(popup.image, isA<MemoryImage>());
    // A square picture shows whole: its own 1:1, nudged to 45% of the screen height
    // (368 / (0.45 * (800 - 32))).
    expect(popup.imageAspectRatio, closeTo(368 / (0.45 * 768), 0.001));
  });

  group('picture proportion', () {
    double aspect(double own, {double height = 800}) =>
        PopupPresenter.imageAspect(own, width: 370, availableHeight: height);

    test('its own when it fits', () {
      expect(aspect(1.5), 1.5);
      expect(aspect(1.2), 1.2);
    });

    test('no wider than 2:1', () => expect(aspect(4), 2));

    test('no taller than 4:5', () => expect(aspect(0.5, height: 2000), 0.8));

    test('no taller than 45% of the height', () {
      // 370 / (0.45 * 600) ≈ 1.37: a square picture is cropped a little.
      expect(aspect(1, height: 600), closeTo(1.37, 0.01));
    });

    test('a very short screen never asks for wider than 2:1', () {
      expect(aspect(1, height: 200), 2);
    });
  });

  testWidgets('a picture that fails leaves the popup without it', (
    tester,
  ) async {
    final h = await _pumpApp(tester);

    h.presenter.receive(_popup(imageUrl: 'broken'));
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pumpAndSettle();

    final popup = tester.widget<PersonalizationInAppPopup>(
      find.byType(PersonalizationInAppPopup),
    );
    expect(popup.view, PersonalizationInAppPopupView.text);
    expect(popup.image, isNull);
    expect(h.tracked, <int>[1]);
  });

  testWidgets('a CupertinoApp gets popups too', (tester) async {
    final h = await _pumpApp(tester);
    await tester.pumpWidget(const CupertinoApp(home: Text('home')));

    h.presenter.receive(_popup());
    await tester.pumpAndSettle();

    expect(find.text('Title 1'), findsOneWidget);
    expect(h.tracked, <int>[1]);
  });

  testWidgets('the queue goes on after the navigator goes away under a popup', (
    tester,
  ) async {
    final h = await _pumpApp(tester);

    h.presenter.receive(_popup(id: 1));
    await tester.pumpAndSettle();
    expect(find.text('Title 1'), findsOneWidget);

    // The app swaps its root MaterialApp, say after a login: the old navigator and the
    // popup on it are gone without being closed.
    await tester.pumpWidget(
      MaterialApp(key: UniqueKey(), home: const Text('signed in')),
    );
    await tester.pumpAndSettle();

    h.presenter.receive(_popup(id: 2));
    await tester.pumpAndSettle();
    expect(find.text('Title 2'), findsOneWidget);
    expect(h.tracked, <int>[1, 2]);
  });

  testWidgets('the queue goes on when the app clears the stack under a popup', (
    tester,
  ) async {
    final h = await _pumpApp(tester);

    h.presenter
      ..receive(_popup(id: 1))
      ..receive(_popup(id: 2));
    await tester.pumpAndSettle();
    expect(find.text('Title 1'), findsOneWidget);

    PopupPresenter.rootNavigator()!.popUntil((route) => route.isFirst);
    await tester.pumpAndSettle();

    expect(find.text('Title 1'), findsNothing);
    expect(find.text('Title 2'), findsOneWidget);
  });

  testWidgets(
    'fullscreen: the status bar icons follow the popup, not the photo',
    (tester) async {
      final h = await _pumpApp(tester);
      await tester.runAsync(
        () => precacheImage(
          MemoryImage(_pixel),
          PopupPresenter.rootNavigator()!.context,
        ),
      );

      h.presenter.receive(
        _popup(position: InAppPopupPosition.unknown, imageUrl: 'x'),
      );
      await tester.pumpAndSettle();

      final region = tester.widget<AnnotatedRegion<SystemUiOverlayStyle>>(
        find.byType(AnnotatedRegion<SystemUiOverlayStyle>).last,
      );
      expect(region.value, SystemUiOverlayStyle.dark);
    },
  );
}
