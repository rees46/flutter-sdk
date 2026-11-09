import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../popups_v3/popup_v3.dart';
import '../../popups_v3/popups_v3_api.dart';
import '../../popups_v3/popups_v3_engine.dart';
import 'popup_v3_design.dart';
import 'popup_v3_elements.dart';
import 'popup_v3_texts.dart';
import 'popup_v3_view.dart';

/// Показ попапов v3 над приложением — записями в оверлее корневого навигатора, поверх
/// страниц. Окно и полный экран вместе с затемнением всегда выше баннеров: баннер,
/// показанный при открытом окне, ложится под его затемнение. Касания мимо баннера уходят
/// в приложение, если у него нет затемнения и `lockBackgroundScroll`.
///
/// Окну нужен ещё и прозрачный маршрут диалога: он закрывает окно системным «назад» и
/// не пускает касания к страницам. Рисовать окно самим маршрутом нельзя: навигатор
/// держит чужие записи оверлея (баннеры) над записями маршрутов.
class PopupV3Host implements PopupsV3Presenter {
  PopupV3Host({PopupV3Texts? texts, this.platform}) : _texts = texts;

  final PopupV3Texts? _texts;

  /// Платформа ссылок (`key_ios` / `key_android`); `null` — текущая.
  final TargetPlatform? platform;

  /// Сколько ждать навигатор приложения на холодном старте.
  static const Duration navigatorWait = Duration(seconds: 10);

  static const Duration _transition = Duration(milliseconds: 220);

  /// Записи открытых окон по оверлеям: баннер встаёт ниже них.
  static final List<({OverlayState overlay, OverlayEntry entry})> _modals =
      <({OverlayState overlay, OverlayEntry entry})>[];

  @override
  Future<PopupsV3Shown?> present(
    PopupV3 popup,
    Map<String, String> variables,
    PopupV3Actions actions,
  ) async {
    final design = PopupV3Design.parse(
      popup.design,
      layout: popup.layout,
      types: popupV3ElementBuilders.keys.toSet(),
      runtime: variables,
      platform: platform,
    );
    design.dropped.forEach(
      (id, reason) => debugPrint(
        'PersonalizationPopupsV3: popup ${popup.id} element $id skipped — $reason',
      ),
    );
    if (design.isEmpty) {
      debugPrint(
        'PersonalizationPopupsV3: popup ${popup.id} not shown — empty design',
      );
      return null;
    }
    final navigator = await _navigator();
    if (navigator == null || !navigator.mounted) {
      debugPrint(
        'PersonalizationPopupsV3: popup ${popup.id} not shown — the app has no navigator',
      );
      return null;
    }
    final shown = PopupV3Shown._(actions);
    final texts = _texts ?? PopupV3Texts.device;
    Widget content(Widget child) => PopupV3Scope(
      design: design,
      actions: actions,
      texts: texts,
      onClose: shown.close,
      onDismiss: shown.dismiss,
      child: Material(type: MaterialType.transparency, child: child),
    );
    final overlay = navigator.overlay;
    if (overlay == null) return null;
    if (popup.isModal) {
      _presentModal(navigator, overlay, popup, design, shown, content);
    } else {
      _presentBanner(overlay, popup, design, shown, content);
    }
    return shown;
  }

  void _presentModal(
    NavigatorState navigator,
    OverlayState overlay,
    PopupV3 popup,
    PopupV3Design design,
    PopupV3Shown shown,
    Widget Function(Widget child) content,
  ) {
    final fullscreen = popup.layout == PopupV3Layout.fullscreen;
    final dim = design.frame.overlay;
    final dimmed = !fullscreen && dim.enabled;
    final layer = GlobalKey<_ModalLayerState>();
    late final OverlayEntry entry;
    late final ({OverlayState overlay, OverlayEntry entry}) record;
    var removed = false;
    void remove() {
      if (removed) return;
      removed = true;
      _modals.remove(record);
      try {
        entry.remove();
      } catch (_) {
        // Оверлей ушёл вместе с навигатором.
      }
      shown._gone();
    }

    final route = _PopupV3Route(
      barrierDismissible: false,
      barrierColor: const Color(0x00000000),
      transitionDuration: Duration.zero,
      pageBuilder: (context, _, _) => const SizedBox.shrink(),
    );
    entry = OverlayEntry(
      builder: (context) => content(
        _ModalLayer(
          key: layer,
          popup: popup,
          design: design,
          barrierColor: dimmed ? dim.color : const Color(0x00000000),
          barrierLabel:
              Localizations.of<MaterialLocalizations>(
                context,
                MaterialLocalizations,
              )?.modalBarrierDismissLabel ??
              'Dismiss',
          onBarrierTap: dimmed ? shown.close : null,
          onRemoved: remove,
        ),
      ),
    );
    record = (overlay: overlay, entry: entry);
    // Ушёл маршрут («назад», закрытие, навигатор) — окно уезжает и убирается.
    void hide() {
      final state = layer.currentState;
      if (state == null) {
        remove();
      } else {
        state.hide();
      }
    }

    shown._remove = () {
      final routeNavigator = route.navigator;
      if (routeNavigator == null || !route.isActive) {
        hide();
      } else if (route.isCurrent) {
        routeNavigator.pop();
      } else {
        routeNavigator.removeRoute(route);
      }
    };
    _modals.add(record);
    overlay.insert(entry);
    unawaited(navigator.push(route));
    unawaited(route.gone.then((_) => hide()));
  }

  void _presentBanner(
    OverlayState overlay,
    PopupV3 popup,
    PopupV3Design design,
    PopupV3Shown shown,
    Widget Function(Widget child) content,
  ) {
    late final OverlayEntry entry;
    final layer = GlobalKey<_BannerLayerState>();
    var removed = false;
    void remove() {
      if (removed) return;
      removed = true;
      entry.remove();
      shown._gone();
    }

    entry = OverlayEntry(
      builder: (context) => content(
        _BannerLayer(
          key: layer,
          popup: popup,
          design: design,
          onClose: shown.close,
          onRemoved: remove,
        ),
      ),
    );
    shown._remove = () {
      final state = layer.currentState;
      if (state == null) {
        remove();
      } else {
        state.hide();
      }
    };
    // Под открытым окном: его затемнение накрывает и баннер.
    OverlayEntry? below;
    for (final modal in _modals) {
      if (identical(modal.overlay, overlay)) {
        below = modal.entry;
        break;
      }
    }
    overlay.insert(entry, below: below);
  }

  Future<NavigatorState?> _navigator() async {
    const poll = Duration(milliseconds: 100);
    for (var waited = Duration.zero; waited < navigatorWait; waited += poll) {
      final navigator = _rootNavigator();
      if (navigator != null) return navigator;
      await Future<void>.delayed(poll);
    }
    return _rootNavigator();
  }

  /// Корневой навигатор приложения — первый вниз по дереву.
  static NavigatorState? _rootNavigator() {
    NavigatorState? found;
    void visit(Element element) {
      if (found != null) return;
      if (element is StatefulElement && element.state is NavigatorState) {
        found = element.state as NavigatorState;
        return;
      }
      element.visitChildElements(visit);
    }

    WidgetsBinding.instance.rootElement?.visitChildElements(visit);
    return found;
  }
}

/// Показанный попап v3: закрытие пользователем шлёт `close`, [dismiss] — нет.
class PopupV3Shown implements PopupsV3Shown {
  PopupV3Shown._(this._actions);

  final PopupV3Actions _actions;
  final Completer<void> _closed = Completer<void>();
  VoidCallback? _remove;
  bool _silent = false;

  @override
  Future<void> get closed => _closed.future;

  /// Закрыть пользователем: крестик, кнопка `close`, затемнение, «назад», свайп.
  void close() => _remove?.call();

  @override
  void dismiss() {
    _silent = true;
    _remove?.call();
  }

  void _gone() {
    if (_closed.isCompleted) return;
    if (!_silent) _actions.event(PopupV3Event.close);
    _closed.complete();
  }
}

/// Прозрачный маршрут окна: системное «назад» и блокировка страниц под окном. [gone] —
/// маршрут ушёл по любой причине.
class _PopupV3Route extends RawDialogRoute<void> {
  _PopupV3Route({
    required super.pageBuilder,
    super.barrierDismissible,
    super.barrierColor,
    super.transitionDuration,
  });

  final Completer<void> _gone = Completer<void>();

  Future<void> get gone => _gone.future;

  @override
  void didComplete(void result) {
    super.didComplete(result);
    if (!_gone.isCompleted) _gone.complete();
  }

  @override
  void dispose() {
    if (!_gone.isCompleted) _gone.complete();
    super.dispose();
  }
}

/// Окно по центру (поля 16 сверху и снизу, над клавиатурой) или полный экран в
/// безопасной зоне (фон рамки — и под системными полосами).
class _ModalPage extends StatelessWidget {
  const _ModalPage({required this.popup, required this.design});

  final PopupV3 popup;
  final PopupV3Design design;

  static const double _margin = 16;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final safe = MediaQuery.paddingOf(context);
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    final bottom = math.max(safe.bottom, keyboard);
    if (popup.layout == PopupV3Layout.fullscreen) {
      return ColoredBox(
        color: design.frame.background,
        child: Padding(
          padding: EdgeInsets.fromLTRB(safe.left, safe.top, safe.right, bottom),
          child: PopupV3FrameView(
            design: design,
            layout: popup.layout,
            screen: size,
            maxWidth: math.max(0, size.width - safe.horizontal),
            maxHeight: math.max(0, size.height - safe.top - bottom),
          ),
        ),
      );
    }
    final top = safe.top + _margin;
    final available = math.max(0.0, size.height - top - bottom - _margin);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        safe.left,
        top,
        safe.right,
        bottom + _margin,
      ),
      child: Center(
        child: PopupV3FrameView(
          design: design,
          layout: popup.layout,
          screen: size,
          maxWidth: math.max(0, size.width - safe.horizontal),
          maxHeight: available,
        ),
      ),
    );
  }
}

/// Окно с затемнением: затемнение проявляется, окно — ещё и из 95 % масштаба; тап по
/// затемнению — [onBarrierTap] (без него затемнение только не пускает касания).
class _ModalLayer extends StatefulWidget {
  const _ModalLayer({
    super.key,
    required this.popup,
    required this.design,
    required this.barrierColor,
    required this.barrierLabel,
    required this.onBarrierTap,
    required this.onRemoved,
  });

  final PopupV3 popup;
  final PopupV3Design design;
  final Color barrierColor;
  final String barrierLabel;
  final VoidCallback? onBarrierTap;
  final VoidCallback onRemoved;

  @override
  State<_ModalLayer> createState() => _ModalLayerState();
}

class _ModalLayerState extends State<_ModalLayer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: PopupV3Host._transition,
  )..forward();
  late final Animation<double> _curve = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOutCubic,
    reverseCurve: Curves.easeInCubic,
  );
  bool _hiding = false;

  /// Исчезнуть и убраться.
  void hide() {
    if (_hiding) return;
    _hiding = true;
    _controller.reverse().whenComplete(widget.onRemoved);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fullscreen = widget.popup.layout == PopupV3Layout.fullscreen;
    final page = _ModalPage(popup: widget.popup, design: widget.design);
    return IgnorePointer(
      ignoring: _hiding,
      child: Stack(
        children: <Widget>[
          Positioned.fill(
            child: Semantics(
              label: widget.onBarrierTap == null ? null : widget.barrierLabel,
              button: widget.onBarrierTap != null,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: widget.onBarrierTap,
                child: FadeTransition(
                  opacity: _curve,
                  child: ColoredBox(color: widget.barrierColor),
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: FadeTransition(
              opacity: _curve,
              child: fullscreen
                  ? page
                  : ScaleTransition(
                      scale: Tween<double>(begin: 0.95, end: 1).animate(_curve),
                      child: page,
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Баннер сверху или снизу: отступы `offsetX/offsetY` от краёв безопасной зоны, поле 16
/// с противоположной стороны. Въезжает от края, свайп к краю закрывает. Затемнение —
/// если включено (тап по нему закрывает); `lockBackgroundScroll` без затемнения — касания
/// мимо баннера не доходят до приложения.
class _BannerLayer extends StatefulWidget {
  const _BannerLayer({
    super.key,
    required this.popup,
    required this.design,
    required this.onClose,
    required this.onRemoved,
  });

  final PopupV3 popup;
  final PopupV3Design design;
  final VoidCallback onClose;
  final VoidCallback onRemoved;

  @override
  State<_BannerLayer> createState() => _BannerLayerState();
}

class _BannerLayerState extends State<_BannerLayer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: PopupV3Host._transition,
  )..forward();
  late final Animation<double> _curve = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOutCubic,
    reverseCurve: Curves.easeInCubic,
  );
  bool _hiding = false;

  /// Уехать к краю и убраться.
  void hide() {
    if (_hiding) return;
    _hiding = true;
    _controller.reverse().whenComplete(widget.onRemoved);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  static const double _margin = 16;

  @override
  Widget build(BuildContext context) {
    final popup = widget.popup;
    final frame = widget.design.frame;
    final size = MediaQuery.sizeOf(context);
    final safe = MediaQuery.paddingOf(context);
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    final top = popup.placement == PopupV3Placement.top;
    final bottomInset = math.max(safe.bottom, keyboard);
    final edge = (top ? safe.top : bottomInset) + frame.offsetY;
    final opposite = (top ? bottomInset : safe.top) + _margin;
    final banner = PopupV3FrameView(
      design: widget.design,
      layout: popup.layout,
      screen: size,
      maxWidth: math.max(0, size.width - safe.horizontal - 2 * frame.offsetX),
      maxHeight: math.max(0, size.height - edge - opposite),
    );
    final overlay = frame.overlay;
    return Stack(
      children: <Widget>[
        if (overlay.enabled)
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: widget.onClose,
              child: FadeTransition(
                opacity: _curve,
                child: ColoredBox(color: overlay.color),
              ),
            ),
          )
        else if (frame.lockBackground)
          const Positioned.fill(child: AbsorbPointer()),
        Positioned(
          left: safe.left + frame.offsetX,
          right: safe.right + frame.offsetX,
          top: top ? edge : null,
          bottom: top ? null : edge,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: Offset(0, top ? -1 : 1),
              end: Offset.zero,
            ).animate(_curve),
            child: FadeTransition(
              opacity: _curve,
              child: Align(
                alignment: top ? Alignment.topCenter : Alignment.bottomCenter,
                heightFactor: 1,
                child: Dismissible(
                  key: ValueKey<String>('popup-v3-banner-${popup.id}'),
                  direction: top ? DismissDirection.up : DismissDirection.down,
                  onDismissed: (_) {
                    _hiding = true;
                    widget.onRemoved();
                  },
                  child: banner,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
