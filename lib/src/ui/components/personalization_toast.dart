import 'dart:async';

import 'package:flutter/semantics.dart';
import 'package:flutter/widgets.dart';

import '../personalization_elevation.dart';
import '../personalization_spacing.dart';
import '../personalization_theme.dart';

/// У какого края экрана показать тост.
enum PersonalizationToastPosition { top, bottom }

/// Тост: короткое сообщение-«пилюля» поверх экрана.
///
/// Источник: Figma Mobile SDK UI Kit, страница Components, секция Toast
/// (367:16179), компонент 367:16178. На странице Stories он же во фреймах
/// 367:16063 (снизу, «Copied») и 367:16106 (сверху, «Code copied to clipboard»).
///
/// Скругление — радиус Toast (999, то есть половина высоты), заливка
/// Background/Float, тень Elevation 2 цветом Shadow/Heavy темы. Поля 16 по
/// вертикали и 20 по горизонтали, текст 18/18 Medium по центру — однострочный
/// тост высотой 50. В макете текст залит сырым #000 без переменной, здесь
/// Text/Primary, чтобы тост работал и в тёмной теме.
///
/// Сам виджет — только пилюля. Показывает её [show]: поверх текущего экрана, по
/// центру, в 16 от края безопасной зоны, с появлением и исчезанием.
class PersonalizationToast extends StatelessWidget {
  const PersonalizationToast({super.key, required this.text});

  final String text;

  /// Появление и исчезание.
  static const Duration fadeDuration = Duration(milliseconds: 200);

  static _ShownToast? _current;

  /// Показывает тост поверх текущего экрана и через [duration] убирает.
  ///
  /// Кладётся в корневой [Overlay]: тост относится ко всему экрану, а не к
  /// вложенному навигатору. По центру, в 16 от края безопасной зоны; снизу — ещё
  /// и над клавиатурой, иначе она его закроет. Ширина — не больше экрана без
  /// 16 с каждой стороны, длинный текст переносится.
  ///
  /// Новый вызов заменяет тост, который ещё на экране, — стопкой они не
  /// копятся. Касания тост не перехватывает: всё под ним нажимается как
  /// обычно. Скринридеру текст объявляется.
  static void show(
    BuildContext context,
    String text, {
    PersonalizationToastPosition position = PersonalizationToastPosition.bottom,
    Duration duration = const Duration(milliseconds: 2000),
  }) {
    final overlay = Overlay.of(context, rootOverlay: true);
    _current?.remove();

    final toast = _ShownToast();
    toast.entry = OverlayEntry(
      builder: (context) => _ToastLayer(
        text: text,
        position: position,
        duration: duration,
        onHidden: toast.remove,
      ),
    );
    _current = toast;
    overlay.insert(toast.entry!);
    _announce(context, text);
  }

  // Где платформа умеет объявления (iOS, веб), текст объявляется явно. На
  // Android объявления устарели — там тост помечен живой областью, и TalkBack
  // зачитывает его сам (см. [_ToastLayer]).
  static void _announce(BuildContext context, String text) {
    if (!(MediaQuery.maybeSupportsAnnounceOf(context) ?? false)) return;
    final view = View.maybeOf(context);
    if (view == null) return;
    unawaited(
      SemanticsService.sendAnnouncement(
        view,
        text,
        Directionality.maybeOf(context) ?? TextDirection.ltr,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = PersonalizationTheme.of(context);
    final colors = theme.colors;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.backgroundFloat,
        borderRadius: BorderRadius.circular(theme.radius.toast),
        // Цвет тени из темы: в тёмной схеме Shadow/Heavy плотнее.
        boxShadow: <BoxShadow>[
          for (final shadow in PersonalizationElevation.e2)
            shadow.copyWith(color: colors.shadowHeavy),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          vertical: PersonalizationSpacing.xl,
          horizontal: PersonalizationSpacing.xl2,
        ),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 18,
            height: 1, // 18 / 18
            fontWeight: FontWeight.w500,
            letterSpacing: 0,
            fontFamily: theme.fontFamily.familyFor(FontWeight.w500),
            package: theme.fontFamily.package,
            color: colors.textPrimary,
          ),
        ),
      ),
    );
  }
}

/// Показанный тост: его запись в оверлее. Убирается один раз — по окончании
/// исчезания или когда его сменяет следующий.
class _ShownToast {
  OverlayEntry? entry;

  void remove() {
    final shown = entry;
    if (shown == null) return;
    entry = null;
    if (identical(PersonalizationToast._current, this)) {
      PersonalizationToast._current = null;
    }
    shown
      ..remove()
      ..dispose();
  }
}

/// Слой тоста в оверлее: раскладка по краю экрана, появление, таймер, исчезание.
class _ToastLayer extends StatefulWidget {
  const _ToastLayer({
    required this.text,
    required this.position,
    required this.duration,
    required this.onHidden,
  });

  final String text;
  final PersonalizationToastPosition position;
  final Duration duration;
  final VoidCallback onHidden;

  @override
  State<_ToastLayer> createState() => _ToastLayerState();
}

class _ToastLayerState extends State<_ToastLayer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _opacity;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _opacity = AnimationController(
      vsync: this,
      duration: PersonalizationToast.fadeDuration,
    )..forward();
    _timer = Timer(widget.duration, _hide);
  }

  // Будущее обратной анимации завершается только если она доиграла: сменённый
  // тост убирается сразу, и второй раз onHidden не придёт.
  void _hide() => _opacity.reverse().then((_) => widget.onHidden());

  @override
  void dispose() {
    _timer?.cancel();
    _opacity.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final safe = MediaQuery.paddingOf(context);
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    final top = widget.position == PersonalizationToastPosition.top;
    const edge = PersonalizationSpacing.xl;

    return IgnorePointer(
      child: Align(
        alignment: top ? Alignment.topCenter : Alignment.bottomCenter,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            safe.left + edge,
            top ? safe.top + edge : 0,
            safe.right + edge,
            top ? 0 : safe.bottom + keyboard + edge,
          ),
          child: FadeTransition(
            opacity: _opacity,
            child: Semantics(
              container: true,
              liveRegion: !MediaQuery.supportsAnnounceOf(context),
              // В корневом оверлее нет Material, и Text взял бы аварийный стиль
              // приложения — моноширинный с жёлтым подчёркиванием.
              child: DefaultTextStyle(
                style: const TextStyle(),
                child: PersonalizationToast(text: widget.text),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
