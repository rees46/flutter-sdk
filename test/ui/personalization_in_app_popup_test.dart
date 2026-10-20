import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rees46_sdk/src/ui/personalization_ui.dart';

Widget _host(Widget popup, {ThemeData? theme}) => MaterialApp(
  theme: theme,
  home: Align(
    alignment: Alignment.topLeft,
    child: SizedBox(width: 400, height: 600, child: popup),
  ),
);

final Finder _cross = find.byWidgetPredicate(
  (widget) =>
      widget is PersonalizationButton &&
      widget.iconStart == PersonalizationIcons.crossLarge,
);

/// The shadow of the popup card: the nearest decoration above its clip.
List<BoxShadow> _shadows(WidgetTester tester) {
  final clip = find
      .descendant(
        of: find.byType(PersonalizationInAppPopup),
        matching: find.byType(ClipRRect),
      )
      .first;
  final box = tester.widget<DecoratedBox>(
    find.ancestor(of: clip, matching: find.byType(DecoratedBox)).first,
  );
  return (box.decoration as BoxDecoration).boxShadow ?? const <BoxShadow>[];
}

void main() {
  testWidgets('the cross is a round overlay in the corner in every view', (
    tester,
  ) async {
    for (final presentation in PersonalizationInAppPopupPresentation.values) {
      final pad = presentation == PersonalizationInAppPopupPresentation.modal
          ? PersonalizationSpacing.paddingModal
          : PersonalizationSpacing.paddingFullScreen;
      for (final view in PersonalizationInAppPopupView.values) {
        final reason = '$presentation, $view';
        await tester.pumpWidget(
          _host(
            PersonalizationInAppPopup(
              view: view,
              presentation: presentation,
              title: 'Title',
              text: 'Text',
              actionText: 'Go',
              closeText: 'Later',
            ),
          ),
        );

        expect(_cross, findsOneWidget, reason: reason);
        expect(
          tester.widget<PersonalizationButton>(_cross).rounded,
          isTrue,
          reason: reason,
        );
        // Over the content, not a row of a column.
        expect(
          find.ancestor(of: _cross, matching: find.byType(Column)),
          findsNothing,
          reason: reason,
        );
        final popup = tester.getRect(find.byType(PersonalizationInAppPopup));
        final cross = tester.getRect(_cross);
        expect(
          cross.topRight,
          popup.topRight + Offset(-pad, pad),
          reason: reason,
        );
        expect(cross.width, cross.height, reason: reason);
      }
    }
  });

  testWidgets('the cross keeps its solid backing over a photo too', (
    tester,
  ) async {
    // The design's dark cross over a photo (white on white 5%) vanishes on the light
    // product photos shops send; the plain secondary one shows on any picture.
    for (final view in PersonalizationInAppPopupView.values) {
      await tester.pumpWidget(_host(PersonalizationInAppPopup(view: view)));

      expect(
        tester.widget<PersonalizationButton>(_cross).onDark,
        isFalse,
        reason: '$view',
      );
      final backing = tester.widget<DecoratedBox>(
        find.ancestor(of: _cross, matching: find.byType(DecoratedBox)).first,
      );
      expect(
        (backing.decoration as BoxDecoration).color,
        PersonalizationColors.light.backgroundCard,
        reason: '$view',
      );
    }
  });

  testWidgets('buttons are 12 apart in a modal and 16 in a fullscreen popup', (
    tester,
  ) async {
    const gaps = <(PersonalizationInAppPopupPresentation, double)>[
      (PersonalizationInAppPopupPresentation.modal, PersonalizationSpacing.lg),
      (
        PersonalizationInAppPopupPresentation.fullscreen,
        PersonalizationSpacing.xl,
      ),
    ];
    for (final (presentation, gap) in gaps) {
      await tester.pumpWidget(
        _host(
          PersonalizationInAppPopup(
            view: PersonalizationInAppPopupView.text,
            presentation: presentation,
            actionText: 'Go',
            closeText: 'Later',
          ),
        ),
      );

      final action = find.widgetWithText(PersonalizationButton, 'Go');
      final close = find.widgetWithText(PersonalizationButton, 'Later');
      expect(
        tester.getTopLeft(close).dy - tester.getBottomLeft(action).dy,
        gap,
        reason: '$presentation',
      );
    }
  });

  testWidgets('a modal casts Elevation 3 in the scheme shadow colour', (
    tester,
  ) async {
    final schemes = <(ThemeData, PersonalizationColors)>[
      (ThemeData(), PersonalizationColors.light),
      (ThemeData(brightness: Brightness.dark), PersonalizationColors.dark),
    ];
    for (final (theme, colors) in schemes) {
      await tester.pumpWidget(
        _host(
          const PersonalizationInAppPopup(
            view: PersonalizationInAppPopupView.text,
          ),
          theme: theme,
        ),
      );
      // MaterialApp animates a theme change.
      await tester.pumpAndSettle();

      final shadows = _shadows(tester);
      expect(shadows, hasLength(PersonalizationElevation.e3.length));
      for (int i = 0; i < shadows.length; i++) {
        final expected = PersonalizationElevation.e3[i];
        expect(shadows[i].offset, expected.offset);
        expect(shadows[i].blurRadius, expected.blurRadius);
        expect(shadows[i].color, colors.shadowHeavy);
      }
    }
  });

  testWidgets('a fullscreen popup casts no shadow', (tester) async {
    await tester.pumpWidget(
      _host(
        const PersonalizationInAppPopup(
          view: PersonalizationInAppPopupView.text,
          presentation: PersonalizationInAppPopupPresentation.fullscreen,
        ),
      ),
    );

    expect(_shadows(tester), isEmpty);
  });

  group('height by content', () {
    // In a scroll view the height is unbounded: the popup sizes to its content.
    Widget scrolling(PersonalizationInAppPopupView view) => MaterialApp(
      home: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: 370,
          height: 800,
          child: SingleChildScrollView(
            child: PersonalizationInAppPopup(
              view: view,
              title: 'Title',
              text: 'Text',
              actionText: 'Open',
              closeText: 'Later',
              image: const _NoImage(),
            ),
          ),
        ),
      ),
    );

    for (final view in PersonalizationInAppPopupView.values) {
      testWidgets('$view lays out without overflow', (tester) async {
        await tester.pumpWidget(scrolling(view));

        expect(tester.takeException(), isNull);
        final size = tester.getSize(find.byType(PersonalizationInAppPopup));
        expect(size.width, 370);
        expect(size.height, inExclusiveRange(100, 800));
      });
    }

    testWidgets('the picture on top keeps 16:10', (tester) async {
      await tester.pumpWidget(scrolling(PersonalizationInAppPopupView.image));

      final image = tester.getSize(find.byType(Image));
      expect(image.width / image.height, closeTo(1.6, 0.01));
    });

    testWidgets('the picture on top takes the proportion given', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 370,
              child: SingleChildScrollView(
                child: PersonalizationInAppPopup(
                  title: 'Title',
                  image: const _NoImage(),
                  imageAspectRatio: 1,
                ),
              ),
            ),
          ),
        ),
      );

      final image = tester.getSize(find.byType(Image));
      expect(image.width, 370);
      expect(image.height, 370);
    });

    testWidgets('the picture behind is a 4:5 card', (tester) async {
      await tester.pumpWidget(
        scrolling(PersonalizationInAppPopupView.imageBackground),
      );

      final size = tester.getSize(find.byType(PersonalizationInAppPopup));
      expect(size.width / size.height, closeTo(0.8, 0.01));
    });

    testWidgets('the text starts below the cross', (tester) async {
      await tester.pumpWidget(scrolling(PersonalizationInAppPopupView.text));

      expect(
        tester.getRect(find.text('Title')).top,
        greaterThanOrEqualTo(tester.getRect(_cross).bottom),
      );
    });
  });

  testWidgets('a fullscreen popup keeps its controls inside the safe area', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(400, 800),
            padding: EdgeInsets.only(top: 47, bottom: 34),
          ),
          child: SizedBox(
            width: 400,
            height: 800,
            child: PersonalizationInAppPopup(
              view: PersonalizationInAppPopupView.imageBackground,
              presentation: PersonalizationInAppPopupPresentation.fullscreen,
              title: 'Title',
              actionText: 'Open',
              image: const _NoImage(),
            ),
          ),
        ),
      ),
    );

    expect(tester.getRect(_cross).top, 47 + 24);
    expect(tester.getRect(find.text('Open')).bottom, lessThan(800 - 34 - 24));
  });

  testWidgets('without an icon builder the cross draws itself', (tester) async {
    await tester.pumpWidget(
      _host(const PersonalizationInAppPopup(title: 'Title')),
    );

    expect(
      find.descendant(
        of: _cross,
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is CustomPaint &&
              widget.painter.runtimeType.toString() == '_CrossPainter',
        ),
      ),
      findsOneWidget,
    );
  });

  testWidgets('the top picture is never cropped; a background one fills', (
    tester,
  ) async {
    Future<BoxFit?> fit(PersonalizationInAppPopupView view) async {
      await tester.pumpWidget(
        _host(PersonalizationInAppPopup(view: view, image: const _NoImage())),
      );
      return tester.widget<Image>(find.byType(Image)).fit;
    }

    expect(await fit(PersonalizationInAppPopupView.image), BoxFit.contain);
    expect(
      await fit(PersonalizationInAppPopupView.imageBackground),
      BoxFit.cover,
    );
  });

  testWidgets('a fullscreen top picture starts below the status bar', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(400, 800),
            padding: EdgeInsets.only(top: 47, bottom: 34),
          ),
          child: SizedBox(
            width: 400,
            height: 800,
            child: PersonalizationInAppPopup(
              presentation: PersonalizationInAppPopupPresentation.fullscreen,
              title: 'Title',
              image: const _NoImage(),
            ),
          ),
        ),
      ),
    );

    expect(tester.getRect(find.byType(Image)).top, 47);
  });
}

/// A picture that never loads: these tests only lay the popup out.
class _NoImage extends ImageProvider<_NoImage> {
  const _NoImage();

  @override
  Future<_NoImage> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture<_NoImage>(this);

  @override
  ImageStreamCompleter loadImage(_NoImage key, ImageDecoderCallback decode) =>
      OneFrameImageStreamCompleter(Completer<ImageInfo>().future);
}
