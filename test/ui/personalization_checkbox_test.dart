import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rees46_sdk/src/ui/personalization_ui.dart';

/// Чекбокс в приложении светлой или тёмной темы.
Widget _host(Widget child, {Brightness brightness = Brightness.light}) =>
    MaterialApp(
      theme: ThemeData(),
      darkTheme: ThemeData(brightness: Brightness.dark),
      themeMode: brightness == Brightness.dark
          ? ThemeMode.dark
          : ThemeMode.light,
      home: Center(child: child),
    );

Finder get _box => find.descendant(
  of: find.byType(PersonalizationCheckbox),
  matching: find.byType(CustomPaint),
);

/// Пустой: заливка и рамка.
PaintPattern _unchecked(Color fill, Color border) => paints
  ..rrect(color: fill, style: PaintingStyle.fill)
  ..rrect(color: border, style: PaintingStyle.stroke);

/// Отмеченный: заливка и галка.
PaintPattern _checked(Color fill, Color glyph) => paints
  ..rrect(color: fill, style: PaintingStyle.fill)
  ..path(color: glyph);

void main() {
  for (final (brightness, colors) in <(Brightness, PersonalizationColors)>[
    (Brightness.light, PersonalizationColors.light),
    (Brightness.dark, PersonalizationColors.dark),
  ]) {
    testWidgets('without colors: the kit tokens of the ${brightness.name} '
        'theme', (tester) async {
      await tester.pumpWidget(
        _host(const PersonalizationCheckbox(), brightness: brightness),
      );
      await tester.pumpAndSettle();
      expect(_box, _unchecked(colors.backgroundInput, colors.lineInput));

      await tester.pumpWidget(
        _host(
          const PersonalizationCheckbox(
            state: PersonalizationCheckboxState.checked,
          ),
          brightness: brightness,
        ),
      );
      await tester.pumpAndSettle();
      expect(_box, _checked(colors.buttonPrimary, colors.textLightPrimary));
    });
  }

  testWidgets('with colors: the same in the light and the dark theme', (
    tester,
  ) async {
    const checked = Color(0xff16a34a);
    const checkmark = Color(0xff111827);
    const unchecked = Color(0xfffefce8);
    const border = Color(0xffa16207);
    for (final brightness in Brightness.values) {
      await tester.pumpWidget(
        _host(
          const PersonalizationCheckbox(
            checkedColor: checked,
            checkmarkColor: checkmark,
            uncheckedColor: unchecked,
            borderColor: border,
          ),
          brightness: brightness,
        ),
      );
      await tester.pumpAndSettle();
      expect(_box, _unchecked(unchecked, border));

      await tester.pumpWidget(
        _host(
          const PersonalizationCheckbox(
            state: PersonalizationCheckboxState.checked,
            checkedColor: checked,
            checkmarkColor: checkmark,
            uncheckedColor: unchecked,
            borderColor: border,
          ),
          brightness: brightness,
        ),
      );
      await tester.pumpAndSettle();
      expect(_box, _checked(checked, checkmark));
    }
  });

  testWidgets('disabled with colors keeps the disabled fills of the kit', (
    tester,
  ) async {
    const colors = PersonalizationColors.light;
    await tester.pumpWidget(
      _host(
        const PersonalizationCheckbox(
          disabled: true,
          checkedColor: Color(0xff16a34a),
          uncheckedColor: Color(0xfffefce8),
        ),
      ),
    );
    expect(
      _box,
      paints..rrect(
        color: colors.backgroundInputDisabled,
        style: PaintingStyle.fill,
      ),
    );

    await tester.pumpWidget(
      _host(
        const PersonalizationCheckbox(
          state: PersonalizationCheckboxState.checked,
          disabled: true,
          checkedColor: Color(0xff16a34a),
          uncheckedColor: Color(0xfffefce8),
        ),
      ),
    );
    expect(
      _box,
      paints
        ..rrect(color: colors.buttonPrimaryDisabled, style: PaintingStyle.fill),
    );
  });
}
