import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rees46_sdk/src/ui/personalization_ui.dart';

/// Captures what [PersonalizationTheme] resolves to where it is built.
class _Probe extends StatelessWidget {
  const _Probe();

  static PersonalizationTheme? theme;
  static Brightness? brightness;

  @override
  Widget build(BuildContext context) {
    theme = PersonalizationTheme.of(context);
    brightness = PersonalizationTheme.brightnessOf(context);
    return const SizedBox();
  }
}

void main() {
  tearDown(() {
    PersonalizationTheme.mode = ThemeMode.system;
    PersonalizationTheme.configure();
  });

  group('system: follows the app', () {
    testWidgets('MaterialApp in light and in dark', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: _Probe()));
      expect(_Probe.brightness, Brightness.light);
      expect(_Probe.theme!.colors, PersonalizationColors.light);

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(),
          darkTheme: ThemeData(brightness: Brightness.dark),
          themeMode: ThemeMode.dark,
          home: const _Probe(),
        ),
      );
      await tester.pumpAndSettle(); // MaterialApp animates a theme change
      expect(_Probe.brightness, Brightness.dark);
      expect(_Probe.theme!.colors, PersonalizationColors.dark);
    });

    testWidgets('CupertinoApp with a dark theme', (tester) async {
      await tester.pumpWidget(
        const CupertinoApp(
          theme: CupertinoThemeData(brightness: Brightness.dark),
          home: _Probe(),
        ),
      );
      expect(_Probe.brightness, Brightness.dark);
      expect(_Probe.theme!.colors, PersonalizationColors.dark);
    });

    testWidgets('CupertinoApp without a brightness takes the device setting', (
      tester,
    ) async {
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

      await tester.pumpWidget(const CupertinoApp(home: _Probe()));
      expect(_Probe.brightness, Brightness.dark);
    });

    testWidgets('no app theme at all takes the device setting', (tester) async {
      await tester.pumpWidget(
        const MediaQuery(
          data: MediaQueryData(platformBrightness: Brightness.dark),
          child: _Probe(),
        ),
      );
      expect(_Probe.brightness, Brightness.dark);
    });
  });

  testWidgets('a fixed mode wins over the app', (tester) async {
    PersonalizationTheme.mode = ThemeMode.dark;
    await tester.pumpWidget(const MaterialApp(home: _Probe()));
    expect(_Probe.brightness, Brightness.dark);
    expect(_Probe.theme!.colors, PersonalizationColors.dark);

    PersonalizationTheme.mode = ThemeMode.light;
    await tester.pumpWidget(
      const CupertinoApp(
        theme: CupertinoThemeData(brightness: Brightness.dark),
        home: _Probe(),
      ),
    );
    expect(_Probe.brightness, Brightness.light);
    expect(_Probe.theme!.colors, PersonalizationColors.light);
  });

  group('configure', () {
    const purple = Color(0xFF7C3AED);
    const lilac = Color(0xFFA78BFA);
    const font = PersonalizationFontFamily(
      regular: 'Brand',
      emphasized: 'Brand',
    );

    testWidgets('a partial override keeps the rest of the design', (
      tester,
    ) async {
      PersonalizationTheme.configure(
        lightColors: PersonalizationColors.light.copyWith(brandPrimary: purple),
        fontFamily: font,
      );
      await tester.pumpWidget(const MaterialApp(home: _Probe()));

      final theme = _Probe.theme!;
      expect(theme.colors.brandPrimary, purple);
      expect(
        theme.colors.backgroundCard,
        PersonalizationColors.light.backgroundCard,
      );
      expect(theme.fontFamily, font);
      expect(theme.radius.modal, const PersonalizationRadiusScale().modal);
    });

    testWidgets('dark colours of the brand under a forced dark mode', (
      tester,
    ) async {
      PersonalizationTheme.configure(
        lightColors: PersonalizationColors.light.copyWith(brandPrimary: purple),
        darkColors: PersonalizationColors.dark.copyWith(brandPrimary: lilac),
        fontFamily: font,
      );
      PersonalizationTheme.mode = ThemeMode.dark;
      await tester.pumpWidget(const MaterialApp(home: _Probe()));

      expect(_Probe.theme!.colors.brandPrimary, lilac);
      expect(
        _Probe.theme!.colors.backgroundCard,
        PersonalizationColors.dark.backgroundCard,
      );
      expect(_Probe.theme!.fontFamily, font);
    });

    testWidgets('without dark colours the dark scheme takes the brand', (
      tester,
    ) async {
      PersonalizationTheme.configure(
        lightColors: PersonalizationColors.light.copyWith(
          brandPrimary: purple,
          buttonPrimary: purple,
        ),
      );
      PersonalizationTheme.mode = ThemeMode.dark;
      await tester.pumpWidget(const MaterialApp(home: _Probe()));

      final colors = _Probe.theme!.colors;
      expect(colors.brandPrimary, purple);
      expect(colors.buttonPrimary, purple);
      expect(colors.backgroundCard, PersonalizationColors.dark.backgroundCard);
      expect(colors.textPrimary, PersonalizationColors.dark.textPrimary);
    });

    testWidgets('a CupertinoApp gets the brand too', (tester) async {
      PersonalizationTheme.configure(
        lightColors: PersonalizationColors.light.copyWith(brandPrimary: purple),
      );
      await tester.pumpWidget(const CupertinoApp(home: _Probe()));

      expect(_Probe.theme!.colors.brandPrimary, purple);
    });

    testWidgets('configure() with nothing brings the design back', (
      tester,
    ) async {
      PersonalizationTheme.configure(
        lightColors: PersonalizationColors.light.copyWith(brandPrimary: purple),
      );
      PersonalizationTheme.configure();
      await tester.pumpWidget(const MaterialApp(home: _Probe()));

      expect(
        _Probe.theme!.colors.brandPrimary,
        PersonalizationColors.light.brandPrimary,
      );
    });
  });

  testWidgets('a forced brightness on a subtree wins over the mode', (
    tester,
  ) async {
    PersonalizationTheme.mode = ThemeMode.light;
    await tester.pumpWidget(
      const MaterialApp(
        home: PersonalizationBrightness(
          brightness: Brightness.dark,
          child: _Probe(),
        ),
      ),
    );

    expect(_Probe.brightness, Brightness.dark);
    expect(_Probe.theme!.colors, PersonalizationColors.dark);
  });

  testWidgets('a change on the fly redraws what is on screen', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: _Probe()));
    expect(_Probe.brightness, Brightness.light);

    PersonalizationTheme.mode = ThemeMode.dark;
    await tester.pump();

    expect(_Probe.brightness, Brightness.dark);
  });
}
