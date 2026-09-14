import 'package:flutter/material.dart';

import 'personalization_theme.dart';

/// Цвета дизайн-системы.
///
/// Figma Mobile SDK UI Kit (SSwS49L1fG1psWA7xbakV6), страница Colors,
/// фреймы 57:141 (Light) и 187:362 (Dark). Снято 2026-09-09.
///
/// Набор цветов внутри [PersonalizationTheme]: подключается не сам по себе,
/// а полем темы, и читается через [of] или `PersonalizationTheme.of(context).colors`.
@immutable
class PersonalizationColors {
  final Color brandPrimary;
  final Color semanticWarning;
  final Color backgroundPrimary;
  final Color backgroundGeneric;
  final Color backgroundCard;
  final Color backgroundInput;
  final Color backgroundTransparent;
  final Color backgroundInputDisabled;
  final Color buttonPrimary;
  final Color buttonPrimaryFocus;
  final Color buttonSecondary;
  final Color buttonSecondaryFocus;
  final Color buttonPrimaryDisabled;
  final Color buttonSecondaryDisabled;
  final Color buttonGhost;
  final Color lineBrand;
  final Color lineGeneric;
  final Color lineGenericSubtle;
  final Color lineInput;
  final Color lineInputFocus;
  final Color textPrimary;
  final Color textSecondary;
  final Color textHint;
  final Color textDarkPrimary;
  final Color textDarkSecondary;
  final Color textDarkHint;
  final Color textLightPrimary;
  final Color textLightSecondary;
  final Color textLightHint;
  final Color textInvertedPrimary;
  final Color textInvertedSecondary;
  final Color textInvertedHint;
  final Color textBrand;
  final Color textLink;
  final Color textLinkVisited;

  const PersonalizationColors({
    required this.brandPrimary,
    required this.semanticWarning,
    required this.backgroundPrimary,
    required this.backgroundGeneric,
    required this.backgroundCard,
    required this.backgroundInput,
    required this.backgroundTransparent,
    required this.backgroundInputDisabled,
    required this.buttonPrimary,
    required this.buttonPrimaryFocus,
    required this.buttonSecondary,
    required this.buttonSecondaryFocus,
    required this.buttonPrimaryDisabled,
    required this.buttonSecondaryDisabled,
    required this.buttonGhost,
    required this.lineBrand,
    required this.lineGeneric,
    required this.lineGenericSubtle,
    required this.lineInput,
    required this.lineInputFocus,
    required this.textPrimary,
    required this.textSecondary,
    required this.textHint,
    required this.textDarkPrimary,
    required this.textDarkSecondary,
    required this.textDarkHint,
    required this.textLightPrimary,
    required this.textLightSecondary,
    required this.textLightHint,
    required this.textInvertedPrimary,
    required this.textInvertedSecondary,
    required this.textInvertedHint,
    required this.textBrand,
    required this.textLink,
    required this.textLinkVisited,
  });

  static const PersonalizationColors light = PersonalizationColors(
    brandPrimary: Color(0xFF007DF2),
    semanticWarning: Color(0xFFF37A17),
    backgroundPrimary: Color(0xFF007DF2),
    backgroundGeneric: Color(0xFFFAFAFA),
    backgroundCard: Color(0xFFF2F2F2),
    backgroundInput: Color(0xFFFAFAFA),
    backgroundTransparent: Color(0x00FFFFFF),
    backgroundInputDisabled: Color(0x0D000000),
    buttonPrimary: Color(0xFF007DF2),
    buttonPrimaryFocus: Color(0xFF004BC0),
    buttonSecondary: Color(0x0D000000),
    buttonSecondaryFocus: Color(0x1A000000),
    buttonPrimaryDisabled: Color(0xFF32AFFF),
    buttonSecondaryDisabled: Color(0x0D000000),
    buttonGhost: Color(0x00FFFFFF),
    lineBrand: Color(0xFF007DF2),
    lineGeneric: Color(0x33000000),
    lineGenericSubtle: Color(0x0D000000),
    lineInput: Color(0x33000000),
    lineInputFocus: Color(0xFF007DF2),
    textPrimary: Color(0xFF000000),
    textSecondary: Color(0xB2000000),
    textHint: Color(0x66000000),
    textDarkPrimary: Color(0xFF000000),
    textDarkSecondary: Color(0xB2000000),
    textDarkHint: Color(0x66000000),
    textLightPrimary: Color(0xFFFFFFFF),
    textLightSecondary: Color(0xCCFFFFFF),
    textLightHint: Color(0x80FFFFFF),
    textInvertedPrimary: Color(0xFFFFFFFF),
    textInvertedSecondary: Color(0xCCFFFFFF),
    textInvertedHint: Color(0x80FFFFFF),
    textBrand: Color(0xFF007DF2),
    textLink: Color(0xFF007DF2),
    textLinkVisited: Color(0xFF4D00F2),
  );

  static const PersonalizationColors dark = PersonalizationColors(
    brandPrimary: Color(0xFF007DF2),
    semanticWarning: Color(0xFFF37A17),
    backgroundPrimary: Color(0xFF007DF2),
    backgroundGeneric: Color(0xFF141414),
    backgroundCard: Color(0xFF0D0D0D),
    backgroundInput: Color(0xFF141414),
    backgroundTransparent: Color(0x00FFFFFF),
    backgroundInputDisabled: Color(0x0DFFFFFF),
    buttonPrimary: Color(0xFF007DF2),
    buttonPrimaryFocus: Color(0xFF32AFFF),
    buttonSecondary: Color(0x0DFFFFFF),
    buttonSecondaryFocus: Color(0x1AFFFFFF),
    buttonPrimaryDisabled: Color(0xFF32AFFF),
    buttonSecondaryDisabled: Color(0x0DFFFFFF),
    buttonGhost: Color(0x00FFFFFF),
    lineBrand: Color(0xFF007DF2),
    lineGeneric: Color(0x33FFFFFF),
    lineGenericSubtle: Color(0x0DFFFFFF),
    lineInput: Color(0x33FFFFFF),
    lineInputFocus: Color(0xFF007DF2),
    textPrimary: Color(0xFFFFFFFF),
    textSecondary: Color(0xCCFFFFFF),
    textHint: Color(0x80FFFFFF),
    textDarkPrimary: Color(0xFF000000),
    textDarkSecondary: Color(0xB2000000),
    textDarkHint: Color(0x66000000),
    textLightPrimary: Color(0xFFFFFFFF),
    textLightSecondary: Color(0xCCFFFFFF),
    textLightHint: Color(0x80FFFFFF),
    textInvertedPrimary: Color(0xFF000000),
    textInvertedSecondary: Color(0xB2000000),
    textInvertedHint: Color(0x66000000),
    textBrand: Color(0xFF007DF2),
    textLink: Color(0xFF007DF2),
    textLinkVisited: Color(0xFF4D00F2),
  );

  /// Цвета действующей темы. Расширение не подключено — берётся светлый набор,
  /// чтобы компоненты не падали на голой теме.
  static PersonalizationColors of(BuildContext context) =>
      PersonalizationTheme.of(context).colors;

  PersonalizationColors copyWith({
    Color? brandPrimary,
    Color? semanticWarning,
    Color? backgroundPrimary,
    Color? backgroundGeneric,
    Color? backgroundCard,
    Color? backgroundInput,
    Color? backgroundTransparent,
    Color? backgroundInputDisabled,
    Color? buttonPrimary,
    Color? buttonPrimaryFocus,
    Color? buttonSecondary,
    Color? buttonSecondaryFocus,
    Color? buttonPrimaryDisabled,
    Color? buttonSecondaryDisabled,
    Color? buttonGhost,
    Color? lineBrand,
    Color? lineGeneric,
    Color? lineGenericSubtle,
    Color? lineInput,
    Color? lineInputFocus,
    Color? textPrimary,
    Color? textSecondary,
    Color? textHint,
    Color? textDarkPrimary,
    Color? textDarkSecondary,
    Color? textDarkHint,
    Color? textLightPrimary,
    Color? textLightSecondary,
    Color? textLightHint,
    Color? textInvertedPrimary,
    Color? textInvertedSecondary,
    Color? textInvertedHint,
    Color? textBrand,
    Color? textLink,
    Color? textLinkVisited,
  }) {
    return PersonalizationColors(
      brandPrimary: brandPrimary ?? this.brandPrimary,
      semanticWarning: semanticWarning ?? this.semanticWarning,
      backgroundPrimary: backgroundPrimary ?? this.backgroundPrimary,
      backgroundGeneric: backgroundGeneric ?? this.backgroundGeneric,
      backgroundCard: backgroundCard ?? this.backgroundCard,
      backgroundInput: backgroundInput ?? this.backgroundInput,
      backgroundTransparent: backgroundTransparent ?? this.backgroundTransparent,
      backgroundInputDisabled: backgroundInputDisabled ?? this.backgroundInputDisabled,
      buttonPrimary: buttonPrimary ?? this.buttonPrimary,
      buttonPrimaryFocus: buttonPrimaryFocus ?? this.buttonPrimaryFocus,
      buttonSecondary: buttonSecondary ?? this.buttonSecondary,
      buttonSecondaryFocus: buttonSecondaryFocus ?? this.buttonSecondaryFocus,
      buttonPrimaryDisabled: buttonPrimaryDisabled ?? this.buttonPrimaryDisabled,
      buttonSecondaryDisabled: buttonSecondaryDisabled ?? this.buttonSecondaryDisabled,
      buttonGhost: buttonGhost ?? this.buttonGhost,
      lineBrand: lineBrand ?? this.lineBrand,
      lineGeneric: lineGeneric ?? this.lineGeneric,
      lineGenericSubtle: lineGenericSubtle ?? this.lineGenericSubtle,
      lineInput: lineInput ?? this.lineInput,
      lineInputFocus: lineInputFocus ?? this.lineInputFocus,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textHint: textHint ?? this.textHint,
      textDarkPrimary: textDarkPrimary ?? this.textDarkPrimary,
      textDarkSecondary: textDarkSecondary ?? this.textDarkSecondary,
      textDarkHint: textDarkHint ?? this.textDarkHint,
      textLightPrimary: textLightPrimary ?? this.textLightPrimary,
      textLightSecondary: textLightSecondary ?? this.textLightSecondary,
      textLightHint: textLightHint ?? this.textLightHint,
      textInvertedPrimary: textInvertedPrimary ?? this.textInvertedPrimary,
      textInvertedSecondary: textInvertedSecondary ?? this.textInvertedSecondary,
      textInvertedHint: textInvertedHint ?? this.textInvertedHint,
      textBrand: textBrand ?? this.textBrand,
      textLink: textLink ?? this.textLink,
      textLinkVisited: textLinkVisited ?? this.textLinkVisited,
    );
  }

  PersonalizationColors lerp(PersonalizationColors other, double t) {
    return PersonalizationColors(
      brandPrimary: Color.lerp(brandPrimary, other.brandPrimary, t)!,
      semanticWarning: Color.lerp(semanticWarning, other.semanticWarning, t)!,
      backgroundPrimary: Color.lerp(backgroundPrimary, other.backgroundPrimary, t)!,
      backgroundGeneric: Color.lerp(backgroundGeneric, other.backgroundGeneric, t)!,
      backgroundCard: Color.lerp(backgroundCard, other.backgroundCard, t)!,
      backgroundInput: Color.lerp(backgroundInput, other.backgroundInput, t)!,
      backgroundTransparent: Color.lerp(backgroundTransparent, other.backgroundTransparent, t)!,
      backgroundInputDisabled: Color.lerp(backgroundInputDisabled, other.backgroundInputDisabled, t)!,
      buttonPrimary: Color.lerp(buttonPrimary, other.buttonPrimary, t)!,
      buttonPrimaryFocus: Color.lerp(buttonPrimaryFocus, other.buttonPrimaryFocus, t)!,
      buttonSecondary: Color.lerp(buttonSecondary, other.buttonSecondary, t)!,
      buttonSecondaryFocus: Color.lerp(buttonSecondaryFocus, other.buttonSecondaryFocus, t)!,
      buttonPrimaryDisabled: Color.lerp(buttonPrimaryDisabled, other.buttonPrimaryDisabled, t)!,
      buttonSecondaryDisabled: Color.lerp(buttonSecondaryDisabled, other.buttonSecondaryDisabled, t)!,
      buttonGhost: Color.lerp(buttonGhost, other.buttonGhost, t)!,
      lineBrand: Color.lerp(lineBrand, other.lineBrand, t)!,
      lineGeneric: Color.lerp(lineGeneric, other.lineGeneric, t)!,
      lineGenericSubtle: Color.lerp(lineGenericSubtle, other.lineGenericSubtle, t)!,
      lineInput: Color.lerp(lineInput, other.lineInput, t)!,
      lineInputFocus: Color.lerp(lineInputFocus, other.lineInputFocus, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textHint: Color.lerp(textHint, other.textHint, t)!,
      textDarkPrimary: Color.lerp(textDarkPrimary, other.textDarkPrimary, t)!,
      textDarkSecondary: Color.lerp(textDarkSecondary, other.textDarkSecondary, t)!,
      textDarkHint: Color.lerp(textDarkHint, other.textDarkHint, t)!,
      textLightPrimary: Color.lerp(textLightPrimary, other.textLightPrimary, t)!,
      textLightSecondary: Color.lerp(textLightSecondary, other.textLightSecondary, t)!,
      textLightHint: Color.lerp(textLightHint, other.textLightHint, t)!,
      textInvertedPrimary: Color.lerp(textInvertedPrimary, other.textInvertedPrimary, t)!,
      textInvertedSecondary: Color.lerp(textInvertedSecondary, other.textInvertedSecondary, t)!,
      textInvertedHint: Color.lerp(textInvertedHint, other.textInvertedHint, t)!,
      textBrand: Color.lerp(textBrand, other.textBrand, t)!,
      textLink: Color.lerp(textLink, other.textLink, t)!,
      textLinkVisited: Color.lerp(textLinkVisited, other.textLinkVisited, t)!,
    );
  }
}
