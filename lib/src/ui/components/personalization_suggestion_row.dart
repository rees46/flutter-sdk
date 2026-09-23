import 'package:flutter/widgets.dart';

import '../personalization_icons.dart';
import '../personalization_theme.dart';

/// Вид строки подсказки.
enum PersonalizationSuggestionKind { product, category }

/// Строка подсказки поиска: товар или категория.
///
/// Источник: Figma Mobile SDK UI Kit, секция Card — Product (151:4003) и Category
/// (151:4011), у обоих варианты Image и Text. Строка с картинкой 40x40 и двумя
/// строками текста (у товара цена, у категории родительская категория), либо одна
/// строка текста. У категории справа шеврон. Шаг между картинкой и текстом 10 —
/// значения нет в шкале отступов, взято из макета как есть.
///
/// [highlight] выделяет совпадение с запросом полужирным, как в макете подсказок.
class PersonalizationSuggestionRow extends StatelessWidget {
  const PersonalizationSuggestionRow({
    super.key,
    this.kind = PersonalizationSuggestionKind.product,
    required this.title,
    this.subtitle,
    this.image,
    this.showImage = false,
    this.highlight,
    this.onTap,
    this.iconBuilder,
  });

  final PersonalizationSuggestionKind kind;
  final String title;

  /// Цена у товара, родительская категория у категории. Видна только с картинкой.
  final String? subtitle;
  final ImageProvider? image;
  final bool showImage;

  /// Подстрока запроса, которую надо выделить в [title].
  final String? highlight;
  final VoidCallback? onTap;

  final Widget Function(
    BuildContext context,
    String asset,
    double size,
    Color color,
  )?
  iconBuilder;

  @override
  Widget build(BuildContext context) {
    final theme = PersonalizationTheme.of(context);
    final colors = theme.colors;
    final category = kind == PersonalizationSuggestionKind.category;

    TextStyle style(FontWeight weight, Color color) => TextStyle(
      fontFamily: theme.fontFamily.familyFor(weight),
      package: theme.fontFamily.package,
      fontSize: 14,
      height: 20 / 14,
      letterSpacing: 0.05,
      fontWeight: weight,
      color: color,
    );
    final regular = style(FontWeight.w400, colors.textPrimary);
    final bold = style(FontWeight.w600, colors.textPrimary);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Row(
        crossAxisAlignment: category
            ? CrossAxisAlignment.center
            : CrossAxisAlignment.start,
        children: <Widget>[
          if (showImage) ...<Widget>[
            SizedBox(
              width: 40,
              height: 40,
              child: ColoredBox(
                color: colors.neutral50,
                child: image == null
                    ? null
                    : Image(image: image!, fit: BoxFit.cover),
              ),
            ),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text.rich(
                  _highlighted(regular, bold),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (showImage && subtitle != null && subtitle!.isNotEmpty)
                  // У товара это цена полужирным, у категории — родитель серым.
                  Text(
                    subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: category
                        ? style(FontWeight.w400, colors.textHint)
                        : bold,
                  ),
              ],
            ),
          ),
          if (category) ...<Widget>[
            const SizedBox(width: 10),
            SizedBox(
              width: 24,
              height: 24,
              child: iconBuilder?.call(
                context,
                PersonalizationIcons.angleLargeRight,
                24,
                colors.textHint,
              ),
            ),
          ],
        ],
      ),
    );
  }

  TextSpan _highlighted(TextStyle regular, TextStyle bold) {
    final query = highlight ?? '';
    final index = query.isEmpty
        ? -1
        : title.toLowerCase().indexOf(query.toLowerCase());
    if (index < 0) return TextSpan(text: title, style: regular);
    return TextSpan(
      style: regular,
      children: <TextSpan>[
        TextSpan(text: title.substring(0, index)),
        TextSpan(
          text: title.substring(index, index + query.length),
          style: bold,
        ),
        TextSpan(text: title.substring(index + query.length)),
      ],
    );
  }
}
