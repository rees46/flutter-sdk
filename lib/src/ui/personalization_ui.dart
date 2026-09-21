/// UI-кит дизайн-системы: токены, тема и все собранные на них компоненты.
///
/// Намеренно не экспортируется из `package:rees46_sdk/rees46_sdk.dart`. Кит ещё
/// собирается и ничем в SDK не используется, поэтому до релиза, который его
/// выпустит, он остаётся вне публичной поверхности. Пока единственный вход —
/// прямой импорт этого файла; анализатор помечает его как implementation
/// import, и это ожидаемо:
///
/// ```dart
/// // ignore: implementation_imports
/// import 'package:rees46_sdk/src/ui/personalization_ui.dart';
/// ```
///
/// Перед релизом эти экспорты переезжают в барель пакета, и кит становится
/// обычным публичным API.
library;

export 'personalization_typography.dart';
export 'personalization_spacing.dart';
export 'personalization_radius.dart';
export 'personalization_elevation.dart';
export 'personalization_icons.dart';
export 'personalization_colors.dart';
export 'personalization_theme.dart';

export 'components/personalization_in_app_popup.dart';
export 'components/personalization_badge.dart';
export 'components/personalization_tag.dart';
export 'components/personalization_checkbox.dart';
export 'components/personalization_checkbox_with_label.dart';
export 'components/personalization_loader.dart';
export 'components/personalization_empty_state.dart';
export 'components/personalization_button.dart';
export 'components/personalization_button_group.dart';
export 'components/personalization_input_field.dart';
export 'components/personalization_title.dart';
export 'components/personalization_link.dart';
export 'components/personalization_accordion.dart';
export 'components/personalization_list_label.dart';
export 'components/personalization_dots.dart';
export 'components/personalization_count.dart';
export 'components/personalization_rating.dart';
export 'components/personalization_search_results_title.dart';
export 'components/personalization_product_image.dart';
export 'components/personalization_favorites_badge.dart';
export 'components/personalization_product_card.dart';
export 'components/personalization_product.dart';
export 'components/personalization_products_list.dart';
export 'components/personalization_recommender_block.dart';
export 'components/personalization_suggestion_row.dart';
export 'components/personalization_instant_search.dart';
export 'components/personalization_filters.dart';
export 'components/personalization_catalog.dart';

// Виджеты с данными SDK: сами резолвят инстанс по shopId, ходят в поиск и держат состояние.
export 'widgets/search_support.dart' show PersonalizationSearchCategory;
export 'widgets/personalization_instant_search_field.dart';
export 'widgets/personalization_search_results_screen.dart';
