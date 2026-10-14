import 'package:flutter/widgets.dart';

import 'personalization_story_cover.dart';
import 'personalization_story_preview.dart';

/// Данные превью в ленте сторис.
@immutable
class PersonalizationStoryItem {
  const PersonalizationStoryItem({
    required this.id,
    required this.label,
    this.image,
    this.pinned = false,
    this.viewed = false,
    this.segments = 0,
    this.seenSegments = const <int>{},
  });

  final String id;
  final String label;

  /// Картинку даёт хост — кит не тянет сеть.
  final ImageProvider? image;
  final bool pinned;
  final bool viewed;

  /// См. [PersonalizationStoryCover.segments].
  final int segments;

  /// См. [PersonalizationStoryCover.seenSegments].
  final Set<int> seenSegments;
}

/// Лента сторис: превью в горизонтальной прокрутке.
///
/// Источник: Figma Mobile SDK UI Kit, страница Stories (1:32), фреймы «Блок сторис на
/// странице» (светлый и тёмный).
///
/// Превью [PersonalizationStoryPreview] с шагом 16, поля ленты 16 — оба хост может
/// переопределить. Пока идёт загрузка ([loading]), вместо превью — [skeletonCount]
/// заглушек.
class PersonalizationStoriesBar extends StatelessWidget {
  const PersonalizationStoriesBar({
    super.key,
    this.items = const <PersonalizationStoryItem>[],
    this.loading = false,
    this.skeletonCount = 4,
    this.padding = const EdgeInsets.all(16),
    this.gap = 16,
    this.onItemTap,
    this.iconBuilder,
  });

  final List<PersonalizationStoryItem> items;

  /// Идёт загрузка: вместо [items] — заглушки.
  final bool loading;
  final int skeletonCount;
  final EdgeInsetsGeometry padding;
  final double gap;
  final ValueChanged<PersonalizationStoryItem>? onItemTap;

  final Widget Function(
    BuildContext context,
    String asset,
    double size,
    Color color,
  )?
  iconBuilder;

  @override
  Widget build(BuildContext context) {
    final previews = <Widget>[
      if (loading)
        for (int i = 0; i < skeletonCount; i++)
          const PersonalizationStoryPreview(
            state: PersonalizationStoryCoverState.skeleton,
          )
      else
        for (final item in items)
          PersonalizationStoryPreview(
            key: ValueKey<String>(item.id),
            label: item.label,
            image: item.image,
            state: item.viewed
                ? PersonalizationStoryCoverState.viewed
                : PersonalizationStoryCoverState.unviewed,
            pinned: item.pinned,
            segments: item.segments,
            seenSegments: item.seenSegments,
            onTap: onItemTap == null ? null : () => onItemTap!(item),
            iconBuilder: iconBuilder,
          ),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          for (int i = 0; i < previews.length; i++) ...<Widget>[
            if (i > 0) SizedBox(width: gap),
            previews[i],
          ],
        ],
      ),
    );
  }
}
