import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../multi_instance/rees46.dart';
import '../../personalization_sdk.dart';
import '../../search/search_params.dart';
import '../../search/search_response.dart';
import '../../tracking/tracking_models.dart';
import '../components/personalization_instant_search.dart';
import 'search_support.dart';

/// Мгновенный поиск с данными SDK: поле ввода, недавние запросы, подсказки, категории и
/// товары — виджет сам ходит в `searchInstant` / `searchBlank` и держит состояние.
///
/// Паттерн InstantSearchField из Figma (страница 1:29): «компонент владеет вводом»,
/// источник — `searchInstant(query)`. Визуальный слой — [PersonalizationInstantSearch].
///
/// Инстанс SDK: [sdk] явно, иначе [shopId] выбирает магазин при нескольких
/// зарегистрированных; без него берётся единственный (`REES46.getInstance`). Если магазин
/// не зарегистрирован, виджет остаётся пустым и пишет об этом в лог, а не роняет экран.
///
/// Пока запрос короче [minChars] показывается пустое состояние: история запросов
/// (локальная, по магазину, в SharedPreferences), а из `searchBlank` — товары и
/// популярные категории; популярные фразы (`suggests`) подставляются тегами, только если
/// истории ещё нет. При вводе после [debounce] уходит `searchInstant`: фразы из `queries`
/// — тегами, категории и товары — строками. Ответ на устаревший запрос отбрасывается.
///
/// Нажатие на товар или категорию запоминает источник `instant_search` в трекинге и
/// отдаёт объект хосту; отправка кладёт фразу в историю и вызывает [onSubmit] — экран
/// полной выдачи открывает хост, событие `search` трекает
/// `PersonalizationSearchResultsScreen`.
class PersonalizationInstantSearchField extends StatefulWidget {
  const PersonalizationInstantSearchField({
    super.key,
    this.sdk,
    this.shopId,
    this.debounce = const Duration(milliseconds: 300),
    this.minChars = 2,
    this.productsLimit = 5,
    this.categoriesLimit = 3,
    this.suggestionsLimit = 8,
    this.recentLimit = 10,
    this.recentCollapsed = 5,
    this.showRecent = true,
    this.showSuggestions = true,
    this.showCategories = true,
    this.showProducts = true,
    this.showImages = true,
    this.locations,
    this.placeholder,
    this.cancelText,
    this.recentLabel,
    this.clearText,
    this.moreText,
    this.categoriesLabel,
    this.productsLabel,
    this.onSubmit,
    this.onCancel,
    this.onProductTap,
    this.onCategoryTap,
    this.onError,
    this.iconBuilder,
  });

  /// Явный инстанс; иначе резолв по [shopId].
  final PersonalizationSdk? sdk;

  /// Магазин при нескольких зарегистрированных; без него — единственный.
  final String? shopId;

  final Duration debounce;
  final int minChars;
  final int productsLimit;
  final int categoriesLimit;
  final int suggestionsLimit;
  final int recentLimit;

  /// Сколько недавних запросов видно до тега «ещё».
  final int recentCollapsed;

  final bool showRecent;
  final bool showSuggestions;
  final bool showCategories;
  final bool showProducts;
  final bool showImages;

  /// Список id локаций через запятую.
  final String? locations;

  final String? placeholder;
  final String? cancelText;
  final String? recentLabel;
  final String? clearText;

  /// Подпись тега «ещё»; показывается, когда история длиннее [recentCollapsed].
  final String? moreText;
  final String? categoriesLabel;
  final String? productsLabel;

  final ValueChanged<String>? onSubmit;
  final VoidCallback? onCancel;
  final ValueChanged<SearchProduct>? onProductTap;
  final ValueChanged<PersonalizationSearchCategory>? onCategoryTap;
  final ValueChanged<Object>? onError;

  final Widget Function(
    BuildContext context,
    String asset,
    double size,
    Color color,
  )?
  iconBuilder;

  @override
  State<PersonalizationInstantSearchField> createState() =>
      _PersonalizationInstantSearchFieldState();
}

class _PersonalizationInstantSearchFieldState
    extends State<PersonalizationInstantSearchField> {
  final TextEditingController _controller = TextEditingController();
  PersonalizationSdk? _sdk;
  RecentSearches? _recent;
  List<String> _recentItems = const <String>[];
  bool _recentExpanded = false;
  SearchBlankResponse? _blank;
  SearchInstantResponse? _instant;
  int _seq = 0;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  @override
  void didUpdateWidget(PersonalizationInstantSearchField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sdk != widget.sdk || oldWidget.shopId != widget.shopId) {
      _resolve();
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _resolve() {
    PersonalizationSdk? sdk = widget.sdk;
    if (sdk == null) {
      try {
        sdk = REES46.getInstance(widget.shopId);
      } catch (error) {
        debugPrint(
          'PersonalizationInstantSearchField: cannot resolve an SDK for '
          'shopId=${widget.shopId} — $error',
        );
        widget.onError?.call(error);
      }
    }
    _sdk = sdk;
    if (sdk == null) return;
    _recent = RecentSearches(
      shopKey: sdk.shopId ?? widget.shopId ?? 'default',
      limit: widget.recentLimit,
    );
    _recent!.load().then((items) {
      if (mounted) setState(() => _recentItems = items);
    });
    _loadBlank(sdk);
  }

  Future<void> _loadBlank(PersonalizationSdk sdk) async {
    try {
      final response = await sdk.searchBlank();
      // Пустое состояние не привязано к запросу: пригодится, когда поле очистят.
      if (!mounted) return;
      setState(() => _blank = response);
    } catch (error) {
      if (mounted) widget.onError?.call(error);
    }
  }

  bool get _typing => _controller.text.trim().length >= widget.minChars;

  void _typed(String text) {
    _debounce?.cancel();
    if (text.trim().length < widget.minChars) {
      _seq++;
      setState(() => _instant = null);
      return;
    }
    _debounce = Timer(widget.debounce, () => _runInstant(text.trim()));
  }

  Future<void> _runInstant(String text) async {
    final sdk = _sdk;
    if (sdk == null) return;
    final seq = ++_seq;
    try {
      final response = await sdk.searchInstant(
        text,
        params: widget.locations == null
            ? null
            : SearchInstantParams(locations: widget.locations),
      );
      if (!mounted || seq != _seq) return;
      setState(() => _instant = response);
    } catch (error) {
      if (mounted && seq == _seq) widget.onError?.call(error);
    }
  }

  Future<void> _submit(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    _recentExpanded = false;
    final recent = _recent;
    if (recent != null) {
      final items = await recent.add(trimmed);
      if (mounted) setState(() => _recentItems = items);
    }
    widget.onSubmit?.call(trimmed);
  }

  void _rememberSource() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    _sdk?.tracking.setSource(
      TrackingSource(type: TrackingSourceType.instantSearch, code: text),
    );
  }

  @override
  Widget build(BuildContext context) {
    final typing = _typing;
    final blank = _blank;
    final instant = _instant;

    final recentItems = !typing && widget.showRecent
        ? _recentItems
        : const <String>[];
    final collapsed =
        !_recentExpanded && recentItems.length > widget.recentCollapsed;
    final recentShown = collapsed
        ? recentItems.take(widget.recentCollapsed).toList()
        : recentItems;

    // Популярные фразы сервера заменяют пустую историю.
    List<String> suggestions;
    if (typing) {
      suggestions = widget.showSuggestions
          ? (instant?.queries ?? const <SearchSuggest>[])
                .map((item) => item.name)
                .take(widget.suggestionsLimit)
                .toList()
          : const <String>[];
    } else {
      suggestions = widget.showSuggestions && recentItems.isEmpty
          ? (blank?.suggests ?? const <SearchSuggest>[])
                .map((item) => item.name)
                .take(widget.suggestionsLimit)
                .toList()
          : const <String>[];
    }

    final categories = <PersonalizationSuggestion>[];
    final categoryTargets = <String, PersonalizationSearchCategory>{};
    if (widget.showCategories) {
      if (typing) {
        final all = instant?.categories ?? const <SearchCategory>[];
        for (final category in all.take(widget.categoriesLimit)) {
          categories.add(
            PersonalizationSuggestion(
              id: category.id,
              title: category.name,
              subtitle: parentName(category, all),
            ),
          );
          categoryTargets[category.id] = PersonalizationSearchCategory(
            id: category.id,
            name: category.name,
            url: category.url,
          );
        }
      } else {
        final popular = blank?.popularCategories ?? const <SearchSuggest>[];
        for (final item in popular.take(widget.categoriesLimit)) {
          final id = item.url.isNotEmpty ? item.url : item.name;
          categories.add(PersonalizationSuggestion(id: id, title: item.name));
          categoryTargets[id] = PersonalizationSearchCategory(
            id: null,
            name: item.name,
            url: item.url.isEmpty ? null : item.url,
          );
        }
      }
    }

    final products = <PersonalizationSuggestion>[];
    final productTargets = <String, SearchProduct>{};
    if (widget.showProducts) {
      final source = typing ? instant?.products : blank?.products;
      for (final product in (source ?? const <SearchProduct>[]).take(
        widget.productsLimit,
      )) {
        final card = toCardProduct(product, null);
        products.add(
          PersonalizationSuggestion(
            id: card.id,
            title: card.name,
            subtitle: card.price,
            image: widget.showImages ? card.image : null,
          ),
        );
        productTargets[card.id] = product;
      }
    }

    return PersonalizationInstantSearch(
      controller: _controller,
      placeholder: widget.placeholder,
      cancelText: widget.cancelText,
      onCancel: widget.onCancel,
      onQueryChanged: _typed,
      onSubmit: _submit,
      recentLabel: widget.recentLabel,
      clearText: widget.clearText,
      onClearRecent: () => _recent?.clear().then((items) {
        if (mounted) setState(() => _recentItems = items);
      }),
      recentSearches: recentShown,
      moreText: collapsed ? widget.moreText : null,
      onMoreRecent: () => setState(() => _recentExpanded = true),
      onRecentTap: (item) {
        _controller.text = item;
        _submit(item);
      },
      onRecentRemove: (item) => _recent?.remove(item).then((items) {
        if (mounted) setState(() => _recentItems = items);
      }),
      suggestions: suggestions,
      onSuggestionTap: (item) {
        _controller.text = item;
        _submit(item);
      },
      categoriesLabel: widget.categoriesLabel,
      categories: categories,
      onCategoryTap: (suggestion) {
        final target = categoryTargets[suggestion.id];
        if (target == null) return;
        _rememberSource();
        widget.onCategoryTap?.call(target);
      },
      productsLabel: widget.productsLabel,
      products: products,
      onProductTap: (suggestion) {
        final target = productTargets[suggestion.id];
        if (target == null) return;
        _rememberSource();
        widget.onProductTap?.call(target);
      },
      showImages: widget.showImages,
      iconBuilder: widget.iconBuilder,
    );
  }
}
