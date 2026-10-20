import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'personalization_colors.dart';
import 'personalization_radius.dart';

/// Шрифт дизайн-системы: семейства под обычное и усиленное начертание.
///
/// Inter в SDK не поставляется — по умолчанию используется системный шрифт.
/// Хост может подставить свой, в том числе из другого пакета.
@immutable
class PersonalizationFontFamily {
  const PersonalizationFontFamily({
    this.regular,
    this.emphasized,
    this.package,
  });

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
enum PersonalizationRadiusToken {
  xs,
  sm,
  md,
  lg,
  xl,
  xl2,
  xl3,
  xl4,
  xl5,
  xl6,
  xl7,
  rounded,
  buttonLg,
  buttonMd,
  buttonSm,
  segmentedLg,
  segmentedMd,
  segmentedSm,
  card,
  toast,
  modal,
}

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
    this.xl7 = PersonalizationRadius.xl7,
    this.rounded = PersonalizationRadius.rounded,
    this.buttonLg = PersonalizationRadius.buttonLg,
    this.buttonMd = PersonalizationRadius.buttonMd,
    this.buttonSm = PersonalizationRadius.buttonSm,
    this.segmentedLg = PersonalizationRadius.segmentedLg,
    this.segmentedMd = PersonalizationRadius.segmentedMd,
    this.segmentedSm = PersonalizationRadius.segmentedSm,
    this.card = PersonalizationRadius.card,
    this.toast = PersonalizationRadius.toast,
    this.modal = PersonalizationRadius.modal,
  });

  final double xs, sm, md, lg, xl, xl2, xl3, xl4, xl5, xl6, xl7, rounded;

  /// Семантические радиусы, см. [PersonalizationRadius].
  final double buttonLg,
      buttonMd,
      buttonSm,
      segmentedLg,
      segmentedMd,
      segmentedSm;
  final double card, toast, modal;

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
    PersonalizationRadiusToken.xl7 => xl7,
    PersonalizationRadiusToken.rounded => rounded,
    PersonalizationRadiusToken.buttonLg => buttonLg,
    PersonalizationRadiusToken.buttonMd => buttonMd,
    PersonalizationRadiusToken.buttonSm => buttonSm,
    PersonalizationRadiusToken.segmentedLg => segmentedLg,
    PersonalizationRadiusToken.segmentedMd => segmentedMd,
    PersonalizationRadiusToken.segmentedSm => segmentedSm,
    PersonalizationRadiusToken.card => card,
    PersonalizationRadiusToken.toast => toast,
    PersonalizationRadiusToken.modal => modal,
  };
}

/// Тема дизайн-системы: то, что хост может подменить под свой бренд.
///
/// Задаётся один раз на старте, обычно в `main`, и действует во всём приложении —
/// в `MaterialApp`, `CupertinoApp` и без них:
///
/// ```dart
/// PersonalizationTheme.configure(
///   lightColors: PersonalizationColors.light.copyWith(brandPrimary: Color(0xFF7C3AED)),
///   darkColors: PersonalizationColors.dark.copyWith(brandPrimary: Color(0xFFA78BFA)),
///   fontFamily: PersonalizationFontFamily(regular: 'Inter', emphasized: 'Inter'),
/// );
/// PersonalizationTheme.mode = ThemeMode.system;
/// ```
///
/// Цвета задаются на каждую схему, шрифт и радиусы — одни на обе, как в остальных
/// SDK. Темизуются цвета, радиусы и шрифт — поверхность брендирования. Отступы,
/// тени и кегли остаются константами: это шкала макета, менять её не предполагается.
///
/// Светлую или тёмную выбирает [mode]: по умолчанию как у приложения, или жёстко одну.
@immutable
class PersonalizationTheme {
  const PersonalizationTheme({
    required this.colors,
    this.radius = const PersonalizationRadiusScale(),
    this.fontFamily = PersonalizationFontFamily.system,
  });

  final PersonalizationColors colors;
  final PersonalizationRadiusScale radius;
  final PersonalizationFontFamily fontFamily;

  /// Светлая тема из макета.
  static const PersonalizationTheme light = PersonalizationTheme(
    colors: PersonalizationColors.light,
  );

  /// Тёмная тема из макета.
  static const PersonalizationTheme dark = PersonalizationTheme(
    colors: PersonalizationColors.dark,
  );

  static PersonalizationTheme _light = light;
  static PersonalizationTheme _dark = dark;

  /// Тема бренда для всего UI SDK. Незаданное остаётся из макета, а повторный вызов
  /// задаёт тему целиком заново.
  ///
  /// Цвета обычно берутся частично: `PersonalizationColors.light.copyWith(...)`. Без
  /// [darkColors] тёмная схема берёт из [lightColors] цвета бренда — основной и кнопки
  /// Primary, — а остальное из макета: тёмные поверхности светлой темы не выводятся.
  static void configure({
    PersonalizationColors? lightColors,
    PersonalizationColors? darkColors,
    PersonalizationFontFamily fontFamily = PersonalizationFontFamily.system,
    PersonalizationRadiusScale radius = const PersonalizationRadiusScale(),
  }) {
    _light = PersonalizationTheme(
      colors: lightColors ?? PersonalizationColors.light,
      radius: radius,
      fontFamily: fontFamily,
    );
    _dark = PersonalizationTheme(
      colors:
          darkColors ??
          (lightColors == null
              ? PersonalizationColors.dark
              : _withBrand(PersonalizationColors.dark, lightColors)),
      radius: radius,
      fontFamily: fontFamily,
    );
    _rebuildOnScreen();
  }

  /// Светлая или тёмная тема UI SDK.
  ///
  /// [ThemeMode.system] (по умолчанию) — как у приложения: по его теме Material, иначе
  /// Cupertino, иначе по настройке устройства. [ThemeMode.light] и [ThemeMode.dark] —
  /// всегда эта, что бы ни стояло в приложении. Задаётся один раз, обычно в `main`;
  /// смена на лету перерисовывает то, что на экране.
  static ThemeMode get mode => _mode;

  static set mode(ThemeMode value) {
    if (value == _mode) return;
    _mode = value;
    _rebuildOnScreen();
  }

  static ThemeMode _mode = ThemeMode.system;

  /// Яркость, в которой рисуется UI SDK: заданная [mode], а в [ThemeMode.system] —
  /// яркость приложения.
  static Brightness brightnessOf(BuildContext context) =>
      PersonalizationBrightness._of(context) ??
      switch (_mode) {
        ThemeMode.light => Brightness.light,
        ThemeMode.dark => Brightness.dark,
        // Тема Material ставит под собой CupertinoTheme со своей яркостью, у CupertinoApp
        // она своя, а без обеих CupertinoTheme отдаёт настройку устройства.
        ThemeMode.system =>
          CupertinoTheme.maybeBrightnessOf(context) ?? Brightness.light,
      };

  /// Тема из контекста: заданная [configure], нужной яркости ([brightnessOf]). Без
  /// настройки — значения из макета, поэтому компоненты работают и у хоста, которому
  /// тема не нужна, и в тёмной схеме не остаются светлыми.
  static PersonalizationTheme of(BuildContext context) =>
      brightnessOf(context) == Brightness.dark ? _dark : _light;

  // Компоненты читают режим при сборке, а подписаться им не на что: при смене
  // перестраивается всё дерево приложения — один раз на изменение настройки.
  static void _rebuildOnScreen() {
    final binding = WidgetsFlutterBinding.ensureInitialized();
    void rebuild([Duration? _]) {
      void visit(Element element) {
        element.markNeedsBuild();
        element.visitChildren(visit);
      }

      binding.rootElement?.visitChildren(visit);
    }

    // Посреди сборки кадра помечать нельзя — тогда сразу после него.
    if (binding.schedulerPhase == SchedulerPhase.persistentCallbacks) {
      binding.addPostFrameCallback(rebuild);
    } else {
      rebuild();
    }
  }

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
}

/// [base] с цветами бренда из [brand]: основной цвет, кнопки Primary, линия и текст
/// бренда.
PersonalizationColors _withBrand(
  PersonalizationColors base,
  PersonalizationColors brand,
) => base.copyWith(
  brandPrimary: brand.brandPrimary,
  buttonPrimary: brand.buttonPrimary,
  buttonPrimaryDisabled: brand.buttonPrimaryDisabled,
  lineBrand: brand.lineBrand,
  textBrand: brand.textBrand,
);

/// Принудительная яркость UI кита на поддереве — для мест, где фон задаёт не тема, а
/// содержимое: слайды сторис с фото и видео всегда тёмные. Цвета берутся из темы
/// нужной яркости, заданной [PersonalizationTheme.configure]. Внутреннее: наружу из
/// пакета не экспортируется.
class PersonalizationBrightness extends InheritedWidget {
  const PersonalizationBrightness({
    super.key,
    required this.brightness,
    required super.child,
  });

  final Brightness brightness;

  static Brightness? _of(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<PersonalizationBrightness>()
      ?.brightness;

  @override
  bool updateShouldNotify(PersonalizationBrightness oldWidget) =>
      brightness != oldWidget.brightness;
}
