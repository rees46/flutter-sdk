/// Радиусы скругления дизайн-системы.
///
/// Figma Mobile SDK UI Kit (SSwS49L1fG1psWA7xbakV6), страница Typography.
/// Сгенерировано скриптом; правки вносить в источник, не здесь.
///
/// `rounded` — pill: значение заведомо больше любой стороны.
abstract final class PersonalizationRadius {
  /// XS
  static const double xs = 2;

  /// SM
  static const double sm = 4;

  /// MD
  static const double md = 6;

  /// LG
  static const double lg = 8;

  /// XL
  static const double xl = 10;

  /// 2XL
  static const double xl2 = 12;

  /// 3XL
  static const double xl3 = 14;

  /// 4XL
  static const double xl4 = 16;

  /// 5XL
  static const double xl5 = 20;

  /// 6XL
  static const double xl6 = 24;

  /// Rounded
  static const double rounded = 999;

  /// Семантические радиусы: переменные Button LG/MD/SM и Segmented Button MD/SM
  /// из Figma. К ним привязаны Button, Input, Badge, Tag и Button Group —
  /// дизайнер меняет их отдельно от шкалы, поэтому и здесь они отдельно.
  /// segmentedSm в макете не снят, выведен по шагу остальных (+2).
  static const double buttonLg = 12;
  static const double buttonMd = 10;
  static const double buttonSm = 8;
  static const double segmentedMd = 8;
  static const double segmentedSm = 6;
}
