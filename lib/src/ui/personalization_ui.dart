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
export 'components/personalization_toast.dart';
// Кодировщик Code 128 (personalization_code128.dart) не экспортируется — это
// внутренность штрихкода.
export 'components/personalization_barcode.dart';
export 'components/personalization_loyalty_card.dart';
// Сторис V2. Заглушка-переливание (personalization_story_shimmer.dart) не
// экспортируется — это внутренность обложки и превью.
export 'components/personalization_story_cover.dart';
export 'components/personalization_story_preview.dart';
export 'components/personalization_stories_bar.dart';
export 'components/personalization_story_progress.dart';
export 'components/personalization_story_navigation.dart';
export 'components/personalization_story_sound_button.dart';
export 'components/personalization_story_price.dart';
export 'components/personalization_story_timer.dart';
export 'components/personalization_story_text_block.dart';
export 'components/personalization_story_used_products.dart';

// Виджеты с данными SDK: сами резолвят инстанс по shopId, ходят в поиск и держат состояние.
export 'widgets/search_support.dart' show PersonalizationSearchCategory;
export 'widgets/personalization_instant_search_field.dart';
export 'widgets/personalization_search_results_screen.dart';
// Модели блока сторис живут рядом с остальными ответами SDK, но до релиза кита
// видны только отсюда: пакетный барель их не экспортирует.
export '../stories/stories_response.dart' hide parseStoryOpacity;
export 'widgets/stories_support.dart' show PersonalizationStoryImageProvider;
export 'widgets/personalization_story_viewer.dart';
export 'widgets/personalization_stories.dart';
