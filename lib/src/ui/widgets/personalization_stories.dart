import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../../multi_instance/rees46.dart';
import '../../personalization_sdk.dart';
import '../../stories/stories_response.dart';
import '../components/personalization_stories_bar.dart';
import 'personalization_story_viewer.dart';
import 'stories_playback.dart';
import 'stories_seen_store.dart';
import 'stories_support.dart';

/// Программное управление блоком сторис: открыть сторис, пауза, продолжение, перезагрузка.
///
/// Передаётся в [PersonalizationStories.controller] или в [PersonalizationStories.show].
/// [pause] и [resume] действуют на открытый просмотр; при закрытии просмотра пауза
/// снимается.
class PersonalizationStoriesController {
  _PersonalizationStoriesState? _bar;
  final ValueNotifier<bool> _paused = ValueNotifier<bool>(false);

  /// Открыть сторис номер [index] ленты — со стартового слайда по общим правилам. Future
  /// завершается, когда просмотр закроют. Блок ещё не загружен — ничего.
  Future<void> open(int index) => _bar?._open(index) ?? Future<void>.value();

  /// Открыть сторис с id [storyId]; нет такой — ничего.
  Future<void> openStory(String storyId) {
    final bar = _bar;
    if (bar == null) return Future<void>.value();
    final index = bar._stories.indexWhere((story) => story.id == storyId);
    return index < 0 ? Future<void>.value() : bar._open(index);
  }

  /// Остановить открытый просмотр.
  void pause() => _paused.value = true;

  /// Продолжить после [pause].
  void resume() => _paused.value = false;

  /// Заново загрузить блок.
  Future<void> reload() => _bar?._load() ?? Future<void>.value();
}

/// Блок сторис с данными SDK: лента превью, по нажатию — полноэкранный просмотр.
///
/// Паттерн «Блок сторис на странице» из Figma (страница Stories, 1:32), источник —
/// `stories/{code}`. Визуальный слой — [PersonalizationStoriesBar] и
/// [PersonalizationStoryViewer]. Без ленты сторис показывает [show].
///
/// Инстанс SDK: [sdk] явно, иначе [shopId] выбирает магазин при нескольких
/// зарегистрированных; без него берётся единственный (`REES46.getInstance`).
///
/// Пока блок грузится, в ленте заглушки. Пустой блок — виджет исчезает. Ошибка загрузки,
/// пустой [code], магазин не найден или неоднозначен, загрузка дольше 15 с — виджет
/// исчезает и зовёт [onError]; вечных заглушек нет. Сторис без слайдов выпадают.
///
/// Просмотренные слайды хранятся на устройстве по магазину и переживают перезапуск:
/// сторис просмотрена, когда так говорит сервер или просмотрены все её слайды; дуги
/// кольца горят по просмотренным слайдам; сторис открывается с первого
/// непросмотренного. Тексты и колбэки уходят в просмотр как есть.
class PersonalizationStories extends StatefulWidget {
  const PersonalizationStories({
    super.key,
    required this.code,
    this.sdk,
    this.shopId,
    this.controller,
    this.onLinkClick,
    this.onProductClick,
    this.onPromoCopied,
    this.onError,
    this.promoCopiedText = 'Copied',
    this.promoCaption = 'Promo code',
    this.productButtonText = 'More info',
    this.showProductsText = 'Used products',
    this.hideProductsText = 'Hide products',
    this.retryText = 'Retry',
    this.closeLabel = 'Close',
    this.soundOnLabel = 'Sound on',
    this.soundOffLabel = 'Sound off',
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

  /// Программное управление; см. [PersonalizationStoriesController].
  final PersonalizationStoriesController? controller;

  /// См. [PersonalizationStoryViewer.onLinkClick].
  final ValueChanged<String>? onLinkClick;

  /// См. [PersonalizationStoryViewer.onProductClick].
  final ValueChanged<StoryProduct>? onProductClick;
  final ValueChanged<String>? onPromoCopied;
  final ValueChanged<Object>? onError;

  /// Тексты просмотра — см. одноимённые у [PersonalizationStoryViewer].
  final String promoCopiedText;
  final String promoCaption;
  final String productButtonText;
  final String showProductsText;
  final String hideProductsText;
  final String retryText;
  final String closeLabel;
  final String soundOnLabel;
  final String soundOffLabel;

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

  /// Сколько ждать блок, прежде чем сдаться и позвать [onError].
  static const Duration loadTimeout = Duration(seconds: 15);

  /// Показать сторис блока [code] без ленты: загрузить блок и открыть просмотр — со
  /// сторис [startStoryId] (нет такой — с первой). Тексты, колбэки и [controller] — как
  /// у виджета. Ошибка (пустой код, магазин не найден, загрузка не удалась или дольше
  /// 15 с) уходит в [onError], просмотр не открывается. Future завершается, когда
  /// просмотр закроют.
  static Future<void> show(
    BuildContext context, {
    required String code,
    PersonalizationSdk? sdk,
    String? shopId,
    String? startStoryId,
    PersonalizationStoriesController? controller,
    ValueChanged<String>? onLinkClick,
    ValueChanged<StoryProduct>? onProductClick,
    ValueChanged<String>? onPromoCopied,
    ValueChanged<Object>? onError,
    String promoCopiedText = 'Copied',
    String promoCaption = 'Promo code',
    String productButtonText = 'More info',
    String showProductsText = 'Used products',
    String hideProductsText = 'Hide products',
    String retryText = 'Retry',
    String closeLabel = 'Close',
    String soundOnLabel = 'Sound on',
    String soundOffLabel = 'Sound off',
    PersonalizationStoryImageProvider? imageProvider,
    Widget Function(
      BuildContext context,
      String asset,
      double size,
      Color color,
    )?
    iconBuilder,
  }) async {
    // Носитель текстов и колбэков для просмотра; в дерево не вставляется.
    final config = PersonalizationStories(
      code: code,
      onLinkClick: onLinkClick,
      onProductClick: onProductClick,
      onPromoCopied: onPromoCopied,
      promoCopiedText: promoCopiedText,
      promoCaption: promoCaption,
      productButtonText: productButtonText,
      showProductsText: showProductsText,
      hideProductsText: hideProductsText,
      retryText: retryText,
      closeLabel: closeLabel,
      soundOnLabel: soundOnLabel,
      soundOffLabel: soundOffLabel,
      imageProvider: imageProvider,
      iconBuilder: iconBuilder,
    );
    final PersonalizationSdk resolved;
    final List<Story> stories;
    try {
      resolved = _resolve(sdk, shopId);
      stories = await _fetch(resolved, code);
    } catch (error) {
      debugPrint('PersonalizationStories.show: $code — $error');
      onError?.call(error);
      return;
    }
    if (stories.isEmpty || !context.mounted) return;
    final index = stories.indexWhere((story) => story.id == startStoryId);
    try {
      await _present(
        context,
        config: config,
        sdk: resolved,
        stories: stories,
        index: index < 0 ? 0 : index,
        paused: controller?._paused,
      );
    } finally {
      controller?._paused.value = false;
    }
  }

  @override
  State<PersonalizationStories> createState() => _PersonalizationStoriesState();
}

/// Открыть просмотр [stories] со сторис [index] поверх корневого навигатора; тексты и
/// колбэки — из [config]. Завершается, когда просмотр закроют.
Future<void> _present(
  BuildContext context, {
  required PersonalizationStories config,
  required PersonalizationSdk? sdk,
  required List<Story> stories,
  required int index,
  ValueListenable<bool>? paused,
  void Function(Story story, int slideIndex)? onSlideShown,
}) {
  final viewer = PersonalizationStoryViewer(
    stories: stories,
    initialStory: index,
    seen: sdk == null
        ? const <String, Set<String>>{}
        : StoriesSeenStore.instance.seen(sdk),
    code: config.code,
    sdk: sdk,
    paused: paused,
    onSlideShown: onSlideShown,
    onLinkClick: config.onLinkClick,
    onProductClick: config.onProductClick,
    onPromoCopied: config.onPromoCopied,
    productButtonText: config.productButtonText,
    promoCaption: config.promoCaption,
    promoCopiedText: config.promoCopiedText,
    showProductsText: config.showProductsText,
    hideProductsText: config.hideProductsText,
    retryText: config.retryText,
    closeLabel: config.closeLabel,
    soundOnLabel: config.soundOnLabel,
    soundOffLabel: config.soundOffLabel,
    imageProvider: config.imageProvider,
    iconBuilder: config.iconBuilder,
  );
  final navigator = Navigator.of(context, rootNavigator: true);
  // Тема едет с просмотром: хост мог задать её поддереву, а не приложению.
  return navigator.push(
    PersonalizationStoryViewer.route(
      InheritedTheme.capture(from: context, to: navigator.context).wrap(viewer),
    ),
  );
}

/// SDK по [sdk] или [shopId]; не вышло — ошибка резолва.
PersonalizationSdk _resolve(PersonalizationSdk? sdk, String? shopId) =>
    sdk ?? REES46.getInstance(shopId);

/// Блок [code] со сторис, у которых есть слайды, и просмотренное магазина — не дольше
/// [PersonalizationStories.loadTimeout].
Future<List<Story>> _fetch(PersonalizationSdk sdk, String code) async {
  if (code.isEmpty) {
    throw ArgumentError.value(code, 'code', 'must be non-empty');
  }
  // Просмотренное читается вместе с блоком; ошибка блока приходит как есть.
  final results = await Future.wait<Object>(<Future<Object>>[
    sdk.getStories(code),
    StoriesSeenStore.instance.load(sdk),
  ]).timeout(PersonalizationStories.loadTimeout);
  final block = results.first as StoriesBlock;
  return block.stories.where((story) => story.slides.isNotEmpty).toList();
}

class _PersonalizationStoriesState extends State<PersonalizationStories> {
  PersonalizationSdk? _sdk;
  List<Story> _stories = const <Story>[];
  bool _loading = true;
  int _seq = 0;
  bool _presenting = false;

  @override
  void initState() {
    super.initState();
    widget.controller?._bar = this;
    _load();
  }

  @override
  void didUpdateWidget(PersonalizationStories oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      if (oldWidget.controller?._bar == this) oldWidget.controller?._bar = null;
      widget.controller?._bar = this;
    }
    if (oldWidget.sdk != widget.sdk ||
        oldWidget.shopId != widget.shopId ||
        oldWidget.code != widget.code) {
      _load();
    }
  }

  @override
  void dispose() {
    if (widget.controller?._bar == this) widget.controller?._bar = null;
    super.dispose();
  }

  Future<void> _load() async {
    final seq = ++_seq;
    setState(() => _loading = true);
    try {
      final sdk = _sdk = _resolve(widget.sdk, widget.shopId);
      final stories = await _fetch(sdk, widget.code);
      if (!mounted || seq != _seq) return;
      setState(() {
        _loading = false;
        _stories = stories;
      });
    } catch (error) {
      if (!mounted || seq != _seq) return;
      debugPrint('PersonalizationStories: ${widget.code} — $error');
      setState(() {
        _loading = false;
        _stories = const <Story>[];
      });
      // После кадра: ошибка бывает и до первой сборки, а хост в ответ может, например,
      // показать снекбар — посреди сборки это запрещено.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onError?.call(error);
      });
    }
  }

  Future<void> _open(int index) async {
    final sdk = _sdk;
    if (_presenting || index < 0 || index >= _stories.length) return;
    _presenting = true;
    try {
      await _present(
        context,
        config: widget,
        sdk: sdk,
        stories: _stories,
        index: index,
        paused: widget.controller?._paused,
        onSlideShown: (_, _) {
          if (mounted) setState(() {});
        },
      );
    } finally {
      _presenting = false;
      widget.controller?._paused.value = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return PersonalizationStoriesBar(loading: true, padding: widget.padding);
    }
    final stories = _stories;
    final sdk = _sdk;
    if (stories.isEmpty || sdk == null) return const SizedBox.shrink();
    final seen = StoriesSeenStore.instance.seen(sdk);
    return PersonalizationStoriesBar(
      padding: widget.padding,
      items: <PersonalizationStoryItem>[
        for (final story in stories)
          _item(story, seen[story.id] ?? const <String>{}),
      ],
      onItemTap: (item) =>
          _open(stories.indexWhere((story) => story.id == item.id)),
      iconBuilder: widget.iconBuilder,
    );
  }

  PersonalizationStoryItem _item(Story story, Set<String> seen) =>
      PersonalizationStoryItem(
        id: story.id,
        label: story.name,
        image: storyImage(story.avatar, widget.imageProvider),
        pinned: story.pinned,
        viewed: StoriesPlayback.isViewed(story, seen),
        segments: story.slides.length,
        seenSegments: <int>{
          for (var i = 0; i < story.slides.length; i++)
            if (seen.contains(story.slides[i].id)) i,
        },
      );
}
