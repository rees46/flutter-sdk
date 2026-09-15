import 'package:flutter/widgets.dart';

import '../personalization_theme.dart';
import 'personalization_badge.dart';
import 'personalization_button.dart';
import 'personalization_product_image.dart';
import 'personalization_rating.dart';

/// Тип карточки товара.
enum PersonalizationProductCardType { carousel, grid, list }

/// Оценка товара для карточки.
class PersonalizationProductRating {
  const PersonalizationProductRating({required this.value, required this.reviews});

  /// Уже отформатированная оценка: в макете «4,7» с запятой.
  final String value;
  final int reviews;
}

/// Карточка товара.
///
/// Источник: Figma Mobile SDK UI Kit, секция Card, фрейм Product (126:2263):
/// carousel — колонка 220, grid — колонка на всю ширину ячейки, list — строка с картинкой
/// шириной 120 и ценой с кнопкой внизу справа. Пропорция картинки — [imageAspect]: на
/// странице ProductCard (88:69) карточка нарисована с 4:3, 1:1 и 3:4, и её высота идёт
/// за картинкой.
/// У трёх типов разная типографика названия, цены и старой цены, поэтому она задана
/// в таблице. Старая цена карусели — 16/24 по страницам ProductCard и Product Carousel;
/// мастер-компонент Product там же даёт 14/20 — расхождение в макете, взяты страницы.
///
/// Собрана из готовых блоков: [PersonalizationProductImage], [PersonalizationRating],
/// [PersonalizationBadge] (скидка, вид danger), [PersonalizationButton].
class PersonalizationProductCard extends StatelessWidget {
  const PersonalizationProductCard({
    super.key,
    this.type = PersonalizationProductCardType.carousel,
    this.image,
    this.imageAspect = PersonalizationProductImageAspect.square,
    this.brand,
    required this.name,
    this.rating,
    required this.price,
    this.oldPrice,
    this.discount,
    this.actionText,
    this.onAction,
    this.iconBuilder,
  });

  final PersonalizationProductCardType type;
  final ImageProvider? image;

  /// Пропорция картинки; высота карточки идёт за ней.
  final PersonalizationProductImageAspect imageAspect;
  final String? brand;
  final String name;
  final PersonalizationProductRating? rating;
  final String price;

  /// Старая цена, зачёркнутая. `null` — не показывать.
  final String? oldPrice;

  /// Скидка, например «-15%». `null` — без бейджа.
  final String? discount;

  /// Подпись кнопки. `null` — без кнопки.
  final String? actionText;
  final VoidCallback? onAction;

  final Widget Function(
    BuildContext context,
    String asset,
    double size,
    Color color,
  )? iconBuilder;

  @override
  Widget build(BuildContext context) {
    final theme = PersonalizationTheme.of(context);
    final colors = theme.colors;
    final metrics = _metrics[type]!;

    TextStyle style(double fontSize, double lineHeight, double letterSpacing, FontWeight weight, Color color) =>
        TextStyle(
          fontFamily: theme.fontFamily.familyFor(weight),
          package: theme.fontFamily.package,
          fontSize: fontSize,
          height: lineHeight / fontSize,
          letterSpacing: letterSpacing,
          fontWeight: weight,
          color: color,
        );

    Widget nameBlock(double gap) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (brand != null && brand!.isNotEmpty) ...<Widget>[
              Text(brand!, style: style(12, 16, 0.05, FontWeight.w400, colors.textSecondary)),
              SizedBox(height: gap),
            ],
            Text(
              name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: style(metrics.nameSize, metrics.nameLineHeight, metrics.nameLetterSpacing,
                  FontWeight.w400, colors.textPrimary),
            ),
          ],
        );

    final Widget? ratingRow = rating == null
        ? null
        : PersonalizationRating(value: rating!.value, reviews: rating!.reviews, iconBuilder: iconBuilder);
    final Widget priceText = Text(
      price,
      style: style(metrics.priceSize, metrics.priceLineHeight, 0, FontWeight.w600, colors.textPrimary),
    );
    final Widget? oldPriceText = oldPrice == null
        ? null
        : Text(
            oldPrice!,
            style: style(metrics.oldPriceSize, metrics.oldPriceLineHeight, metrics.oldPriceLetterSpacing,
                    FontWeight.w400, colors.textHint)
                .copyWith(decoration: TextDecoration.lineThrough),
          );
    final Widget? discountBadge = discount == null
        ? null
        : PersonalizationBadge(
            label: discount!,
            size: PersonalizationBadgeSize.sm,
            view: PersonalizationBadgeView.danger,
          );
    final Widget? action = actionText == null
        ? null
        : PersonalizationButton(
            label: actionText,
            size: PersonalizationButtonSize.md,
            view: PersonalizationButtonView.primary,
            onPressed: onAction,
          );

    // List: картинка шириной 120 слева, справа колонка — название с рейтингом сверху,
    // цена с кнопкой снизу. Высота строки — большее из картинки и текста, поэтому
    // IntrinsicHeight: колонка тянется до картинки, а низкая картинка её не сжимает.
    if (type == PersonalizationProductCardType.list) {
      return IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            SizedBox(width: 120, child: PersonalizationProductImage(image: image, aspect: imageAspect)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      nameBlock(2),
                      if (ratingRow != null) ...<Widget>[const SizedBox(height: 4), ratingRow],
                    ],
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: <Widget>[
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              priceText,
                              if (discountBadge != null) ...<Widget>[const SizedBox(width: 8), discountBadge],
                            ],
                          ),
                          ?oldPriceText,
                        ],
                      ),
                      ?action,
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // Carousel и Grid: картинка, название, рейтинг, цена, кнопка — колонкой с шагом 8.
    // У колонок скидка лежит на картинке: отступ 8 у carousel и 4 у grid.
    final column = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Stack(
          children: <Widget>[
            PersonalizationProductImage(image: image, aspect: imageAspect),
            if (discountBadge != null)
              Positioned(top: metrics.badgeInset, right: metrics.badgeInset, child: discountBadge),
          ],
        ),
        const SizedBox(height: 8),
        nameBlock(2),
        if (ratingRow != null) ...<Widget>[const SizedBox(height: 8), ratingRow],
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: <Widget>[
            priceText,
            if (oldPriceText != null) ...<Widget>[const SizedBox(width: 8), oldPriceText],
          ],
        ),
        if (action != null) ...<Widget>[const SizedBox(height: 8), action],
      ],
    );
    return type == PersonalizationProductCardType.carousel
        ? SizedBox(width: 220, child: column)
        : column;
  }
}

class _CardMetrics {
  const _CardMetrics({
    required this.nameSize,
    required this.nameLineHeight,
    required this.nameLetterSpacing,
    required this.priceSize,
    required this.priceLineHeight,
    required this.oldPriceSize,
    required this.oldPriceLineHeight,
    required this.oldPriceLetterSpacing,
    required this.badgeInset,
  });

  final double nameSize, nameLineHeight, nameLetterSpacing, priceSize, priceLineHeight;
  final double oldPriceSize, oldPriceLineHeight, oldPriceLetterSpacing, badgeInset;
}

const Map<PersonalizationProductCardType, _CardMetrics> _metrics =
    <PersonalizationProductCardType, _CardMetrics>{
  PersonalizationProductCardType.carousel: _CardMetrics(
      nameSize: 16, nameLineHeight: 24, nameLetterSpacing: 0, priceSize: 20, priceLineHeight: 32,
      oldPriceSize: 16, oldPriceLineHeight: 24, oldPriceLetterSpacing: 0, badgeInset: 8),
  PersonalizationProductCardType.grid: _CardMetrics(
      nameSize: 16, nameLineHeight: 24, nameLetterSpacing: 0, priceSize: 18, priceLineHeight: 28,
      oldPriceSize: 14, oldPriceLineHeight: 20, oldPriceLetterSpacing: 0.05, badgeInset: 4),
  PersonalizationProductCardType.list: _CardMetrics(
      nameSize: 14, nameLineHeight: 20, nameLetterSpacing: 0.05, priceSize: 16, priceLineHeight: 24,
      oldPriceSize: 14, oldPriceLineHeight: 20, oldPriceLetterSpacing: 0.05, badgeInset: 0),
};
