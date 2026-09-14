import 'package:flutter/material.dart';

import 'personalization_colors.dart';
import 'personalization_radius.dart';

/// Шрифт дизайн-системы: семейства под обычное и усиленное начертание.
///
/// Inter в SDK не поставляется — по умолчанию используется системный шрифт.
/// Хост может подставить свой, в том числе из другого пакета.
@immutable
class PersonalizationFontFamily {
  const PersonalizationFontFamily({this.regular, this.emphasized, this.package});

  /// Семейство для FontWeight.w400. `null` — системный.
  final String? regular;

  /// Семейство для FontWeight.w600. `null` — системный.
  final String? emphasized;

  /// Пакет, из которого берутся шрифты, если они лежат не в приложении.
  final String? package;

  /// Семейство под вес: только w600 считается усиленным, как в макете.
  String? familyFor(FontWeight weight) =>
      weight == FontWeight.w600 ? emphasized : regular;

  static const PersonalizationFontFamily system = PersonalizationFontFamily();
}

/// Ступень шкалы радиусов. Нужна там, где компонент держит метрики в `const`
/// таблице и не может обратиться к теме на уровне файла.
enum PersonalizationRadiusToken { xs, sm, md, lg, xl, xl2, xl3, xl4, xl5, xl6, rounded }

/// Радиусы темы. Значения по умолчанию — шкала из макета.
@immutable
class PersonalizationRadiusScale {
  const PersonalizationRadiusScale({
    this.xs = PersonalizationRadius.xs,
    this.sm = PersonalizationRadius.sm,
    this.md = PersonalizationRadius.md,
    this.lg = PersonalizationRadius.lg,
    this.xl = PersonalizationRadius.xl,
    this.xl2 = PersonalizationRadius.xl2,
    this.xl3 = PersonalizationRadius.xl3,
    this.xl4 = PersonalizationRadius.xl4,
    this.xl5 = PersonalizationRadius.xl5,
    this.xl6 = PersonalizationRadius.xl6,
    this.rounded = PersonalizationRadius.rounded,
  });

  final double xs, sm, md, lg, xl, xl2, xl3, xl4, xl5, xl6, rounded;

  /// Значение ступени из действующей темы.
  double resolve(PersonalizationRadiusToken token) => switch (token) {
        PersonalizationRadiusToken.xs => xs,
        PersonalizationRadiusToken.sm => sm,
        PersonalizationRadiusToken.md => md,
        PersonalizationRadiusToken.lg => lg,
        PersonalizationRadiusToken.xl => xl,
        PersonalizationRadiusToken.xl2 => xl2,
        PersonalizationRadiusToken.xl3 => xl3,
        PersonalizationRadiusToken.xl4 => xl4,
        PersonalizationRadiusToken.xl5 => xl5,
        PersonalizationRadiusToken.xl6 => xl6,
        PersonalizationRadiusToken.rounded => rounded,
      };

  PersonalizationRadiusScale lerp(PersonalizationRadiusScale other, double t) =>
      PersonalizationRadiusScale(
        xs: lerpDouble(xs, other.xs, t),
        sm: lerpDouble(sm, other.sm, t),
        md: lerpDouble(md, other.md, t),
        lg: lerpDouble(lg, other.lg, t),
        xl: lerpDouble(xl, other.xl, t),
        xl2: lerpDouble(xl2, other.xl2, t),
        xl3: lerpDouble(xl3, other.xl3, t),
        xl4: lerpDouble(xl4, other.xl4, t),
        xl5: lerpDouble(xl5, other.xl5, t),
        xl6: lerpDouble(xl6, other.xl6, t),
        rounded: lerpDouble(rounded, other.rounded, t),
      );

  static double lerpDouble(double a, double b, double t) => a + (b - a) * t;
}

/// Тема дизайн-системы: то, что хост может подменить под свой бренд.
///
/// Подключается расширением к теме приложения:
///
/// ```dart
/// MaterialApp(
///   theme: ThemeData(extensions: <ThemeExtension<dynamic>>[
///     PersonalizationTheme.light.copyWith(
///       colors: PersonalizationColors.light.copyWith(brandPrimary: Color(0xFF7C3AED)),
///       fontFamily: PersonalizationFontFamily(
///         regular: 'Inter', emphasized: 'Inter',
///       ),
///     ),
///   ]),
///   darkTheme: ThemeData.dark().copyWith(extensions: <ThemeExtension<dynamic>>[
///     PersonalizationTheme.dark,
///   ]),
/// )
/// ```
///
/// Расширение можно переопределить и на поддереве через `Theme(data: ...)`:
/// разным магазинам в одном приложении можно дать разный брендинг.
///
/// Темизуются цвета, радиусы и шрифт — поверхность брендирования. Отступы, тени
/// и кегли остаются константами: это шкала макета, менять её не предполагается.
@immutable
class PersonalizationTheme extends ThemeExtension<PersonalizationTheme> {
  const PersonalizationTheme({
    required this.colors,
    this.radius = const PersonalizationRadiusScale(),
    this.fontFamily = PersonalizationFontFamily.system,
  });

  final PersonalizationColors colors;
  final PersonalizationRadiusScale radius;
  final PersonalizationFontFamily fontFamily;

  static const PersonalizationTheme light =
      PersonalizationTheme(colors: PersonalizationColors.light);

  static const PersonalizationTheme dark =
      PersonalizationTheme(colors: PersonalizationColors.dark);

  /// Тема из контекста. Расширение не подключено — берётся светлая по умолчанию,
  /// поэтому компоненты работают и у хоста, которому тема не нужна.
  static PersonalizationTheme of(BuildContext context) =>
      Theme.of(context).extension<PersonalizationTheme>() ?? light;

  @override
  PersonalizationTheme copyWith({
    PersonalizationColors? colors,
    PersonalizationRadiusScale? radius,
    PersonalizationFontFamily? fontFamily,
  }) {
    return PersonalizationTheme(
      colors: colors ?? this.colors,
      radius: radius ?? this.radius,
      fontFamily: fontFamily ?? this.fontFamily,
    );
  }

  @override
  PersonalizationTheme lerp(ThemeExtension<PersonalizationTheme>? other, double t) {
    if (other is! PersonalizationTheme) return this;
    return PersonalizationTheme(
      colors: colors.lerp(other.colors, t),
      radius: radius.lerp(other.radius, t),
      // Шрифт не интерполируется: переключается разом на середине перехода.
      fontFamily: t < 0.5 ? fontFamily : other.fontFamily,
    );
  }
}
