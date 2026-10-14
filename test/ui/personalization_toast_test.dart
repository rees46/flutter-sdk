import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rees46_sdk/src/ui/personalization_ui.dart';

const Duration _fade = PersonalizationToast.fadeDuration;

/// A screen with a button that shows a toast, and a counter of taps on the
/// area under it.
class _Screen extends StatelessWidget {
  const _Screen({required this.onShow, required this.onBackgroundTap});

  final void Function(BuildContext context) onShow;
  final VoidCallback onBackgroundTap;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: <Widget>[
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onBackgroundTap,
          ),
        ),
        Center(
          child: Builder(
            builder: (context) => TextButton(
              onPressed: () => onShow(context),
              child: const Text('show'),
            ),
          ),
        ),
      ],
    );
  }
}

Future<void> _pumpScreen(
  WidgetTester tester, {
  required void Function(BuildContext context) onShow,
  VoidCallback? onBackgroundTap,
}) {
  return tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: _Screen(
          onShow: onShow,
          onBackgroundTap: onBackgroundTap ?? () {},
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('the pill is 50 high, float-coloured, with Elevation 2', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Center(child: PersonalizationToast(text: 'Copied')),
      ),
    );

    expect(tester.getSize(find.byType(PersonalizationToast)).height, 50);
    final decoration =
        tester
                .widget<DecoratedBox>(
                  find.descendant(
                    of: find.byType(PersonalizationToast),
                    matching: find.byType(DecoratedBox),
                  ),
                )
                .decoration
            as BoxDecoration;
    expect(decoration.color, PersonalizationColors.light.backgroundFloat);
    expect(
      decoration.borderRadius,
      BorderRadius.circular(PersonalizationRadius.toast),
    );
    expect(decoration.boxShadow, hasLength(PersonalizationElevation.e2.length));
    for (int i = 0; i < decoration.boxShadow!.length; i++) {
      expect(
        decoration.boxShadow![i].offset,
        PersonalizationElevation.e2[i].offset,
      );
      expect(
        decoration.boxShadow![i].color,
        PersonalizationColors.light.shadowHeavy,
      );
    }
    final style = tester.widget<Text>(find.text('Copied')).style!;
    expect(style.fontWeight, FontWeight.w500);
    expect(style.color, PersonalizationColors.light.textPrimary);
  });

  testWidgets('shows at the bottom and hides after the duration', (
    tester,
  ) async {
    addTearDown(tester.view.reset);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(400, 800);
    tester.view.padding = const FakeViewPadding(top: 40, bottom: 30);

    await _pumpScreen(
      tester,
      onShow: (context) => PersonalizationToast.show(
        context,
        'Copied',
        duration: const Duration(seconds: 1),
      ),
    );
    await tester.tap(find.text('show'));
    await tester.pump();
    await tester.pump(_fade);

    expect(find.text('Copied'), findsOneWidget);
    final pill = tester.getRect(find.byType(PersonalizationToast));
    expect(pill.bottom, 800 - 30 - 16);
    expect(pill.center.dx, 200);

    // Still there just before the duration runs out.
    await tester.pump(const Duration(seconds: 1) - _fade - _ms);
    expect(find.text('Copied'), findsOneWidget);

    await tester.pump(_ms);
    await tester.pumpAndSettle();
    expect(find.text('Copied'), findsNothing);
  });

  testWidgets('shows at the top below the safe area', (tester) async {
    addTearDown(tester.view.reset);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(400, 800);
    tester.view.padding = const FakeViewPadding(top: 40, bottom: 30);

    await _pumpScreen(
      tester,
      onShow: (context) => PersonalizationToast.show(
        context,
        'Code copied to clipboard',
        position: PersonalizationToastPosition.top,
      ),
    );
    await tester.tap(find.text('show'));
    await tester.pump();
    await tester.pump(_fade);

    expect(tester.getRect(find.byType(PersonalizationToast)).top, 40 + 16);

    await _runOut(tester);
    expect(find.byType(PersonalizationToast), findsNothing);
  });

  testWidgets('a long text wraps inside the screen width less 16 a side', (
    tester,
  ) async {
    addTearDown(tester.view.reset);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(400, 800);

    await _pumpScreen(
      tester,
      onShow: (context) => PersonalizationToast.show(context, 'word ' * 40),
    );
    await tester.tap(find.text('show'));
    await tester.pump();

    final pill = tester.getRect(find.byType(PersonalizationToast));
    expect(pill.left, 16);
    expect(pill.right, 400 - 16);
    expect(pill.height, greaterThan(50));

    await _runOut(tester);
  });

  testWidgets('a new toast replaces the one on screen', (tester) async {
    await _pumpScreen(
      tester,
      onShow: (context) {
        PersonalizationToast.show(context, 'First');
        PersonalizationToast.show(context, 'Second');
      },
    );
    await tester.tap(find.text('show'));
    await tester.pump();

    expect(find.text('First'), findsNothing);
    expect(find.text('Second'), findsOneWidget);
    expect(find.byType(PersonalizationToast), findsOneWidget);

    await _runOut(tester);
    expect(find.byType(PersonalizationToast), findsNothing);
  });

  testWidgets('the replaced toast\'s timer does not cut the new one short', (
    tester,
  ) async {
    late BuildContext screen;
    await _pumpScreen(tester, onShow: (context) => screen = context);
    await tester.tap(find.text('show'));

    PersonalizationToast.show(screen, 'First');
    await tester.pump(const Duration(milliseconds: 1500));
    PersonalizationToast.show(screen, 'Second');
    await tester.pump();

    // The first one's two seconds are up; the second has shown for 0.5 s.
    await tester.pump(const Duration(milliseconds: 1000));
    expect(find.text('Second'), findsOneWidget);

    await _runOut(tester);
    expect(find.byType(PersonalizationToast), findsNothing);
  });

  testWidgets('touches go through to the screen underneath', (tester) async {
    int taps = 0;
    await _pumpScreen(
      tester,
      onShow: (context) => PersonalizationToast.show(context, 'Copied'),
      onBackgroundTap: () => taps++,
    );
    await tester.tap(find.text('show'));
    await tester.pump();
    await tester.pump(_fade);

    await tester.tapAt(tester.getCenter(find.byType(PersonalizationToast)));
    expect(taps, 1);

    await _runOut(tester);
  });

  testWidgets('the text is announced where the platform supports it', (
    tester,
  ) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(supportsAnnounce: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);

    await _pumpScreen(
      tester,
      onShow: (context) => PersonalizationToast.show(context, 'Copied'),
    );
    await tester.tap(find.text('show'));
    await tester.pump();

    expect(
      tester.takeAnnouncements().map((announcement) => announcement.message),
      contains('Copied'),
    );

    await _runOut(tester);
  });

  testWidgets('without announcements the toast is a live region', (
    tester,
  ) async {
    // Android: announcement events are deprecated there.
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures();
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    final semantics = tester.ensureSemantics();
    await _pumpScreen(
      tester,
      onShow: (context) => PersonalizationToast.show(context, 'Copied'),
    );
    await tester.tap(find.text('show'));
    await tester.pump();
    // Fully transparent, the toast is left out of the semantics tree.
    await tester.pump(_fade);

    expect(
      tester.getSemantics(find.byType(PersonalizationToast)),
      isSemantics(label: 'Copied', isLiveRegion: true),
    );

    await _runOut(tester);
    semantics.dispose();
  });
}

const Duration _ms = Duration(milliseconds: 1);

/// Lets the default two seconds run out and the fade-out finish.
Future<void> _runOut(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 3));
  await tester.pumpAndSettle();
}
