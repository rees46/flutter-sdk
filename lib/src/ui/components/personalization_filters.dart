import 'package:flutter/widgets.dart';

import '../personalization_icons.dart';
import '../personalization_theme.dart';
import '../personalization_typography.dart';
import 'personalization_accordion.dart';
import 'personalization_button.dart';
import 'personalization_checkbox.dart';
import 'personalization_checkbox_with_label.dart';
import 'personalization_input_field.dart';
import 'personalization_title.dart';

/// Вариант в секции чекбоксов фильтров.
@immutable
class PersonalizationFilterOption {
  const PersonalizationFilterOption({
    required this.id,
    required this.label,
    this.checked = false,
  });

  final String id;
  final String label;
  final bool checked;

  PersonalizationFilterOption copyWith({bool? checked}) =>
      PersonalizationFilterOption(
        id: id,
        label: label,
        checked: checked ?? this.checked,
      );
}

/// Секция экрана фильтров: диапазон или список чекбоксов.
@immutable
sealed class PersonalizationFilterSection {
  const PersonalizationFilterSection({required this.id, required this.title});

  final String id;
  final String title;
}

/// Два поля «от — до». [select] — поля типа Select, список открывает хост.
class PersonalizationFilterRange extends PersonalizationFilterSection {
  const PersonalizationFilterRange({
    required super.id,
    required super.title,
    required this.fromLabel,
    required this.toLabel,
    this.from,
    this.to,
    this.select = false,
  });

  final String fromLabel;
  final String toLabel;
  final String? from;
  final String? to;
  final bool select;

  PersonalizationFilterRange copyWith({String? from, String? to}) =>
      PersonalizationFilterRange(
        id: id,
        title: title,
        fromLabel: fromLabel,
        toLabel: toLabel,
        from: from ?? this.from,
        to: to ?? this.to,
        select: select,
      );
}

/// Список чекбоксов; сверх [collapsedCount] прячется за аккордеон.
class PersonalizationFilterOptions extends PersonalizationFilterSection {
  const PersonalizationFilterOptions({
    required super.id,
    required super.title,
    required this.options,
    this.collapsedCount = 5,
    this.showMoreText,
    this.showLessText,
  });

  final List<PersonalizationFilterOption> options;
  final int collapsedCount;
  final String? showMoreText;
  final String? showLessText;

  PersonalizationFilterOptions copyWith({
    List<PersonalizationFilterOption>? options,
  }) => PersonalizationFilterOptions(
    id: id,
    title: title,
    options: options ?? this.options,
    collapsedCount: collapsedCount,
    showMoreText: showMoreText,
    showLessText: showLessText,
  );
}

/// Экран фильтров выдачи: заголовок с крестиком, секции и две кнопки внизу.
///
/// Источник: Figma Mobile SDK UI Kit, страница SearchResultsScreen — Search Results/Filters
/// (203:8083) и /Filters Dark Theme (241:10831). Заголовок — [PersonalizationTitle] c
/// ghost-кнопкой cross-large (Title/Filters, 204:8340). Секции двух видов: диапазон
/// «From — to» из двух [PersonalizationInputField] md и список
/// [PersonalizationCheckboxWithLabel] с [PersonalizationAccordion] «показать ещё».
/// Внизу [PersonalizationButton] md: secondary «Reset» и primary «Apply» поровну.
/// Шаг между секциями 16, внутри секции 12, заголовок секции — LG/Emphasized 18/28.
/// Фон экрана — Background/Generic.
///
/// Состояние чекбоксов, полей и раскрытия секций живёт здесь; хост получает изменения
/// колбэками и на «Apply» — итоговый список секций.
class PersonalizationFilters extends StatefulWidget {
  const PersonalizationFilters({
    super.key,
    required this.title,
    this.onClose,
    this.sections = const <PersonalizationFilterSection>[],
    this.resetText,
    this.applyText,
    this.onReset,
    this.onApply,
    this.onOptionToggle,
    this.onRangeChanged,
    this.onRangeSelectTap,
    this.iconBuilder,
  });

  final String title;
  final VoidCallback? onClose;
  final List<PersonalizationFilterSection> sections;
  final String? resetText;
  final String? applyText;
  final VoidCallback? onReset;
  final ValueChanged<List<PersonalizationFilterSection>>? onApply;

  /// Изменился чекбокс: секция, вариант, новое значение.
  final void Function(String sectionId, String optionId, bool checked)?
  onOptionToggle;

  /// Изменилось поле диапазона: секция, «от», «до».
  final void Function(String sectionId, String from, String to)? onRangeChanged;

  /// Нажато поле диапазона типа Select: секция и какое из двух (`true` — «от»).
  final void Function(String sectionId, bool isFrom)? onRangeSelectTap;

  final Widget Function(
    BuildContext context,
    String asset,
    double size,
    Color color,
  )?
  iconBuilder;

  @override
  State<PersonalizationFilters> createState() => _PersonalizationFiltersState();
}

class _PersonalizationFiltersState extends State<PersonalizationFilters> {
  late List<PersonalizationFilterSection> _sections = widget.sections;
  final Set<String> _expanded = <String>{};
  final Map<String, TextEditingController> _from =
      <String, TextEditingController>{};
  final Map<String, TextEditingController> _to =
      <String, TextEditingController>{};

  @override
  void didUpdateWidget(PersonalizationFilters oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.sections, widget.sections)) {
      _sections = widget.sections;
      for (final controller in _from.values.followedBy(_to.values)) {
        controller.dispose();
      }
      _from.clear();
      _to.clear();
    }
  }

  @override
  void dispose() {
    for (final controller in _from.values.followedBy(_to.values)) {
      controller.dispose();
    }
    super.dispose();
  }

  TextEditingController _fieldController(
    Map<String, TextEditingController> pool,
    String id,
    String? value,
  ) => pool.putIfAbsent(id, () => TextEditingController(text: value));

  void _update(
    String sectionId,
    PersonalizationFilterSection Function(PersonalizationFilterSection) change,
  ) {
    setState(() {
      _sections = <PersonalizationFilterSection>[
        for (final section in _sections)
          section.id == sectionId ? change(section) : section,
      ];
    });
  }

  Widget _label(
    BuildContext context,
    String text,
    TextStyle base,
    FontWeight weight,
  ) {
    final theme = PersonalizationTheme.of(context);
    return Text(
      text,
      style: base.copyWith(
        fontFamily: theme.fontFamily.familyFor(weight),
        package: theme.fontFamily.package,
        color: theme.colors.textPrimary,
      ),
    );
  }

  Widget _range(BuildContext context, PersonalizationFilterRange section) {
    Widget field(bool isFrom) {
      final controller = _fieldController(
        isFrom ? _from : _to,
        section.id,
        isFrom ? section.from : section.to,
      );
      return Expanded(
        child: PersonalizationInputField(
          controller: controller,
          size: PersonalizationInputFieldSize.md,
          type: section.select
              ? PersonalizationInputFieldType.select
              : PersonalizationInputFieldType.input,
          onChanged: (text) {
            _update(
              section.id,
              (s) => (s as PersonalizationFilterRange).copyWith(
                from: isFrom ? text : null,
                to: isFrom ? null : text,
              ),
            );
            widget.onRangeChanged?.call(
              section.id,
              _from[section.id]?.text ?? '',
              _to[section.id]?.text ?? '',
            );
          },
          onSelectTap: widget.onRangeSelectTap == null
              ? null
              : () => widget.onRangeSelectTap!(section.id, isFrom),
          iconBuilder: widget.iconBuilder,
        ),
      );
    }

    return Row(
      children: <Widget>[
        _label(
          context,
          section.fromLabel,
          PersonalizationTypography.baseDefault,
          FontWeight.w400,
        ),
        const SizedBox(width: 12),
        field(true),
        const SizedBox(width: 12),
        _label(
          context,
          section.toLabel,
          PersonalizationTypography.baseDefault,
          FontWeight.w400,
        ),
        const SizedBox(width: 12),
        field(false),
      ],
    );
  }

  Widget _options(BuildContext context, PersonalizationFilterOptions section) {
    final bool collapsible =
        section.options.length > section.collapsedCount &&
        (section.showMoreText ?? '').isNotEmpty;
    final bool open = _expanded.contains(section.id);
    final visible = collapsible && !open
        ? section.options.take(section.collapsedCount)
        : section.options;
    final rows = <Widget>[
      for (final option in visible)
        PersonalizationCheckboxWithLabel(
          label: option.label,
          state: option.checked
              ? PersonalizationCheckboxState.checked
              : PersonalizationCheckboxState.unchecked,
          onChanged: (next) {
            final checked = next == PersonalizationCheckboxState.checked;
            _update(section.id, (s) {
              final current = s as PersonalizationFilterOptions;
              return current.copyWith(
                options: <PersonalizationFilterOption>[
                  for (final item in current.options)
                    item.id == option.id
                        ? item.copyWith(checked: checked)
                        : item,
                ],
              );
            });
            widget.onOptionToggle?.call(section.id, option.id, checked);
          },
        ),
      if (collapsible)
        PersonalizationAccordion(
          label: open
              ? (section.showLessText ?? section.showMoreText!)
              : section.showMoreText!,
          count: open ? null : section.options.length - section.collapsedCount,
          expanded: open,
          onToggle: (next) => setState(
            () =>
                next ? _expanded.add(section.id) : _expanded.remove(section.id),
          ),
          iconBuilder: widget.iconBuilder,
        ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        for (int i = 0; i < rows.length; i++) ...<Widget>[
          if (i > 0) const SizedBox(height: 12),
          rows[i],
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = PersonalizationTheme.of(context).colors;
    const double sectionGap = 16;
    return ColoredBox(
      color: colors.backgroundGeneric,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          PersonalizationTitle(
            title: widget.title,
            trailing: PersonalizationButton(
              size: PersonalizationButtonSize.md,
              view: PersonalizationButtonView.ghost,
              iconStart: PersonalizationIcons.crossLarge,
              iconBuilder: widget.iconBuilder,
              onPressed: widget.onClose,
            ),
          ),
          for (final section in _sections) ...<Widget>[
            const SizedBox(height: sectionGap),
            _label(
              context,
              section.title,
              PersonalizationTypography.lgEmphasized,
              FontWeight.w600,
            ),
            const SizedBox(height: 12),
            switch (section) {
              PersonalizationFilterRange() => _range(context, section),
              PersonalizationFilterOptions() => _options(context, section),
            },
          ],
          const SizedBox(height: sectionGap * 2),
          Row(
            children: <Widget>[
              Expanded(
                child: PersonalizationButton(
                  label: widget.resetText,
                  size: PersonalizationButtonSize.md,
                  view: PersonalizationButtonView.secondary,
                  onPressed: widget.onReset,
                ),
              ),
              const SizedBox(width: sectionGap),
              Expanded(
                child: PersonalizationButton(
                  label: widget.applyText,
                  size: PersonalizationButtonSize.md,
                  view: PersonalizationButtonView.primary,
                  onPressed: widget.onApply == null
                      ? null
                      : () => widget.onApply!(_sections),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
