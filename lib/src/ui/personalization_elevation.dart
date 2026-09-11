import 'package:flutter/painting.dart';

/// Высоты дизайн-системы.
///
/// Figma Mobile SDK UI Kit (SSwS49L1fG1psWA7xbakV6), страница Typography.
/// Сгенерировано скриптом; правки вносить в источник, не здесь.
///
/// Единственная платформа, где обе тени макета ложатся без потерь:
/// [BoxShadow] складывается списком.
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
      offset: Offset(0, 6),
      blurRadius: 8,
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
      offset: Offset(0, 10),
      blurRadius: 10,
    ),
    BoxShadow(
      color: Color(0x14000000), // чёрный, 0.08
      offset: Offset(0, 3),
      blurRadius: 6,
    ),
  ];
  /// Elevation 4
  static const List<BoxShadow> e4 = <BoxShadow>[
    BoxShadow(
      color: Color(0x14000000), // чёрный, 0.08
      offset: Offset(0, 15),
      blurRadius: 15,
    ),
    BoxShadow(
      color: Color(0x14000000), // чёрный, 0.08
      offset: Offset(0, 4),
      blurRadius: 8,
    ),
  ];
  /// Elevation 5
  static const List<BoxShadow> e5 = <BoxShadow>[
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
