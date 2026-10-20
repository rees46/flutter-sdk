import 'dart:async';
import 'dart:collection';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../ui/components/personalization_in_app_popup.dart';
import '../ui/personalization_theme.dart';
import 'in_app_popup.dart';

/// Hands server popups of one SDK handle to the host, or shows them over the app's root
/// navigator.
///
/// Follows the native SDKs: a popup shown within the last minute is dropped when the
/// server sends it again, one popup is on screen at a time, and a popup that never reached
/// the screen is neither reported nor remembered. Unlike them it waits out the delay the
/// shop set, as the React Native SDK does.
class PopupPresenter {
  PopupPresenter({
    required Future<void> Function(int popupId) trackShown,
    required Future<bool> Function(String url) openUrl,
    required Future<void> Function() openNotificationSettings,
    DateTime Function()? now,
    ImageProvider Function(String url)? image,
  }) : _trackShown = trackShown,
       _openUrl = openUrl,
       _openNotificationSettings = openNotificationSettings,
       _now = now ?? DateTime.now,
       _imageFor = image ?? NetworkImage.new;

  final Future<void> Function(int popupId) _trackShown;
  final Future<bool> Function(String url) _openUrl;
  final Future<void> Function() _openNotificationSettings;
  final DateTime Function() _now;
  final ImageProvider Function(String url) _imageFor;

  /// Whether popups are shown while no [onPopup] is set.
  bool autoPresentation = true;

  /// Takes every popup instead of the SDK showing it.
  void Function(InAppPopup popup)? onPopup;

  /// A popup shown within this window is not shown again.
  static const Duration repeatWindow = Duration(minutes: 1);

  /// How long a popup waits for the app's navigator, which is not there yet when the
  /// init response comes before the app's first frame.
  static const Duration navigatorWait = Duration(seconds: 10);

  static const Duration _navigatorPoll = Duration(milliseconds: 100);

  final Map<int, DateTime> _shownAt = <int, DateTime>{};
  final Set<int> _delayed = <int>{};
  final Queue<_Request> _queue = Queue<_Request>();
  _Request? _current;

  /// A popup from the server: waits out its delay, then goes to [onPopup] or on screen.
  void receive(InAppPopup popup) {
    // An init response without a popup still gives one on iOS: the SDK builds it from an
    // empty object, so it carries the model's defaults (id 0, no position, no
    // components). Its own views skip it for want of a title; here a popup with nothing
    // to show is dropped as well.
    if (!popup.hasContent) return;
    if (_isRepeat(popup.id) || !_delayed.add(popup.id)) return;
    Timer(popup.delay, () {
      _delayed.remove(popup.id);
      if (_isRepeat(popup.id)) return;
      final handler = onPopup;
      if (handler != null) {
        try {
          handler(popup);
        } catch (error, stack) {
          _log('popup ${popup.id}: onPopup failed — $error\n$stack');
        }
        return;
      }
      if (!autoPresentation) {
        _log('popup ${popup.id} not shown: automatic presentation is off');
        return;
      }
      unawaited(present(popup));
    });
  }

  /// Shows [popup] after the one on screen, if any. Completes when the popup closes, or
  /// at once when it cannot be shown.
  Future<void> present(InAppPopup popup) {
    final same = <_Request>[
      ?_current,
      ..._queue,
    ].where((request) => request.popup.id == popup.id);
    if (same.isNotEmpty) return same.first.done.future;

    final request = _Request(popup);
    _queue.add(request);
    _next();
    return request.done.future;
  }

  /// Remembers [popupId] as shown, so a repeat within [repeatWindow] is dropped.
  void markShown(int popupId) => _shownAt[popupId] = _now();

  bool _isRepeat(int popupId) {
    final shown = _shownAt[popupId];
    if (shown == null) return false;
    if (_now().difference(shown) < repeatWindow) return true;
    _shownAt.remove(popupId);
    return false;
  }

  void _next() {
    if (_current != null || _queue.isEmpty) return;
    final request = _current = _queue.removeFirst();
    _show(request)
        .catchError((Object error, StackTrace stack) {
          _log('popup ${request.popup.id} not shown: $error\n$stack');
        })
        .whenComplete(() {
          if (!request.done.isCompleted) request.done.complete();
          _current = null;
          _next();
        });
  }

  Future<void> _show(_Request request) async {
    final popup = request.popup;
    final navigator = await _navigator();
    if (navigator == null) {
      _log('popup ${popup.id} not shown: the app has no navigator');
      return;
    }
    // No repeat check here: server repeats are dropped on arrival, and a popup the app
    // asks for is shown even if it was shown a moment ago.
    final navigatorContext = navigator.context;
    if (!navigatorContext.mounted) return;

    final picture = await _loadImage(popup.imageUrl, navigatorContext);
    if (!navigatorContext.mounted) return;

    final route = _route(popup, picture, navigatorContext);
    unawaited(navigator.push(route));
    markShown(popup.id);
    _run('popup ${popup.id}: shown, not reported', () => _trackShown(popup.id));
    // Not the future push returns: it never completes when the navigator goes away with
    // the popup on screen, and the queue would stand still for the rest of the session.
    await route.gone;
  }

  Future<NavigatorState?> _navigator() async {
    for (
      var waited = Duration.zero;
      waited < navigatorWait;
      waited += _navigatorPoll
    ) {
      final navigator = rootNavigator();
      if (navigator != null) return navigator;
      await Future<void>.delayed(_navigatorPoll);
    }
    return rootNavigator();
  }

  /// The app's root navigator: the first one down the widget tree. `MaterialApp`,
  /// `CupertinoApp` and `WidgetsApp` build it, and so does the router of
  /// `MaterialApp.router`; nested navigators (tabs) sit inside it, so the walk reaches the
  /// root one first. The one `showDialog` uses by default.
  @visibleForTesting
  static NavigatorState? rootNavigator() {
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

  /// The popup's picture and its width to height, loaded before the popup shows so it
  /// does not pop in later. One that fails to load leaves the popup without a picture,
  /// as on iOS.
  Future<_Picture?> _loadImage(String? url, BuildContext context) async {
    if (url == null) return null;
    final image = _imageFor(url);
    final loaded = Completer<Size?>();
    final stream = image.resolve(createLocalImageConfiguration(context));
    late final ImageStreamListener listener;
    listener = ImageStreamListener(
      (info, _) {
        if (!loaded.isCompleted) {
          loaded.complete(
            Size(info.image.width.toDouble(), info.image.height.toDouble()),
          );
        }
        // As precacheImage does: hold the image until the popup that shows it is built.
        SchedulerBinding.instance.addPostFrameCallback((_) {
          info.dispose();
          stream.removeListener(listener);
        });
      },
      onError: (error, _) {
        _log('popup image $url — $error');
        if (!loaded.isCompleted) loaded.complete(null);
      },
    );
    stream.addListener(listener);
    final size = await loaded.future.timeout(
      const Duration(seconds: 10),
      onTimeout: () {
        _log('popup image $url — timed out');
        return null;
      },
    );
    if (size == null || size.isEmpty) return null;
    return (image: image, aspect: size.width / size.height);
  }

  /// Width to height of the picture on top of a modal popup: the picture's own, so it
  /// shows whole, but no wider than 2:1, no taller than 4:5, and no taller than 45% of
  /// the height the popup has.
  @visibleForTesting
  static double imageAspect(
    double own, {
    required double width,
    required double availableHeight,
  }) {
    const widest = 2.0;
    const tallest = 0.8;
    final byScreen = width / (availableHeight * 0.45);
    final lowest = math.min(widest, math.max(tallest, byScreen));
    return own.clamp(lowest, widest);
  }

  _PopupRoute _route(
    InAppPopup popup,
    _Picture? picture,
    BuildContext navigatorContext,
  ) {
    final fullscreen = popup.position == InAppPopupPosition.unknown;
    final buttons =
        (popup.actionText ?? '').isNotEmpty ||
        (popup.closeText ?? '').isNotEmpty;
    late final _PopupRoute route;

    void close() {
      final navigator = route.navigator;
      if (navigator == null || !route.isActive) return;
      if (route.isCurrent) {
        navigator.pop();
      } else {
        navigator.removeRoute(route);
      }
    }

    void action() {
      close();
      if (popup.pushSubscribeText != null) {
        _run('notification settings', _openNotificationSettings);
      } else if (popup.linkUrl != null) {
        _run('link ${popup.linkUrl}', () => _openUrl(popup.linkUrl!));
      }
    }

    route = _PopupRoute(
      // A tap past the popup closes it only when it has no buttons, as on iOS.
      barrierDismissible: !fullscreen && !buttons,
      // Material wording when the app has it; CupertinoApp and WidgetsApp do not, and
      // MaterialLocalizations.of would throw there.
      barrierLabel:
          Localizations.of<MaterialLocalizations>(
            navigatorContext,
            MaterialLocalizations,
          )?.modalBarrierDismissLabel ??
          'Dismiss',
      barrierColor: fullscreen ? Colors.transparent : const Color(0x80000000),
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (context, _, _) => _PopupPage(
        popup: popup,
        picture: picture,
        onAction: action,
        onClose: close,
      ),
      transitionBuilder: (context, animation, _, child) =>
          _transition(popup.position, animation, child),
    );
    return route;
  }

  static Widget _transition(
    InAppPopupPosition position,
    Animation<double> animation,
    Widget child,
  ) {
    final curved = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    final faded = FadeTransition(opacity: curved, child: child);
    Widget slide(double from) => SlideTransition(
      position: Tween<Offset>(
        begin: Offset(0, from),
        end: Offset.zero,
      ).animate(curved),
      child: faded,
    );
    return switch (position) {
      InAppPopupPosition.center => ScaleTransition(
        scale: Tween<double>(begin: 0.95, end: 1).animate(curved),
        child: faded,
      ),
      InAppPopupPosition.top => slide(-0.1),
      InAppPopupPosition.bottom => slide(0.1),
      InAppPopupPosition.unknown => slide(0.04),
    };
  }

  /// Runs a platform call nobody waits for; a failure is logged instead of escaping as an
  /// uncaught error, which crash reporters count as a crash.
  static void _run(String what, Future<Object?> Function() call) {
    unawaited(
      Future<Object?>.sync(
        call,
      ).then<void>((_) {}, onError: (Object error) => _log('$what — $error')),
    );
  }

  static void _log(String message) =>
      debugPrint('PersonalizationPopup: $message');
}

/// The dialog route a popup is shown in. [gone] completes when the popup leaves the
/// screen for any reason: closed, removed, or dropped with its navigator.
class _PopupRoute extends RawDialogRoute<void> {
  _PopupRoute({
    required super.pageBuilder,
    super.barrierDismissible,
    super.barrierColor,
    super.barrierLabel,
    super.transitionDuration,
    super.transitionBuilder,
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

typedef _Picture = ({ImageProvider image, double aspect});

class _Request {
  _Request(this.popup);

  final InAppPopup popup;
  final Completer<void> done = Completer<void>();
}

/// The popup as the server described it: centred, at the top or at the bottom with a
/// 16 margin, or fullscreen when the position is unknown.
class _PopupPage extends StatelessWidget {
  const _PopupPage({
    required this.popup,
    required this.picture,
    required this.onAction,
    required this.onClose,
  });

  final InAppPopup popup;
  final _Picture? picture;
  final VoidCallback onAction;
  final VoidCallback onClose;

  static const double _margin = 16;
  static const double _maxWidth = 370;

  @override
  Widget build(BuildContext context) {
    final fullscreen = popup.position == InAppPopupPosition.unknown;
    final size = MediaQuery.sizeOf(context);
    final padding = MediaQuery.paddingOf(context);
    final width = math.min(_maxWidth, size.width - 2 * _margin);
    final picture = this.picture;
    final card = PersonalizationInAppPopup(
      view: picture == null
          ? PersonalizationInAppPopupView.text
          : PersonalizationInAppPopupView.image,
      presentation: fullscreen
          ? PersonalizationInAppPopupPresentation.fullscreen
          : PersonalizationInAppPopupPresentation.modal,
      title: popup.title,
      text: popup.text,
      actionText: popup.actionText,
      closeText: popup.closeText,
      image: picture?.image,
      imageAspectRatio: picture == null
          ? null
          : PopupPresenter.imageAspect(
              picture.aspect,
              width: width,
              availableHeight: size.height - padding.vertical - 2 * _margin,
            ),
      onAction: onAction,
      onClose: onClose,
    );

    // The kit sets its own text styles; the transparent material only keeps the app's
    // error text style (the yellow underline) from leaking into them.
    if (fullscreen) {
      // The status bar lies on the card (the picture starts below it), so its icons
      // follow the popup's brightness.
      final light =
          PersonalizationTheme.brightnessOf(context) == Brightness.dark;
      return AnnotatedRegion<SystemUiOverlayStyle>(
        value: light ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
        child: Material(type: MaterialType.transparency, child: card),
      );
    }

    return Padding(
      padding: padding + const EdgeInsets.all(_margin),
      child: Align(
        alignment: switch (popup.position) {
          InAppPopupPosition.top => Alignment.topCenter,
          InAppPopupPosition.bottom => Alignment.bottomCenter,
          _ => Alignment.center,
        },
        child: SizedBox(
          width: width,
          // Taller than the screen only with a very long text; it scrolls then. No clip:
          // it would cut the popup's shadow.
          child: SingleChildScrollView(
            clipBehavior: Clip.none,
            child: Material(type: MaterialType.transparency, child: card),
          ),
        ),
      ),
    );
  }
}
