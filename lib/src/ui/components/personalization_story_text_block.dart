import 'package:flutter/widgets.dart';

import '../personalization_theme.dart';

/// Кегль текстового блока сторис: заготовки макета для текста хоста.
enum PersonalizationStoryTextSize {
  /// Regular 48/48.
  large,

  /// Regular 30/36.
  medium,

  /// Regular 20/24.
  small,
}

/// Текстовый блок на слайде сторис.
///
/// Источник: Figma Mobile SDK UI Kit, страница Stories (1:32), компонент Text Block,
/// секция «Текстовый блок».
///
/// Два вида. Сплошной — когда у [background] есть непрозрачность: скругление 12, поля
/// 12/16 у кегля больше 30 (Large) и 8/16 у остальных (Medium, Small), фон — цвет
/// сервера со своей прозрачностью. Прозрачный — без полей и фона: текст прямо на картинке слайда.
///
/// Кегль, интерлиньяж, цвет, выключка, жирность и курсив приходят с элементом; для текста
/// хоста есть заготовки [size]. Цвет по умолчанию — Text/Light Primary на сплошном фоне
/// и Text/Primary на прозрачном.
class PersonalizationStoryTextBlock extends StatelessWidget {
  const PersonalizationStoryTextBlock({
    super.key,
    required this.text,
    this.size = PersonalizationStoryTextSize.medium,
    this.fontSize,
    this.lineHeight,
    this.color,
    this.background,
    this.textAlign = TextAlign.start,
    this.bold = false,
    this.italic = false,
    this.fontFamily,
    this.fontFamilyFallback,
  });

  final String text;

  /// Заготовка кегля и интерлиньяжа; [fontSize] и [lineHeight] её перекрывают.
  final PersonalizationStoryTextSize size;
  final double? fontSize;

  /// Интерлиньяж в долях кегля, как `TextStyle.height`.
  final double? lineHeight;

  /// Цвет текста; `null` — по виду блока.
  final Color? color;

  /// Фон блока вместе с прозрачностью; `null` или прозрачный — блок без рамки.
  final Color? background;
  final TextAlign textAlign;
  final bool bold;
  final bool italic;

  /// Семейство шрифта элемента (serif, monospace); `null` — шрифт темы.
  final String? fontFamily;
  final List<String>? fontFamilyFallback;

  /// Блок со сплошным фоном: у фона есть непрозрачность.
  bool get solid => background != null && background!.a > 0;

  @override
  Widget build(BuildContext context) {
    final theme = PersonalizationTheme.of(context);
    final colors = theme.colors;
    final (presetSize, presetHeight) = switch (size) {
      PersonalizationStoryTextSize.large => (48.0, 48.0),
      PersonalizationStoryTextSize.medium => (30.0, 36.0),
      PersonalizationStoryTextSize.small => (20.0, 24.0),
    };
    final effectiveSize = fontSize ?? presetSize;
    final weight = bold ? FontWeight.w600 : FontWeight.w400;

    final label = Text(
      text,
      textAlign: textAlign,
      style: TextStyle(
        fontSize: effectiveSize,
        height:
            lineHeight ?? (fontSize == null ? presetHeight / presetSize : null),
        fontWeight: weight,
        fontStyle: italic ? FontStyle.italic : FontStyle.normal,
        letterSpacing: 0,
        fontFamily: fontFamily ?? theme.fontFamily.familyFor(weight),
        fontFamilyFallback: fontFamilyFallback,
        package: fontFamily == null ? theme.fontFamily.package : null,
        color: color ?? (solid ? colors.textLightPrimary : colors.textPrimary),
      ),
    );

    if (!solid) return label;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          vertical: effectiveSize > 30 ? 12 : 8,
          horizontal: 16,
        ),
        child: label,
      ),
    );
  }
}
