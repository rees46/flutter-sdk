import 'package:flutter/widgets.dart';

import '../personalization_theme.dart';
import 'personalization_input_field.dart';
import 'personalization_link.dart';
import 'personalization_list_label.dart';
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

/// Экран мгновенного поиска: поле ввода с «Cancel», недавние запросы, подсказки,
/// категории и товары.
///
/// Источник: Figma Mobile SDK UI Kit, страница InstantSearchField — Instant Search/Text
/// (151:3976), /Input (310:10207), /With Images (310:9829), /Clear Recent Searches
/// (310:10016). Поле — [PersonalizationInputField] типа search размера md, ссылки —
/// [PersonalizationLink], подписи блоков — [PersonalizationListLabel], теги —
/// [PersonalizationTag] с переносом по строкам, строки — [PersonalizationSuggestionRow].
///
/// Недавние запросы — теги с крестиком, в конце синий тег «ещё»; подсказки при вводе —
/// такие же теги без крестика. Перед категориями и перед товарами разделитель 1px.
/// Совпадение с запросом в строках выделяется полужирным само.
///
/// Внимание: шаг колонки в макете 13 — такого значения в шкале нет, взят LG (12).
/// Разделитель в макете чёрный 4%, ближайший токен Line/Generic Subtle (5%).
class PersonalizationInstantSearch extends StatefulWidget {
  const PersonalizationInstantSearch({
    super.key,
    this.controller,
    this.placeholder,
    this.cancelText,
    this.onCancel,
    this.onQueryChanged,
    this.onSubmit,
    this.recentLabel,
    this.clearText,
    this.onClearRecent,
    this.recentSearches = const <String>[],
    this.moreText,
    this.onMoreRecent,
    this.onRecentTap,
    this.onRecentRemove,
    this.suggestions = const <String>[],
    this.onSuggestionTap,
    this.categoriesLabel,
    this.categories = const <PersonalizationSuggestion>[],
    this.onCategoryTap,
    this.productsLabel,
    this.products = const <PersonalizationSuggestion>[],
    this.onProductTap,
    this.showImages = false,
    this.iconBuilder,
  });

  /// Контроллер поля; не задан — виджет заводит свой.
  final TextEditingController? controller;
  final String? placeholder;

  /// Подпись ссылки справа от поля. `null` — без ссылки.
  final String? cancelText;
  final VoidCallback? onCancel;
  final ValueChanged<String>? onQueryChanged;
  final ValueChanged<String>? onSubmit;

  /// Подпись над недавними запросами. `null` — блок без подписи и без «Clear».
  final String? recentLabel;
  final String? clearText;
  final VoidCallback? onClearRecent;
  final List<String> recentSearches;

  /// Подпись синего тега в конце недавних запросов. `null` — без него.
  final String? moreText;
  final VoidCallback? onMoreRecent;
  final ValueChanged<String>? onRecentTap;
  final ValueChanged<String>? onRecentRemove;

  final List<String> suggestions;
  final ValueChanged<String>? onSuggestionTap;

  final String? categoriesLabel;
  final List<PersonalizationSuggestion> categories;
  final ValueChanged<PersonalizationSuggestion>? onCategoryTap;
  final String? productsLabel;
  final List<PersonalizationSuggestion> products;
  final ValueChanged<PersonalizationSuggestion>? onProductTap;

  /// Показывать ли картинки у строк: в макете есть оба варианта. Строка без картинки идёт без плейсхолдера.
  final bool showImages;

  final Widget Function(
    BuildContext context,
    String asset,
    double size,
    Color color,
  )?
  iconBuilder;

  @override
  State<PersonalizationInstantSearch> createState() =>
      _PersonalizationInstantSearchState();
}

class _PersonalizationInstantSearchState
    extends State<PersonalizationInstantSearch> {
  TextEditingController? _ownController;

  TextEditingController get _controller =>
      widget.controller ?? (_ownController ??= TextEditingController());

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onText);
  }

  @override
  void didUpdateWidget(PersonalizationInstantSearch oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      (oldWidget.controller ?? _ownController)?.removeListener(_onText);
      _controller.addListener(_onText);
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onText);
    _ownController?.dispose();
    super.dispose();
  }

  // Совпадение выделяется по тексту поля, поэтому строки перестраиваются на каждый символ.
  void _onText() => setState(() {});

  Widget _removeIcon(BuildContext context, String asset) {
    final color = PersonalizationTheme.of(context).colors.textPrimary;
    return widget.iconBuilder?.call(context, asset, 16, color) ??
        const SizedBox(width: 16, height: 16);
  }

  @override
  Widget build(BuildContext context) {
    final colors = PersonalizationTheme.of(context).colors;
    const double gap = 12;
    final highlight = _controller.text;

    final Widget separator = ColoredBox(
      color: colors.lineGenericSubtle,
      child: const SizedBox(height: 1, width: double.infinity),
    );

    Widget rows(
      List<PersonalizationSuggestion> items,
      PersonalizationSuggestionKind kind,
      ValueChanged<PersonalizationSuggestion>? onTap,
    ) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          for (int i = 0; i < items.length; i++) ...<Widget>[
            if (i > 0) const SizedBox(height: gap),
            PersonalizationSuggestionRow(
              kind: kind,
              title: items[i].title,
              subtitle: items[i].subtitle,
              image: items[i].image,
              // Строка без картинки идёт без плейсхолдера.
              showImage: widget.showImages && items[i].image != null,
              highlight: highlight,
              onTap: onTap == null ? null : () => onTap(items[i]),
              iconBuilder: widget.iconBuilder,
            ),
          ],
        ],
      );
    }

    final bool hasRecent = widget.recentSearches.isNotEmpty;
    final sections = <Widget>[
      Row(
        children: <Widget>[
          Expanded(
            child: PersonalizationInputField(
              controller: _controller,
              placeholder: widget.placeholder,
              size: PersonalizationInputFieldSize.md,
              type: PersonalizationInputFieldType.search,
              onChanged: widget.onQueryChanged,
              onSubmitted: widget.onSubmit,
              iconBuilder: widget.iconBuilder,
            ),
          ),
          if (widget.cancelText != null &&
              widget.cancelText!.isNotEmpty) ...<Widget>[
            const SizedBox(width: 16),
            PersonalizationLink(
              label: widget.cancelText!,
              onTap: widget.onCancel,
            ),
          ],
        ],
      ),
      if (hasRecent &&
          widget.recentLabel != null &&
          widget.recentLabel!.isNotEmpty)
        Row(
          children: <Widget>[
            Expanded(
              child: PersonalizationListLabel(label: widget.recentLabel!),
            ),
            if (widget.clearText != null &&
                widget.clearText!.isNotEmpty) ...<Widget>[
              const SizedBox(width: gap),
              PersonalizationLink(
                label: widget.clearText!,
                onTap: widget.onClearRecent,
              ),
            ],
          ],
        ),
      if (hasRecent)
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            for (final item in widget.recentSearches)
              // Tag сам по себе не кликабелен — нажатие ловит обёртка, крестик — сам тег.
              GestureDetector(
                onTap: widget.onRecentTap == null
                    ? null
                    : () => widget.onRecentTap!(item),
                child: PersonalizationTag(
                  label: item,
                  view: PersonalizationTagView.secondary,
                  onRemove: () => widget.onRecentRemove?.call(item),
                  removeIconBuilder: _removeIcon,
                ),
              ),
            if (widget.moreText != null && widget.moreText!.isNotEmpty)
              GestureDetector(
                onTap: widget.onMoreRecent,
                child: PersonalizationTag(
                  label: widget.moreText!,
                  view: PersonalizationTagView.primary,
                ),
              ),
          ],
        ),
      if (widget.suggestions.isNotEmpty)
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            for (final item in widget.suggestions)
              GestureDetector(
                onTap: widget.onSuggestionTap == null
                    ? null
                    : () => widget.onSuggestionTap!(item),
                child: PersonalizationTag(
                  label: item,
                  view: PersonalizationTagView.secondary,
                ),
              ),
          ],
        ),
      if (widget.categories.isNotEmpty) separator,
      if (widget.categories.isNotEmpty &&
          widget.categoriesLabel != null &&
          widget.categoriesLabel!.isNotEmpty)
        PersonalizationListLabel(label: widget.categoriesLabel!),
      if (widget.categories.isNotEmpty)
        rows(
          widget.categories,
          PersonalizationSuggestionKind.category,
          widget.onCategoryTap,
        ),
      if (widget.products.isNotEmpty) separator,
      if (widget.products.isNotEmpty &&
          widget.productsLabel != null &&
          widget.productsLabel!.isNotEmpty)
        PersonalizationListLabel(label: widget.productsLabel!),
      if (widget.products.isNotEmpty)
        rows(
          widget.products,
          PersonalizationSuggestionKind.product,
          widget.onProductTap,
        ),
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
