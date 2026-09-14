import 'package:flutter/widgets.dart';

import '../personalization_theme.dart';
import '../personalization_icons.dart';
import 'personalization_button.dart';
import 'personalization_button_group.dart';
import 'personalization_tag.dart';
import 'personalization_title.dart';

/// Применённый фильтр: подпись и снятие по крестику.
class PersonalizationSearchFilter {
  const PersonalizationSearchFilter({required this.label, required this.onRemove});

  final String label;
  final VoidCallback onRemove;
}

/// Строка «найдено N товаров». Слова — параметры, локализация за интегратором.
class PersonalizationSearchResults {
  const PersonalizationSearchResults({
    required this.prefix,
    required this.count,
    required this.suffix,
  });

  final String prefix;
  final int count;
  final String suffix;
}

/// Заголовок выдачи поиска.
///
/// Источник: Figma Mobile SDK UI Kit, секция Title (167:3802), символ Search results (167:3807).
/// Три ряда: заголовок с кнопкой «назад» и переключателем вида, строка с фильтром,
/// сортировкой и числом найденного, ряд применённых фильтров-тегов.
/// Два нижних ряда в макете скрываемые (showResults, showFilters) — здесь они
/// прячутся сами, когда данных нет.
///
/// Собран из готовых компонентов: [PersonalizationTitle], [PersonalizationButton],
/// [PersonalizationButtonGroup], [PersonalizationTag].
class PersonalizationSearchResultsTitle extends StatelessWidget {
  const PersonalizationSearchResultsTitle({
    super.key,
    required this.title,
    this.selectedViewIndex = 0,
    this.onBack,
    this.onViewChanged,
    this.onFilters,
    this.onSort,
    this.results,
    this.filters = const <PersonalizationSearchFilter>[],
    this.iconBuilder,
  });

  final String title;

  /// Индекс выбранного вида выдачи: 0 — плитка, 1 — список.
  final int selectedViewIndex;
  final VoidCallback? onBack;
  final ValueChanged<int>? onViewChanged;
  final VoidCallback? onFilters;
  final VoidCallback? onSort;
  final PersonalizationSearchResults? results;
  final List<PersonalizationSearchFilter> filters;

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
    final TextStyle regular = TextStyle(
      fontSize: 14,
      height: 20 / 14,
      letterSpacing: 0.05,
      fontWeight: FontWeight.w400,
      fontFamily: theme.fontFamily.familyFor(FontWeight.w400),
      package: theme.fontFamily.package,
      color: colors.textSecondary,
    );
    final TextStyle strong = regular.copyWith(fontWeight: FontWeight.w600);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        PersonalizationTitle(
          title: title,
          leading: PersonalizationButton(
            size: PersonalizationButtonSize.md,
            view: PersonalizationButtonView.ghost,
            iconStart: PersonalizationIcons.arrowLeft,
            iconBuilder: iconBuilder,
            onPressed: onBack,
          ),
          trailing: PersonalizationButtonGroup(
            items: const <PersonalizationButtonGroupItem>[
              PersonalizationButtonGroupItem(
                icon: PersonalizationIcons.grid2x2,
                activeIcon: PersonalizationIcons.grid2x2Fill,
              ),
              PersonalizationButtonGroupItem(
                icon: PersonalizationIcons.list,
                activeIcon: PersonalizationIcons.listFill,
              ),
            ],
            selectedIndex: selectedViewIndex,
            onSelected: onViewChanged,
            iconBuilder: iconBuilder,
          ),
        ),
        if (results != null) ...<Widget>[
          const SizedBox(height: 8),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              PersonalizationButton(
                size: PersonalizationButtonSize.md,
                view: PersonalizationButtonView.ghost,
                iconStart: PersonalizationIcons.equalizerHorizontal,
                iconBuilder: iconBuilder,
                onPressed: onFilters,
              ),
              const SizedBox(width: 4),
              PersonalizationButton(
                size: PersonalizationButtonSize.md,
                view: PersonalizationButtonView.ghost,
                iconStart: PersonalizationIcons.arrowsUpDown,
                iconBuilder: iconBuilder,
                onPressed: onSort,
              ),
              const SizedBox(width: 12),
              Text(results!.prefix, style: regular),
              const SizedBox(width: 4),
              Text('${results!.count}', style: strong),
              const SizedBox(width: 4),
              Text(results!.suffix, style: strong),
            ],
          ),
        ],
        if (filters.isNotEmpty) ...<Widget>[
          const SizedBox(height: 8),
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: <Widget>[
              for (final PersonalizationSearchFilter filter in filters)
                PersonalizationTag(
                  label: filter.label,
                  view: PersonalizationTagView.secondary,
                  onRemove: filter.onRemove,
                  removeIconBuilder: iconBuilder == null
                      ? null
                      : (BuildContext context, String asset) => iconBuilder!(
                            context,
                            asset,
                            16,
                            colors.textPrimary,
                          ),
                ),
            ],
          ),
        ],
      ],
    );
  }
}
