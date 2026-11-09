import 'package:flutter/material.dart';
import 'package:rees46_sdk/rees46_sdk.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../shop/shop.dart';

/// The built-in game: tic-tac-toe against the computer as one web page (HTML, CSS and
/// JS, no network) — the same file in every demo.
const String demoGameAsset = 'assets/game/tic-tac-toe.html';

/// The demo's mini-game, full screen over the screen the game's link was opened from
/// (see `openDemoGameLink`): a panel with the title and the cross, the game's web page
/// under it. The page is the whole game, "Ещё раз" included; the cross and system back
/// close the screen. The page gets the app's theme through its `setGameTheme`, and
/// stays covered with the kit's background until it has it, so nothing flashes white.
class DemoGameScreen extends StatefulWidget {
  const DemoGameScreen({super.key, this.url});

  /// A game of the app's own from its server (`https`); `null` — the built-in one,
  /// [demoGameAsset].
  final Uri? url;

  static const String title = 'Крестики-нолики';

  @override
  State<DemoGameScreen> createState() => _DemoGameScreenState();
}

class _DemoGameScreenState extends State<DemoGameScreen> {
  late final WebViewController _page;

  /// The page has loaded and has the theme: the cover goes.
  bool _shown = false;

  /// The theme the page has, and the background the view was given.
  Brightness? _pageTheme;
  Color? _background;

  @override
  void initState() {
    super.initState();
    _page = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) => _loaded(),
          onWebResourceError: (error) {
            if (error.isForMainFrame ?? true) _loaded();
          },
        ),
      );
    final url = widget.url;
    if (url == null) {
      _page.loadFlutterAsset(demoGameAsset);
    } else {
      _page.loadRequest(url);
    }
  }

  /// A new document knows no theme yet: it gets the app's, then shows.
  Future<void> _loaded() async {
    _pageTheme = null;
    if (!mounted) return;
    await _giveTheme(PersonalizationTheme.brightnessOf(context));
    if (mounted && !_shown) setState(() => _shown = true);
  }

  Future<void> _giveTheme(Brightness brightness) async {
    if (_pageTheme == brightness) return;
    _pageTheme = brightness;
    final theme = brightness == Brightness.dark ? 'dark' : 'light';
    try {
      // A page of another game may have no such function.
      await _page.runJavaScript(
        "window.setGameTheme && window.setGameTheme('$theme')",
      );
    } catch (error) {
      debugPrint('Demo game: theme not set — $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = PersonalizationTheme.of(context).colors;
    final safe = MediaQuery.paddingOf(context);
    // The app's theme may change while the game is open.
    if (_background != colors.backgroundGeneric) {
      _background = colors.backgroundGeneric;
      _page.setBackgroundColor(colors.backgroundGeneric);
    }
    if (_shown) _giveTheme(PersonalizationTheme.brightnessOf(context));
    return ShopScaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              PersonalizationSpacing.paddingX,
              safe.top + PersonalizationSpacing.md,
              PersonalizationSpacing.paddingX,
              PersonalizationSpacing.md,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    DemoGameScreen.title,
                    style: shopTextStyle(
                      context,
                      PersonalizationTypography.xlEmphasized,
                      colors.textPrimary,
                    ),
                  ),
                ),
                ShopRoundButton(
                  icon: PersonalizationIcons.cross,
                  label: 'Закрыть',
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
              ],
            ),
          ),
          // The page keeps clear of the home indicator.
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: safe.bottom),
              child: Stack(
                children: [
                  Positioned.fill(child: WebViewWidget(controller: _page)),
                  if (!_shown)
                    Positioned.fill(
                      child: ColoredBox(
                        color: colors.backgroundGeneric,
                        child: const Center(child: PersonalizationLoader()),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
