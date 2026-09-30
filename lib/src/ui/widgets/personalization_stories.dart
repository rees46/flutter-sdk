import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../../multi_instance/rees46.dart';
import '../../personalization_sdk.dart';
import '../../stories/stories_response.dart';
import '../components/personalization_stories_bar.dart';
import 'personalization_story_viewer.dart';
import 'stories_support.dart';

/// Блок сторис с данными SDK: лента превью, по нажатию — полноэкранный просмотр.
///
/// Паттерн «Блок сторис на странице» из Figma (страница Stories, 1:32), источник —
/// `stories/{code}`. Визуальный слой — [PersonalizationStoriesBar] и
/// [PersonalizationStoryViewer]. Прежние сторис SDK не затрагивает.
///
/// Инстанс SDK: [sdk] явно, иначе [shopId] выбирает магазин при нескольких
/// зарегистрированных; без него берётся единственный (`REES46.getInstance`). Если
/// магазин не зарегистрирован, виджет остаётся пустым и пишет об этом в лог.
///
/// Пока блок грузится, в ленте заглушки; пустой блок или ошибка — виджет исчезает (ошибка
/// уходит в [onError]). Кольцо обложки поделено по слайдам; показанные слайды и
/// просмотренные сторис виджет помнит, пока жив: сторис считается просмотренной, когда
/// показаны все её слайды, а следующее открытие продолжает с первого непоказанного.
/// Сервер со своей стороны помнит просмотры по трекингу — при новой загрузке они придут в
/// `viewed` и `start_position`.
class PersonalizationStories extends StatefulWidget {
  const PersonalizationStories({
    super.key,
    required this.code,
    this.sdk,
    this.shopId,
    this.onLinkClick,
    this.onProductClick,
    this.onPromoCopied,
    this.onError,
    this.promoCopiedText = 'Copied',
    this.promoCodeCaption = 'Promo code',
    this.moreInfoText = 'More info',
    this.usedProductsText = 'Used products',
    this.hideProductsText = 'Hide products',
    this.padding = const EdgeInsets.all(16),
    this.imageProvider,
    this.iconBuilder,
  });

  /// Код блока сторис.
  final String code;

  /// Явный инстанс; иначе резолв по [shopId].
  final PersonalizationSdk? sdk;

  /// Магазин при нескольких зарегистрированных; без него — единственный.
  final String? shopId;

  /// См. [PersonalizationStoryViewer.onLinkClick].
  final ValueChanged<String>? onLinkClick;

  /// См. [PersonalizationStoryViewer.onProductClick].
  final ValueChanged<StoryProduct>? onProductClick;
  final ValueChanged<String>? onPromoCopied;
  final ValueChanged<Object>? onError;

  final String promoCopiedText;
  final String promoCodeCaption;
  final String moreInfoText;
  final String usedProductsText;
  final String hideProductsText;

  /// Поля ленты.
  final EdgeInsetsGeometry padding;

  /// Картинка по адресу; не задан — [NetworkImage].
  final PersonalizationStoryImageProvider? imageProvider;

  final Widget Function(
    BuildContext context,
    String asset,
    double size,
    Color color,
  )?
  iconBuilder;

  @override
  State<PersonalizationStories> createState() => _PersonalizationStoriesState();
}

class _PersonalizationStoriesState extends State<PersonalizationStories> {
  PersonalizationSdk? _sdk;
  List<Story> _stories = const <Story>[];
  bool _loading = true;
  int _seq = 0;

  /// Сколько первых слайдов показано, по id сторис.
  final Map<String, int> _seen = <String, int>{};

  /// Сторис, досмотренные в этом виджете.
  final Set<String> _viewed = <String>{};

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  @override
  void didUpdateWidget(PersonalizationStories oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sdk != widget.sdk ||
        oldWidget.shopId != widget.shopId ||
        oldWidget.code != widget.code) {
      _resolve();
    }
  }

  void _resolve() {
    PersonalizationSdk? sdk = widget.sdk;
    if (sdk == null) {
      try {
        sdk = REES46.getInstance(widget.shopId);
      } catch (error) {
        debugPrint(
          'PersonalizationStories: cannot resolve an SDK for '
          'shopId=${widget.shopId} — $error',
        );
        // После кадра: резолв идёт и из initState, а хост в ответ может, например,
        // показать снекбар — посреди сборки это запрещено.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) widget.onError?.call(error);
        });
      }
    }
    _sdk = sdk;
    _load();
  }

  Future<void> _load() async {
    final seq = ++_seq;
    final sdk = _sdk;
    _seen.clear();
    _viewed.clear();
    if (sdk == null || widget.code.isEmpty) {
      setState(() {
        _loading = false;
        _stories = const <Story>[];
      });
      return;
    }
    setState(() => _loading = true);
    try {
      final block = await sdk.getStories(widget.code);
      if (!mounted || seq != _seq) return;
      setState(() {
        _loading = false;
        _stories = block.stories
            .where((story) => story.slides.isNotEmpty)
            .toList();
      });
    } catch (error) {
      if (!mounted || seq != _seq) return;
      setState(() {
        _loading = false;
        _stories = const <Story>[];
      });
      widget.onError?.call(error);
    }
  }

  int _seenOf(Story story) => _seen[story.id] ?? story.startPosition;

  bool _isViewed(Story story) => story.viewed || _viewed.contains(story.id);

  /// С какого слайда открыть: первый непоказанный, у досмотренной — с начала.
  int _startOf(Story story) {
    final seen = _seenOf(story);
    return seen >= story.slides.length ? 0 : math.max(0, seen);
  }

  void _shown(Story story, int slideIndex) {
    if (!mounted) return;
    setState(() {
      final seen = math.max(_seenOf(story), slideIndex + 1);
      _seen[story.id] = seen;
      if (seen >= story.slides.length) _viewed.add(story.id);
    });
  }

  void _open(int index) {
    final stories = _stories;
    final viewer = PersonalizationStoryViewer(
      stories: stories,
      initialStory: index,
      startSlides: <String, int>{
        for (final story in stories) story.id: _startOf(story),
      },
      code: widget.code,
      sdk: _sdk,
      onSlideShown: _shown,
      onLinkClick: widget.onLinkClick,
      onProductClick: widget.onProductClick,
      onPromoCopied: widget.onPromoCopied,
      moreInfoText: widget.moreInfoText,
      promoCodeCaption: widget.promoCodeCaption,
      promoCopiedText: widget.promoCopiedText,
      usedProductsText: widget.usedProductsText,
      hideProductsText: widget.hideProductsText,
      imageProvider: widget.imageProvider,
      iconBuilder: widget.iconBuilder,
    );
    final navigator = Navigator.of(context, rootNavigator: true);
    // Тема ленты едет с просмотром: хост мог задать её поддереву, а не приложению.
    navigator.push(
      PersonalizationStoryViewer.route(
        InheritedTheme.capture(
          from: context,
          to: navigator.context,
        ).wrap(viewer),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return PersonalizationStoriesBar(loading: true, padding: widget.padding);
    }
    final stories = _stories;
    if (stories.isEmpty) return const SizedBox.shrink();
    return PersonalizationStoriesBar(
      padding: widget.padding,
      items: <PersonalizationStoryItem>[
        for (final story in stories)
          PersonalizationStoryItem(
            id: story.id,
            label: story.name,
            image: storyImage(story.avatar, widget.imageProvider),
            pinned: story.pinned,
            viewed: _isViewed(story),
            segments: story.slides.length,
            seenSegments: _seenOf(story),
          ),
      ],
      onItemTap: (item) {
        final index = stories.indexWhere((story) => story.id == item.id);
        if (index >= 0) _open(index);
      },
      iconBuilder: widget.iconBuilder,
    );
  }
}
