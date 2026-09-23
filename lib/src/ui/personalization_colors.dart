import 'package:flutter/material.dart';

import 'personalization_theme.dart';

/// Цвета дизайн-системы.
///
/// Figma Mobile SDK UI Kit (SSwS49L1fG1psWA7xbakV6), коллекция переменных Color,
/// режимы Light и Dark. Сверено 2026-09-23.
///
/// Набор цветов внутри [PersonalizationTheme]: подключается не сам по себе,
/// а полем темы, и читается через [of] или `PersonalizationTheme.of(context).colors`.
@immutable
class PersonalizationColors {
  final Color brandPrimary;

  /// Neutral 50: полупрозрачная ступень, одинаково заметна на любом фоне — заглушки картинок.
  final Color neutral50;

  final Color semanticWarning;
  final Color semanticDanger;
  final Color backgroundGeneric;
  final Color backgroundCard;

  /// Поверхности поверх карточки. В светлой все три белые, различаются только
  /// в тёмной: Card #1A1A1A, Float #262626, Modal #333333.
  final Color backgroundFloat;
  final Color backgroundModal;
  final Color backgroundInput;
  final Color backgroundTransparent;
  final Color backgroundInputDisabled;
  final Color buttonPrimary;
  final Color buttonPrimaryFocus;
  final Color buttonSecondary;

  /// Secondary поверх тёмного (картинки-фона): белая 5%, как в тёмном режиме файла.
  final Color buttonSecondaryOnDark;
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

  /// Shadow/Heavy: цвет тени вместе с её прозрачностью — 8% в светлой, 50% в тёмной.
  final Color shadowHeavy;

  const PersonalizationColors({
    required this.brandPrimary,
    required this.neutral50,
    required this.semanticWarning,
    required this.semanticDanger,
    required this.backgroundGeneric,
    required this.backgroundCard,
    required this.backgroundFloat,
    required this.backgroundModal,
    required this.backgroundInput,
    required this.backgroundTransparent,
    required this.backgroundInputDisabled,
    required this.buttonPrimary,
    required this.buttonPrimaryFocus,
    required this.buttonSecondary,
    required this.buttonSecondaryOnDark,
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
    required this.shadowHeavy,
  });

  static const PersonalizationColors light = PersonalizationColors(
    brandPrimary: Color(0xFF007DF2),
    neutral50: Color(0x0D000000),
    semanticWarning: Color(0xFFF37A17),
    semanticDanger: Color(0xFFE51919),
    backgroundGeneric: Color(0xFFF2F2F2),
    backgroundCard: Color(0xFFFFFFFF),
    backgroundFloat: Color(0xFFFFFFFF),
    backgroundModal: Color(0xFFFFFFFF),
    backgroundInput: Color(0xFFF2F2F2),
    backgroundTransparent: Color(0x00FFFFFF),
    backgroundInputDisabled: Color(0x0D000000),
    buttonPrimary: Color(0xFF007DF2),
    buttonPrimaryFocus: Color(0xFF004BC0),
    buttonSecondary: Color(0x0D000000),
    buttonSecondaryOnDark: Color(0x0DFFFFFF),
    buttonSecondaryFocus: Color(0x1A000000),
    // Brand/Primary с прозрачностью 65%.
    buttonPrimaryDisabled: Color(0xA6007DF2),
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
    shadowHeavy: Color(0x14000000),
  );

  static const PersonalizationColors dark = PersonalizationColors(
    brandPrimary: Color(0xFF007DF2),
    neutral50: Color(0x0DFFFFFF),
    semanticWarning: Color(0xFFF37A17),
    semanticDanger: Color(0xFFE51919),
    backgroundGeneric: Color(0xFF0D0D0D),
    backgroundCard: Color(0xFF1A1A1A),
    backgroundFloat: Color(0xFF262626),
    backgroundModal: Color(0xFF333333),
    backgroundInput: Color(0xFF0D0D0D),
    backgroundTransparent: Color(0x00FFFFFF),
    backgroundInputDisabled: Color(0x0DFFFFFF),
    buttonPrimary: Color(0xFF007DF2),
    buttonPrimaryFocus: Color(0xFF32AFFF),
    buttonSecondary: Color(0x0DFFFFFF),
    buttonSecondaryOnDark: Color(0x0DFFFFFF),
    buttonSecondaryFocus: Color(0x1AFFFFFF),
    // Brand/Primary с прозрачностью 65%.
    buttonPrimaryDisabled: Color(0xA6007DF2),
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
    shadowHeavy: Color(0x80000000),
  );

  /// Цвета действующей темы. Расширение не подключено — берётся светлый набор,
  /// чтобы компоненты не падали на голой теме.
  static PersonalizationColors of(BuildContext context) =>
      PersonalizationTheme.of(context).colors;

  PersonalizationColors copyWith({
    Color? brandPrimary,
    Color? neutral50,
    Color? semanticWarning,
    Color? semanticDanger,
    Color? backgroundGeneric,
    Color? backgroundCard,
    Color? backgroundFloat,
    Color? backgroundModal,
    Color? backgroundInput,
    Color? backgroundTransparent,
    Color? backgroundInputDisabled,
    Color? buttonPrimary,
    Color? buttonPrimaryFocus,
    Color? buttonSecondary,
    Color? buttonSecondaryOnDark,
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
    Color? shadowHeavy,
  }) {
    return PersonalizationColors(
      brandPrimary: brandPrimary ?? this.brandPrimary,
      neutral50: neutral50 ?? this.neutral50,
      semanticWarning: semanticWarning ?? this.semanticWarning,
      semanticDanger: semanticDanger ?? this.semanticDanger,
      backgroundGeneric: backgroundGeneric ?? this.backgroundGeneric,
      backgroundCard: backgroundCard ?? this.backgroundCard,
      backgroundFloat: backgroundFloat ?? this.backgroundFloat,
      backgroundModal: backgroundModal ?? this.backgroundModal,
      backgroundInput: backgroundInput ?? this.backgroundInput,
      backgroundTransparent:
          backgroundTransparent ?? this.backgroundTransparent,
      backgroundInputDisabled:
          backgroundInputDisabled ?? this.backgroundInputDisabled,
      buttonPrimary: buttonPrimary ?? this.buttonPrimary,
      buttonPrimaryFocus: buttonPrimaryFocus ?? this.buttonPrimaryFocus,
      buttonSecondary: buttonSecondary ?? this.buttonSecondary,
      buttonSecondaryOnDark:
          buttonSecondaryOnDark ?? this.buttonSecondaryOnDark,
      buttonSecondaryFocus: buttonSecondaryFocus ?? this.buttonSecondaryFocus,
      buttonPrimaryDisabled:
          buttonPrimaryDisabled ?? this.buttonPrimaryDisabled,
      buttonSecondaryDisabled:
          buttonSecondaryDisabled ?? this.buttonSecondaryDisabled,
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
      textInvertedSecondary:
          textInvertedSecondary ?? this.textInvertedSecondary,
      textInvertedHint: textInvertedHint ?? this.textInvertedHint,
      textBrand: textBrand ?? this.textBrand,
      textLink: textLink ?? this.textLink,
      textLinkVisited: textLinkVisited ?? this.textLinkVisited,
      shadowHeavy: shadowHeavy ?? this.shadowHeavy,
    );
  }

  PersonalizationColors lerp(PersonalizationColors other, double t) {
    return PersonalizationColors(
      brandPrimary: Color.lerp(brandPrimary, other.brandPrimary, t)!,
      neutral50: Color.lerp(neutral50, other.neutral50, t)!,
      semanticWarning: Color.lerp(semanticWarning, other.semanticWarning, t)!,
      semanticDanger: Color.lerp(semanticDanger, other.semanticDanger, t)!,
      backgroundGeneric: Color.lerp(
        backgroundGeneric,
        other.backgroundGeneric,
        t,
      )!,
      backgroundCard: Color.lerp(backgroundCard, other.backgroundCard, t)!,
      backgroundFloat: Color.lerp(backgroundFloat, other.backgroundFloat, t)!,
      backgroundModal: Color.lerp(backgroundModal, other.backgroundModal, t)!,
      backgroundInput: Color.lerp(backgroundInput, other.backgroundInput, t)!,
      backgroundTransparent: Color.lerp(
        backgroundTransparent,
        other.backgroundTransparent,
        t,
      )!,
      backgroundInputDisabled: Color.lerp(
        backgroundInputDisabled,
        other.backgroundInputDisabled,
        t,
      )!,
      buttonPrimary: Color.lerp(buttonPrimary, other.buttonPrimary, t)!,
      buttonPrimaryFocus: Color.lerp(
        buttonPrimaryFocus,
        other.buttonPrimaryFocus,
        t,
      )!,
      buttonSecondary: Color.lerp(buttonSecondary, other.buttonSecondary, t)!,
      buttonSecondaryOnDark: Color.lerp(
        buttonSecondaryOnDark,
        other.buttonSecondaryOnDark,
        t,
      )!,
      buttonSecondaryFocus: Color.lerp(
        buttonSecondaryFocus,
        other.buttonSecondaryFocus,
        t,
      )!,
      buttonPrimaryDisabled: Color.lerp(
        buttonPrimaryDisabled,
        other.buttonPrimaryDisabled,
        t,
      )!,
      buttonSecondaryDisabled: Color.lerp(
        buttonSecondaryDisabled,
        other.buttonSecondaryDisabled,
        t,
      )!,
      buttonGhost: Color.lerp(buttonGhost, other.buttonGhost, t)!,
      lineBrand: Color.lerp(lineBrand, other.lineBrand, t)!,
      lineGeneric: Color.lerp(lineGeneric, other.lineGeneric, t)!,
      lineGenericSubtle: Color.lerp(
        lineGenericSubtle,
        other.lineGenericSubtle,
        t,
      )!,
      lineInput: Color.lerp(lineInput, other.lineInput, t)!,
      lineInputFocus: Color.lerp(lineInputFocus, other.lineInputFocus, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textHint: Color.lerp(textHint, other.textHint, t)!,
      textDarkPrimary: Color.lerp(textDarkPrimary, other.textDarkPrimary, t)!,
      textDarkSecondary: Color.lerp(
        textDarkSecondary,
        other.textDarkSecondary,
        t,
      )!,
      textDarkHint: Color.lerp(textDarkHint, other.textDarkHint, t)!,
      textLightPrimary: Color.lerp(
        textLightPrimary,
        other.textLightPrimary,
        t,
      )!,
      textLightSecondary: Color.lerp(
        textLightSecondary,
        other.textLightSecondary,
        t,
      )!,
      textLightHint: Color.lerp(textLightHint, other.textLightHint, t)!,
      textInvertedPrimary: Color.lerp(
        textInvertedPrimary,
        other.textInvertedPrimary,
        t,
      )!,
      textInvertedSecondary: Color.lerp(
        textInvertedSecondary,
        other.textInvertedSecondary,
        t,
      )!,
      textInvertedHint: Color.lerp(
        textInvertedHint,
        other.textInvertedHint,
        t,
      )!,
      textBrand: Color.lerp(textBrand, other.textBrand, t)!,
      textLink: Color.lerp(textLink, other.textLink, t)!,
      textLinkVisited: Color.lerp(textLinkVisited, other.textLinkVisited, t)!,
      shadowHeavy: Color.lerp(shadowHeavy, other.shadowHeavy, t)!,
    );
  }
}
