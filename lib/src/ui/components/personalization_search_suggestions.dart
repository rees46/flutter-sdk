import 'package:flutter/widgets.dart';

import '../personalization_theme.dart';
import 'personalization_suggestion_row.dart';
import 'personalization_tag.dart';

/// Подсказка поиска.
@immutable
class PersonalizationSuggestion {
  const PersonalizationSuggestion({
    required this.id,
    required this.title,
    this.subtitle,
    this.image,
  });

  final String id;
  final String title;

  /// Цена у товара, родительская категория у категории.
  final String? subtitle;
  final ImageProvider? image;
}

/// Панель подсказок поиска: теги-подсказки, категории, товары.
///
/// Источник: Figma Mobile SDK UI Kit, секция Card, фрейм Search (151:3880).
/// Экран там нарисован наброском — шапка вручную, а не из InputField, шрифт
/// SF Pro, — поэтому сюда взято только то, что читается однозначно: ряд тегов
/// с шагом 8, блоки категорий и товаров с шагом 12 внутри и между, разделитель
/// 1px, боковые поля 16. Разделитель в макете — чёрный 4%, ближайший токен
/// Line/Generic Subtle (5%).
///
/// Строки — [PersonalizationSuggestionRow], теги — [PersonalizationTag].
class PersonalizationSearchSuggestions extends StatelessWidget {
  const PersonalizationSearchSuggestions({
    super.key,
    this.tags = const <String>[],
    this.categories = const <PersonalizationSuggestion>[],
    this.products = const <PersonalizationSuggestion>[],
    this.highlight,
    this.showImages = false,
    this.onTagTap,
    this.onCategoryTap,
    this.onProductTap,
    this.iconBuilder,
  });

  final List<String> tags;
  final List<PersonalizationSuggestion> categories;
  final List<PersonalizationSuggestion> products;

  /// Подстрока запроса, выделяемая в подсказках полужирным.
  final String? highlight;

  /// Показывать ли картинки у строк: в макете есть оба варианта.
  final bool showImages;
  final ValueChanged<String>? onTagTap;
  final ValueChanged<PersonalizationSuggestion>? onCategoryTap;
  final ValueChanged<PersonalizationSuggestion>? onProductTap;

  final Widget Function(
    BuildContext context,
    String asset,
    double size,
    Color color,
  )? iconBuilder;

  @override
  Widget build(BuildContext context) {
    final colors = PersonalizationTheme.of(context).colors;
    const double side = 16;
    const double gap = 12;

    Widget block(List<PersonalizationSuggestion> items, PersonalizationSuggestionKind kind,
        ValueChanged<PersonalizationSuggestion>? onTap) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: side),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            for (int i = 0; i < items.length; i++) ...<Widget>[
              if (i > 0) const SizedBox(height: gap),
              PersonalizationSuggestionRow(
                kind: kind,
                title: items[i].title,
                subtitle: items[i].subtitle,
                image: items[i].image,
                showImage: showImages,
                highlight: highlight,
                onTap: onTap == null ? null : () => onTap(items[i]),
                iconBuilder: iconBuilder,
              ),
            ],
          ],
        ),
      );
    }

    final sections = <Widget>[
      if (tags.isNotEmpty)
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: side),
          child: Row(
            children: <Widget>[
              for (int i = 0; i < tags.length; i++) ...<Widget>[
                if (i > 0) const SizedBox(width: 8),
                // Tag сам по себе не кликабелен — нажатие ловит обёртка.
                GestureDetector(
                  onTap: onTagTap == null ? null : () => onTagTap!(tags[i]),
                  child: PersonalizationTag(label: tags[i], view: PersonalizationTagView.primary),
                ),
              ],
            ],
          ),
        ),
      if (categories.isNotEmpty) block(categories, PersonalizationSuggestionKind.category, onCategoryTap),
      // Разделитель нужен только между двумя непустыми блоками.
      if (categories.isNotEmpty && products.isNotEmpty)
        ColoredBox(color: colors.lineGenericSubtle, child: const SizedBox(height: 1, width: double.infinity)),
      if (products.isNotEmpty) block(products, PersonalizationSuggestionKind.product, onProductTap),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        for (int i = 0; i < sections.length; i++) ...<Widget>[
          if (i > 0) const SizedBox(height: gap),
          sections[i],
        ],
      ],
    );
  }
}
