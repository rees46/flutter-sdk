import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../personalization_icons.dart';
import '../personalization_theme.dart';
import 'personalization_toast.dart';

/// Вид блока цены сторис.
///
/// В макете есть ещё Installment (рассрочка), но в данных сторис её нет — не собран.
enum PersonalizationStoryPriceType {
  /// Только цена (и старая цена, если есть).
  price,

  /// Цена и справа скидка на Brand/Primary.
  discount,

  /// Цена и справа промокод на чёрном; нажатие копирует код.
  promoCode,
}

/// Блок цены на слайде с товаром.
///
/// Источник: Figma Mobile SDK UI Kit, страница Stories (1:32), компонент
/// Card/Story/Price — виды Price, Discount и Promo code.
///
/// Коробка со скруглением 12 и заливкой #F2F2F2 95% — в макете сырой цвет, не
/// переменная, и он одинаков в обеих темах, поэтому текст на ней всегда тёмный
/// (Text/Dark). Левая колонка с полями 12/16: старая цена (если есть) с прозрачностью
/// 50% — сумма SemiBold 14 зачёркнутая и валюта Regular 14/16 цвета Text/Dark Secondary;
/// под ней цена — сумма SemiBold 24 и валюта Regular 14/16 с шагом 4 по базовой линии,
/// Text/Dark Primary. Валюту от суммы отделяет [splitCurrency].
///
/// Справа, по [type]:
/// - discount — блок Brand/Primary с полями 0/16, скидка SemiBold 36 Text/Light Primary;
///   левая колонка забирает остаток;
/// - promoCode — чёрный блок (Text/Dark Primary) с полями 12/16: подпись SemiBold 14
///   Text/Light Secondary и код SemiBold 24 Text/Light Primary по центру, иконка copy 24
///   (глиф 20) Text/Light Hint в правом верхнем углу с отступом 4. Колонки делят ширину
///   поровну, длинный код забирает сколько нужно. Нажатие слегка увеличивает блок (как
///   Tap Zoom Effect макета), копирует код в буфер, показывает тост [copiedText] и
///   зовёт [onPromoCopied].
class PersonalizationStoryPrice extends StatefulWidget {
  const PersonalizationStoryPrice({
    super.key,
    this.type = PersonalizationStoryPriceType.price,
    required this.price,
    this.oldPrice,
    this.discount,
    this.promoCode,
    this.promoCodeCaption = 'Promo code',
    this.copiedText = 'Copied',
    this.onPromoCopied,
    this.iconBuilder,
  });

  final PersonalizationStoryPriceType type;

  /// Цена уже отформатированной, с валютой — в макете «1 190 900 ₽».
  final String price;

  /// Старая цена; `null` — не показывать.
  final String? oldPrice;

  /// Скидка для вида discount, например «10%».
  final String? discount;

  /// Код для вида promoCode.
  final String? promoCode;

  /// Подпись над кодом.
  final String promoCodeCaption;

  /// Текст тоста после копирования.
  final String copiedText;

  /// Код скопирован.
  final ValueChanged<String>? onPromoCopied;

  /// Как нарисовать иконку копирования: пакет не рисует SVG сам.
  final Widget Function(
    BuildContext context,
    String asset,
    double size,
    Color color,
  )?
  iconBuilder;

  /// Заливка коробки: #F2F2F2 с прозрачностью 95%.
  static const Color boxColor = Color(0xF2F2F2F2);

  /// Увеличение промокода при нажатии.
  static const double pressedScale = 1.03;

  /// Делит отформатированную цену на сумму и валюту: валюта — нецифровой хвост строки.
  /// `"1 190 900 ₽"` → (`"1 190 900"`, `"₽"`), `"9 999₽"` → (`"9 999"`, `"₽"`). Если
  /// строка кончается цифрой (`"$140"`), валюты нет — вся строка сумма.
  static (String amount, String currency) splitCurrency(String formatted) {
    final text = formatted.trim();
    final match = RegExp(r'^(.*\d)\s*(\D+)$').firstMatch(text);
    if (match == null) return (text, '');
    return (match.group(1)!.trim(), match.group(2)!.trim());
  }

  @override
  State<PersonalizationStoryPrice> createState() =>
      _PersonalizationStoryPriceState();
}

class _PersonalizationStoryPriceState extends State<PersonalizationStoryPrice> {
  bool _pressed = false;

  static const double _radius = 12;

  String get _code => widget.promoCode ?? '';

  bool get _hasSide => switch (widget.type) {
    PersonalizationStoryPriceType.price => false,
    PersonalizationStoryPriceType.discount =>
      (widget.discount ?? '').isNotEmpty,
    PersonalizationStoryPriceType.promoCode => _code.isNotEmpty,
  };

  void _copy() {
    final code = _code;
    Clipboard.setData(ClipboardData(text: code));
    PersonalizationToast.show(context, widget.copiedText);
    widget.onPromoCopied?.call(code);
  }

  TextStyle _style(
    PersonalizationTheme theme,
    double size,
    double lineHeight,
    FontWeight weight,
    Color color,
  ) => TextStyle(
    fontSize: size,
    height: lineHeight / size,
    fontWeight: weight,
    letterSpacing: 0,
    fontFamily: theme.fontFamily.familyFor(weight),
    package: theme.fontFamily.package,
    color: color,
  );

  @override
  Widget build(BuildContext context) {
    final theme = PersonalizationTheme.of(context);
    final colors = theme.colors;
    final side = _hasSide;
    const radius = Radius.circular(_radius);

    final left = DecoratedBox(
      decoration: BoxDecoration(
        color: PersonalizationStoryPrice.boxColor,
        borderRadius: side
            ? const BorderRadius.horizontal(left: radius)
            : const BorderRadius.all(radius),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        child: _prices(theme),
      ),
    );

    if (!side) return left;

    if (widget.type == PersonalizationStoryPriceType.discount) {
      return IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Expanded(child: left),
            DecoratedBox(
              decoration: BoxDecoration(
                color: colors.brandPrimary,
                borderRadius: const BorderRadius.horizontal(right: radius),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Center(
                  child: Text(
                    widget.discount!,
                    maxLines: 1,
                    style: _style(
                      theme,
                      36,
                      44,
                      FontWeight.w600,
                      colors.textLightPrimary,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Промокод: колонки поровну, длинный код забирает сколько нужно — но не больше 70%,
    // чтобы цене осталось место; дальше код ужимается.
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Expanded(child: left),
              ConstrainedBox(
                constraints: BoxConstraints(
                  minWidth: width / 2,
                  maxWidth: width * 0.7,
                ),
                // Ширина по содержимому в пределах ограничений выше.
                child: IntrinsicWidth(child: _promo(context, theme)),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _prices(PersonalizationTheme theme) {
    final colors = theme.colors;
    final (amount, currency) = PersonalizationStoryPrice.splitCurrency(
      widget.price,
    );
    final old = widget.oldPrice;

    Widget line(Widget amountText, String currencyText, Color color) =>
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: AlignmentDirectional.centerStart,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: <Widget>[
              amountText,
              if (currencyText.isNotEmpty) ...<Widget>[
                const SizedBox(width: 4),
                Text(
                  currencyText,
                  style: _style(theme, 14, 16, FontWeight.w400, color),
                ),
              ],
            ],
          ),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        if ((old ?? '').isNotEmpty)
          Opacity(
            opacity: 0.5,
            child: Builder(
              builder: (context) {
                final (oldAmount, oldCurrency) =
                    PersonalizationStoryPrice.splitCurrency(old!);
                return line(
                  Text(
                    oldAmount,
                    style: _style(
                      theme,
                      14,
                      16,
                      FontWeight.w600,
                      colors.textDarkSecondary,
                    ).copyWith(decoration: TextDecoration.lineThrough),
                  ),
                  oldCurrency,
                  colors.textDarkSecondary,
                );
              },
            ),
          ),
        line(
          Text(
            amount,
            style: _style(
              theme,
              24,
              28,
              FontWeight.w600,
              colors.textDarkPrimary,
            ),
          ),
          currency,
          colors.textDarkPrimary,
        ),
      ],
    );
  }

  Widget _promo(BuildContext context, PersonalizationTheme theme) {
    final colors = theme.colors;
    final block = DecoratedBox(
      decoration: BoxDecoration(
        color: colors.textDarkPrimary,
        borderRadius: const BorderRadius.horizontal(
          right: Radius.circular(_radius),
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Text(
                  widget.promoCodeCaption,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: _style(
                    theme,
                    14,
                    20,
                    FontWeight.w600,
                    colors.textLightSecondary,
                  ),
                ),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    _code,
                    maxLines: 1,
                    style: _style(
                      theme,
                      24,
                      28,
                      FontWeight.w600,
                      colors.textLightPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            top: 4,
            right: 4,
            child: SizedBox.square(
              dimension: 24,
              child: widget.iconBuilder?.call(
                context,
                PersonalizationIcons.copy,
                24,
                colors.textLightHint,
              ),
            ),
          ),
        ],
      ),
    );

    return Semantics(
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        onTap: _copy,
        child: AnimatedScale(
          scale: _pressed ? PersonalizationStoryPrice.pressedScale : 1,
          duration: const Duration(milliseconds: 120),
          child: block,
        ),
      ),
    );
  }
}
