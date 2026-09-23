/// Пути к иконкам дизайн-системы внутри пакета.
///
/// Источник: Figma Mobile SDK UI Kit (SSwS49L1fG1psWA7xbakV6),
/// страница Icons, секция 157:5185.
///
/// Ассеты в формате SVG: Flutter не рисует его без сторонней библиотеки,
/// поэтому пакет отдаёт только пути, а отрисовка остаётся за потребителем
/// (например flutter_svg). Зависимостей это не добавляет.
abstract final class PersonalizationIcons {
  static const String angleDown =
      'packages/rees46_sdk/assets/icons/angle-down.svg';
  static const String angleLargeRight =
      'packages/rees46_sdk/assets/icons/angle-large-right.svg';
  static const String angleUp = 'packages/rees46_sdk/assets/icons/angle-up.svg';
  static const String arrowLeft =
      'packages/rees46_sdk/assets/icons/arrow-left.svg';
  static const String arrowRotateCw =
      'packages/rees46_sdk/assets/icons/arrow-rotate-cw.svg';
  static const String arrowsUpDown =
      'packages/rees46_sdk/assets/icons/arrows-up-down.svg';
  static const String checkRosetteFill =
      'packages/rees46_sdk/assets/icons/check-rosette-fill.svg';
  static const String copy = 'packages/rees46_sdk/assets/icons/copy.svg';
  static const String crossLarge =
      'packages/rees46_sdk/assets/icons/cross-large.svg';
  static const String cross = 'packages/rees46_sdk/assets/icons/cross.svg';
  static const String equalizerHorizontal =
      'packages/rees46_sdk/assets/icons/equalizer-horizontal.svg';
  static const String grid2x2Fill =
      'packages/rees46_sdk/assets/icons/grid-2x2-fill.svg';
  static const String grid2x2 = 'packages/rees46_sdk/assets/icons/grid-2x2.svg';
  static const String listFill =
      'packages/rees46_sdk/assets/icons/list-fill.svg';
  static const String list = 'packages/rees46_sdk/assets/icons/list.svg';
  static const String magnifier =
      'packages/rees46_sdk/assets/icons/magnifier.svg';
  static const String rosette = 'packages/rees46_sdk/assets/icons/rosette.svg';
  static const String spacingMd =
      'packages/rees46_sdk/assets/icons/spacing-md.svg';
  static const String starFill =
      'packages/rees46_sdk/assets/icons/star-fill.svg';

  static const List<String> all = <String>[
    angleDown,
    angleLargeRight,
    angleUp,
    arrowLeft,
    arrowRotateCw,
    arrowsUpDown,
    checkRosetteFill,
    copy,
    crossLarge,
    cross,
    equalizerHorizontal,
    grid2x2Fill,
    grid2x2,
    listFill,
    list,
    magnifier,
    rosette,
    spacingMd,
    starFill,
  ];
}
