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

  testWidgets('the cross takes the dark palette over a photo', (tester) async {
    for (final view in PersonalizationInAppPopupView.values) {
      await tester.pumpWidget(_host(PersonalizationInAppPopup(view: view)));

      expect(
        tester.widget<PersonalizationButton>(_cross).onDark,
        view == PersonalizationInAppPopupView.image ||
            view == PersonalizationInAppPopupView.imageBackground,
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
}
