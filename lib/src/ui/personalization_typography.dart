import 'package:flutter/widgets.dart';

/// Типографика дизайн-системы.
///
/// Figma Mobile SDK UI Kit (SSwS49L1fG1psWA7xbakV6), страница Typography.
/// Сгенерировано скриптом; правки вносить в источник, не здесь.
///
/// Inter в SDK не поставляется — `fontFamily` не задан, берётся системный.
/// `height` — отношение интерлиньяжа к кеглю, как того требует [TextStyle].
abstract final class PersonalizationTypography {
  // XS — 12/16
  static const TextStyle xsDefault = TextStyle(
    fontSize: 12,
    height: 1.3333, // 16 / 12
    fontWeight: FontWeight.w400,
    letterSpacing: 0.05,
  );
  static const TextStyle xsEmphasized = TextStyle(
    fontSize: 12,
    height: 1.3333, // 16 / 12
    fontWeight: FontWeight.w600,
    letterSpacing: 0.05,
  );

  // SM — 14/20
  static const TextStyle smDefault = TextStyle(
    fontSize: 14,
    height: 1.4286, // 20 / 14
    fontWeight: FontWeight.w400,
    letterSpacing: 0.05,
  );
  static const TextStyle smEmphasized = TextStyle(
    fontSize: 14,
    height: 1.4286, // 20 / 14
    fontWeight: FontWeight.w600,
    letterSpacing: 0.05,
  );

  // Base — 16/24
  static const TextStyle baseDefault = TextStyle(
    fontSize: 16,
    height: 1.5000, // 24 / 16
    fontWeight: FontWeight.w400,
  );
  static const TextStyle baseEmphasized = TextStyle(
    fontSize: 16,
    height: 1.5000, // 24 / 16
    fontWeight: FontWeight.w600,
  );

  // LG — 18/28
  static const TextStyle lgDefault = TextStyle(
    fontSize: 18,
    height: 1.5556, // 28 / 18
    fontWeight: FontWeight.w400,
  );
  static const TextStyle lgEmphasized = TextStyle(
    fontSize: 18,
    height: 1.5556, // 28 / 18
    fontWeight: FontWeight.w600,
  );

  // XL — 20/32
  static const TextStyle xlDefault = TextStyle(
    fontSize: 20,
    height: 1.6000, // 32 / 20
    fontWeight: FontWeight.w400,
  );
  static const TextStyle xlEmphasized = TextStyle(
    fontSize: 20,
    height: 1.6000, // 32 / 20
    fontWeight: FontWeight.w600,
  );

  // 2XL — 24/36
  static const TextStyle xl2Default = TextStyle(
    fontSize: 24,
    height: 1.5000, // 36 / 24
    fontWeight: FontWeight.w400,
  );
  static const TextStyle xl2Emphasized = TextStyle(
    fontSize: 24,
    height: 1.5000, // 36 / 24
    fontWeight: FontWeight.w600,
  );

  // 3XL — 30/40
  static const TextStyle xl3Default = TextStyle(
    fontSize: 30,
    height: 1.3333, // 40 / 30
    fontWeight: FontWeight.w400,
    letterSpacing: -0.5,
  );
  static const TextStyle xl3Emphasized = TextStyle(
    fontSize: 30,
    height: 1.3333, // 40 / 30
    fontWeight: FontWeight.w600,
    letterSpacing: -0.5,
  );

  // 4XL — 36/52
  static const TextStyle xl4Default = TextStyle(
    fontSize: 36,
    height: 1.3333, // 48 / 36
    fontWeight: FontWeight.w400,
    letterSpacing: -0.5,
  );
  static const TextStyle xl4Emphasized = TextStyle(
    fontSize: 36,
    height: 1.3333, // 48 / 36
    fontWeight: FontWeight.w600,
    letterSpacing: -0.5,
  );

  // 5XL — 48/64
  static const TextStyle xl5Default = TextStyle(
    fontSize: 48,
    height: 1.1667, // 56 / 48
    fontWeight: FontWeight.w400,
    letterSpacing: -0.5,
  );
  static const TextStyle xl5Emphasized = TextStyle(
    fontSize: 48,
    height: 1.1667, // 56 / 48
    fontWeight: FontWeight.w600,
    letterSpacing: -0.5,
  );

  // 6XL — 60/72
  static const TextStyle xl6Default = TextStyle(
    fontSize: 60,
    height: 1.0667, // 64 / 60
    fontWeight: FontWeight.w400,
    letterSpacing: -0.5,
  );
  static const TextStyle xl6Emphasized = TextStyle(
    fontSize: 60,
    height: 1.0667, // 64 / 60
    fontWeight: FontWeight.w600,
    letterSpacing: -0.5,
  );
}
