import 'package:flutter/painting.dart';

/// Высоты дизайн-системы.
///
/// Figma Mobile SDK UI Kit (SSwS49L1fG1psWA7xbakV6), стили Elevation 1–3.
///
/// Единственная платформа, где обе тени макета ложатся без потерь:
/// [BoxShadow] складывается списком.
///
/// Цвет 0x14 — светлое значение токена Shadow/Heavy. В тёмной схеме он 0x80
/// ([PersonalizationColors.shadowHeavy]): тени, которая должна следовать схеме,
/// цвет подставляют оттуда через [BoxShadow.copyWith].
abstract final class PersonalizationElevation {
  /// None
  static const List<BoxShadow> none = <BoxShadow>[];

  /// Elevation 1
  static const List<BoxShadow> e1 = <BoxShadow>[
    BoxShadow(
      color: Color(0x14000000), // чёрный, 0.08
      offset: Offset(0, 2),
      blurRadius: 4,
    ),
    BoxShadow(
      color: Color(0x14000000), // чёрный, 0.08
      offset: Offset(0, 1),
      blurRadius: 2,
    ),
  ];

  /// Elevation 2
  static const List<BoxShadow> e2 = <BoxShadow>[
    BoxShadow(
      color: Color(0x14000000), // чёрный, 0.08
      offset: Offset(0, 10),
      blurRadius: 10,
    ),
    BoxShadow(
      color: Color(0x14000000), // чёрный, 0.08
      offset: Offset(0, 3),
      blurRadius: 6,
    ),
  ];

  /// Elevation 3
  static const List<BoxShadow> e3 = <BoxShadow>[
    BoxShadow(
      color: Color(0x14000000), // чёрный, 0.08
      offset: Offset(0, 23),
      blurRadius: 23,
    ),
    BoxShadow(
      color: Color(0x14000000), // чёрный, 0.08
      offset: Offset(0, 6),
      blurRadius: 13,
    ),
  ];
}
