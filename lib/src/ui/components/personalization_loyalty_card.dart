import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../personalization_elevation.dart';
import '../personalization_icons.dart';
import '../personalization_spacing.dart';
import '../personalization_theme.dart';
import 'personalization_barcode.dart';
import 'personalization_code128.dart';

/// Поле блока Info карты лояльности: подпись и значение.
@immutable
class PersonalizationLoyaltyCardField {
  const PersonalizationLoyaltyCardField({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;
}

/// Карта лояльности в духе Apple Wallet.
///
/// Источник: Figma Mobile SDK UI Kit, страница Loyalty (1:34), фреймы
/// Wallet/iOS/Light Theme (570:9879) и Wallet/iOS/Dark Theme (570:10131);
/// компонент Wallet (570:9111) на странице Components, секция Card. Части:
/// Header, Wallet/Logo (570:9034), набор полей Wallet (559:8973), Wallet/Stripe
/// (520:8923), Wallet/Stamps (570:10384), Wallet/Info (570:9081), Wallet/Code
/// (520:8886).
///
/// С данными SDK не связана: getLoyaltyStatus отдаёт только участие и уровень —
/// ни баланса, ни штампов, ни номера карты в нём нет. Всё содержимое даёт хост,
/// кит только раскладывает. Форма вступления из описания страницы в макете не
/// нарисована — её здесь нет.
///
/// Ширина — ширина родителя, минимальная высота — пропорция пасса 370×560;
/// содержимое выше — карта растёт. Разделы идут стопкой без зазоров, пустой
/// раздел пропадает целиком:
/// - Header — логотип в начале, баланс (подпись и значение) в конце строки;
/// - Stripe — полоса высотой в ширину / 2.6 (strip Apple 375×144): картинка,
///   затемнение 30%, эмблема уровня и штампы;
/// - Info — поля [fields] поровну по ширине;
/// - Code — штрихкод [code] на белой подложке, забирает остаток высоты и
///   прижат к низу по центру.
///
/// Скругление 2XL, обводка 1 внутрь цветом Line/Generic Subtle, тень Elevation 3
/// цветом Shadow/Heavy темы. Фон — Background/Card, подписи и значения —
/// Text/Primary; оба переопределяются через [cardColor] и [contentColor]. Так в
/// тёмном примере макета карта фирменная синяя — Semantic/Info
/// ([PersonalizationColors.semanticInfo]), цвет передаёт хост.
class PersonalizationLoyaltyCard extends StatelessWidget {
  const PersonalizationLoyaltyCard({
    super.key,
    this.logo,
    this.balanceLabel,
    this.balanceValue,
    this.stripe,
    this.emblem,
    this.stamps = 0,
    this.stampsTotal = 0,
    this.fields = const <PersonalizationLoyaltyCardField>[],
    this.code,
    this.cardColor,
    this.contentColor,
    this.iconBuilder,
  });

  /// Логотип хоста. Кит задаёт ему высоту 33, ширину картинка берёт по своей
  /// пропорции. Виджет, а не [ImageProvider]: логотип кит не перекрашивает —
  /// хочет хост цвет текста, он красит его сам (`Image(color: ...)`). Карта
  /// меряет содержимое через IntrinsicHeight, поэтому LayoutBuilder в логотипе
  /// не годится; Image и SvgPicture подходят.
  final Widget? logo;

  /// Подпись баланса — в макете «Бонусы»; выводится прописными.
  final String? balanceLabel;

  /// Баланс уже отформатированным — в макете «50 550».
  final String? balanceValue;

  /// Картинка полосы, заполняет её с обрезкой по краям. Картинки даёт хост —
  /// кит не тянет сеть.
  final ImageProvider? stripe;

  /// Эмблема уровня поверх полосы, у правого края, частично за её границей.
  final ImageProvider? emblem;

  /// Сколько штампов собрано. Приводится к 0…[stampsTotal].
  final int stamps;

  /// Сколько мест под штампы. 0 — ряда штампов нет.
  final int stampsTotal;

  /// Поля блока Info по порядку — в макете «Владелец» и «Уровень». Тумблер
  /// Show Owner макета — просто поле, которое хост не передал.
  final List<PersonalizationLoyaltyCardField> fields;

  /// Номер карты для штрихкода Code 128. Пусто или не кодируется — раздела
  /// нет, минимальная высота карты остаётся.
  final String? code;

  /// Фон карты. `null` — Background/Card.
  final Color? cardColor;

  /// Цвет подписей и значений. `null` — Text/Primary.
  final Color? contentColor;

  /// Как нарисовать иконку штампа ([PersonalizationIcons.checkRosetteFill],
  /// [PersonalizationIcons.rosette]) заданного размера и цвета. Не задан —
  /// кит рисует штампы сам по контуру тех же иконок.
  final Widget Function(
    BuildContext context,
    String asset,
    double size,
    Color color,
  )?
  iconBuilder;

  /// Пропорция пасса в макете.
  static const double _designWidth = 370;
  static const double _designHeight = 560;

  /// Wallet/Logo.
  static const double _logoHeight = 33;

  /// Strip Apple Wallet — 375×144; в макете 368×141.5.
  static const double _stripeRatio = 2.6;

  static const double _stampSize = 32;

  bool get _hasBalance =>
      (balanceLabel ?? '').isNotEmpty || (balanceValue ?? '').isNotEmpty;

  int get _total => math.max(0, stampsTotal);

  bool get _hasCode =>
      code != null && PersonalizationCode128.values(code!) != null;

  @override
  Widget build(BuildContext context) {
    final theme = PersonalizationTheme.of(context);
    final colors = theme.colors;
    final surface = cardColor ?? colors.backgroundCard;
    final radius = BorderRadius.circular(theme.radius.xl2);

    return LayoutBuilder(
      builder: (context, constraints) {
        // Без ограничения по ширине (горизонтальная прокрутка) — ширина макета.
        final width = constraints.hasBoundedWidth
            ? constraints.maxWidth
            : _designWidth;

        final sections = <Widget>[
          if (logo != null || _hasBalance) _header(context),
          if (stripe != null || emblem != null || _total > 0)
            _stripe(context, width / _stripeRatio),
          if (fields.isNotEmpty) _info(context),
          if (_hasCode) Expanded(child: _code(context)),
        ];

        // Тень снаружи карты, поэтому она на обёртке, а не под ClipRRect —
        // обрезка срезала бы её. Обводка поверх содержимого, внутри скругления:
        // полоса во всю ширину её не перекрывает.
        return SizedBox(
          width: width,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: radius,
              boxShadow: <BoxShadow>[
                for (final shadow in PersonalizationElevation.e3)
                  shadow.copyWith(color: colors.shadowHeavy),
              ],
            ),
            child: ClipRRect(
              borderRadius: radius,
              child: DecoratedBox(
                position: DecorationPosition.foreground,
                decoration: BoxDecoration(
                  borderRadius: radius,
                  border: Border.all(color: colors.lineGenericSubtle),
                ),
                child: ColoredBox(
                  color: surface,
                  // Высота — наибольшая из пропорции и содержимого.
                  // IntrinsicHeight меряет содержимое и в прокрутке без
                  // ограничения по высоте, где Expanded раздела Code иначе
                  // было бы нечего делить.
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: width * _designHeight / _designWidth,
                    ),
                    child: IntrinsicHeight(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: sections,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // Подпись поля и баланса: 11/14, SemiBold, +0.04 em, прописными.
  TextStyle _labelStyle(BuildContext context) => _style(
    context,
    fontSize: 11,
    lineHeight: 14,
    weight: FontWeight.w600,
    letterSpacingEm: 0.04,
  );

  // Трекинг в макете в долях кегля, TextStyle ждёт логические пиксели.
  TextStyle _style(
    BuildContext context, {
    required double fontSize,
    required double lineHeight,
    FontWeight weight = FontWeight.w400,
    double letterSpacingEm = 0,
  }) {
    final theme = PersonalizationTheme.of(context);
    return TextStyle(
      fontSize: fontSize,
      height: lineHeight / fontSize,
      fontWeight: weight,
      letterSpacing: fontSize * letterSpacingEm,
      fontFamily: theme.fontFamily.familyFor(weight),
      package: theme.fontFamily.package,
      color: contentColor ?? theme.colors.textPrimary,
    );
  }

  Widget _header(BuildContext context) {
    final label = balanceLabel ?? '';
    final value = balanceValue ?? '';
    return Padding(
      padding: const EdgeInsets.all(PersonalizationSpacing.xl),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          if (logo != null) SizedBox(height: _logoHeight, child: logo),
          if (logo != null && _hasBalance)
            const SizedBox(width: PersonalizationSpacing.xl),
          if (_hasBalance)
            Expanded(
              // Строки баланса однострочные: IntrinsicHeight меряет шапку по
              // собственной ширине картинки логотипа, а не по ширине при
              // высоте 33, и перенос по такой ширине раздул бы шапку.
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  if (label.isNotEmpty)
                    Text(
                      label.toUpperCase(),
                      textAlign: TextAlign.end,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _labelStyle(context),
                    ),
                  if (value.isNotEmpty)
                    Text(
                      value,
                      textAlign: TextAlign.end,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _style(
                        context,
                        fontSize: 24,
                        lineHeight: 24,
                        letterSpacingEm: -0.05,
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _stripe(BuildContext context, double height) {
    final colors = PersonalizationTheme.of(context).colors;
    final filled = stamps.clamp(0, _total);
    return SizedBox(
      height: height,
      child: Stack(
        fit: StackFit.expand,
        // Эмблема выходит за полосу — полоса её обрезает.
        clipBehavior: Clip.hardEdge,
        children: <Widget>[
          // Чёрная подложка, а не токен: полоса в макете в тёмном режиме в
          // любой теме, и пока картинка не загрузилась, под затемнением чёрное.
          const ColoredBox(color: Color(0xFF000000)),
          if (stripe != null) Image(image: stripe!, fit: BoxFit.cover),
          // Затемнение 30%, чтобы штампы читались на любой картинке.
          const ColoredBox(color: Color(0x4D000000)),
          if (emblem != null)
            // Геометрия из макета: эмблема 179.5×205.8 в точке (212.5, −16.5)
            // полосы 368×141.5 — всё в долях высоты полосы.
            PositionedDirectional(
              top: -0.1166 * height,
              end: -0.17 * height,
              height: 1.4545 * height,
              child: Image(image: emblem!, fit: BoxFit.contain),
            ),
          if (_total > 0)
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: PersonalizationSpacing.xl,
                ),
                // Больше штампов, чем влезает в ширину, — ряд ужимается, а не
                // вылезает за карту. В макете их до пяти.
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: AlignmentDirectional.centerStart,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      for (int i = 0; i < _total; i++) ...<Widget>[
                        if (i > 0)
                          const SizedBox(width: PersonalizationSpacing.md),
                        // Полоса в макете всегда в тёмном режиме, поэтому
                        // штампы — постоянные светлые токены, а не текстовые
                        // цвета темы.
                        _stamp(
                          context,
                          filled: i < filled,
                          color: i < filled
                              ? colors.textLightSecondary
                              : colors.textLightHint,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _stamp(
    BuildContext context, {
    required bool filled,
    required Color color,
  }) {
    final asset = filled
        ? PersonalizationIcons.checkRosetteFill
        : PersonalizationIcons.rosette;
    return SizedBox(
      width: _stampSize,
      height: _stampSize,
      child:
          iconBuilder?.call(context, asset, _stampSize, color) ??
          CustomPaint(
            painter: _StampPainter(filled: filled, color: color),
          ),
    );
  }

  Widget _info(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(PersonalizationSpacing.xl),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          for (int i = 0; i < fields.length; i++) ...<Widget>[
            if (i > 0) const SizedBox(width: PersonalizationSpacing.gapModal),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    fields[i].label.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _labelStyle(context),
                  ),
                  Text(
                    fields[i].value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _style(
                      context,
                      fontSize: 28,
                      lineHeight: 32,
                      letterSpacingEm: -0.05,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _code(BuildContext context) {
    final theme = PersonalizationTheme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        PersonalizationSpacing.xl,
        PersonalizationSpacing.xl3,
        PersonalizationSpacing.xl,
        PersonalizationSpacing.xl3,
      ),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: DecoratedBox(
          decoration: BoxDecoration(
            // Белый Brand/White, а не токен фона: сканеру нужна белая подложка
            // в обеих темах.
            color: const Color(0xFFFFFFFF),
            borderRadius: BorderRadius.circular(theme.radius.lg),
            border: Border.all(color: theme.colors.lineGenericSubtle),
          ),
          child: Padding(
            padding: const EdgeInsets.all(PersonalizationSpacing.xl2),
            child: PersonalizationBarcode(code: code!),
          ),
        ),
      ),
    );
  }
}

/// Штамп без [PersonalizationLoyaltyCard.iconBuilder]: те же контуры, что в
/// ассетах check-rosette-fill.svg и rosette.svg, — пакет не рисует SVG сам.
class _StampPainter extends CustomPainter {
  const _StampPainter({required this.filled, required this.color});

  final bool filled;
  final Color color;

  static final Path _checkRosetteFill = _svgPath(_checkRosetteFillData);
  static final Path _rosette = _svgPath(_rosetteData);

  @override
  void paint(Canvas canvas, Size size) {
    canvas
      ..save()
      ..scale(size.width / 32, size.height / 32)
      ..drawPath(filled ? _checkRosetteFill : _rosette, Paint()..color = color)
      ..restore();
  }

  @override
  bool shouldRepaint(_StampPainter oldDelegate) =>
      oldDelegate.filled != filled || oldDelegate.color != color;
}

/// Контур из атрибута `d`: Figma экспортирует эти иконки абсолютными M, L, C и
/// Z. Сдвиг 0.6281 — из атрибута transform: контур 30.74 в рамке 32. Заливка
/// even-odd — так дырки (галочка, внутренний контур) вырезаются при любом
/// направлении обхода.
Path _svgPath(String data) {
  final tokens = RegExp(
    r'[MLCZ]|-?\d*\.?\d+',
  ).allMatches(data).map((match) => match[0]!).toList();
  final path = Path()..fillType = PathFillType.evenOdd;
  String command = 'M';
  int i = 0;
  double next() => double.parse(tokens[i++]);
  while (i < tokens.length) {
    switch (tokens[i]) {
      case 'M' || 'L' || 'C':
        command = tokens[i++];
      case 'Z':
        path.close();
        i++;
      default:
        switch (command) {
          case 'M':
            path.moveTo(next(), next());
            // Следующие пары после M — неявные L.
            command = 'L';
          case 'L':
            path.lineTo(next(), next());
          case 'C':
            path.cubicTo(next(), next(), next(), next(), next(), next());
        }
    }
  }
  return path.shift(const Offset(0.6281, 0.6281));
}

const String _checkRosetteFillData =
    'M13.4256 0.716651C14.5469 -0.238881 16.1969 -0.238887 17.3182 0.716651'
    'L20.12 3.10435C20.2801 3.24076 20.4796 3.32296 20.6893 3.3397'
    'L24.3592 3.63267C25.8276 3.74997 26.9939 4.91624 27.1112 6.38462'
    'L27.4042 10.0545C27.4209 10.2642 27.503 10.4638 27.6395 10.6239'
    'L30.0272 13.4256C30.9826 14.5469 30.9827 16.197 30.0272 17.3182'
    'L27.6395 20.12C27.503 20.2801 27.4209 20.4795 27.4042 20.6893'
    'L27.1112 24.3592C26.9939 25.8276 25.8276 26.9939 24.3592 27.1112'
    'L20.6893 27.4042C20.4795 27.4209 20.2801 27.503 20.12 27.6395'
    'L17.3182 30.0272C16.197 30.9827 14.5469 30.9826 13.4256 30.0272'
    'L10.6239 27.6395C10.4638 27.503 10.2642 27.4209 10.0545 27.4042'
    'L6.38462 27.1112C4.91624 26.9939 3.74998 25.8276 3.63267 24.3592'
    'L3.3397 20.6893C3.32296 20.4796 3.24076 20.2801 3.10435 20.12'
    'L0.716651 17.3182C-0.238887 16.1969 -0.23888 14.5469 0.716651 13.4256'
    'L3.10435 10.6239C3.2408 10.4637 3.32294 10.2643 3.3397 10.0545'
    'L3.63267 6.38462C3.74991 4.91619 4.91619 3.74991 6.38462 3.63267'
    'L10.0545 3.3397C10.2643 3.32294 10.4637 3.2408 10.6239 3.10435'
    'L13.4256 0.716651Z'
    'M21.579 11.1649C21.1884 10.7744 20.5554 10.7744 20.1649 11.1649'
    'L13.3719 17.9579L10.579 15.1649'
    'C10.1884 14.7744 9.55542 14.7744 9.16489 15.1649'
    'C8.77437 15.5554 8.77437 16.1884 9.16489 16.579L12.6649 20.079'
    'C13.0554 20.4693 13.6885 20.4694 14.079 20.079L21.579 12.579'
    'C21.9694 12.1885 21.9693 11.5554 21.579 11.1649Z';

const String _rosetteData =
    'M13.4256 0.716656C14.5469 -0.238886 16.1969 -0.238885 17.3182 0.716656'
    'L20.12 3.10435C20.2801 3.24084 20.4795 3.32296 20.6893 3.3397'
    'L24.3592 3.63267C25.8277 3.74991 26.9939 4.91619 27.1112 6.38462'
    'L27.4042 10.0545C27.4209 10.2643 27.503 10.4637 27.6395 10.6239'
    'L30.0272 13.4256C30.9827 14.5469 30.9827 16.1969 30.0272 17.3182'
    'L27.6395 20.12C27.503 20.2801 27.4209 20.4795 27.4042 20.6893'
    'L27.1112 24.3592C26.9939 25.8277 25.8277 26.9939 24.3592 27.1112'
    'L20.6893 27.4042C20.4795 27.4209 20.2801 27.503 20.12 27.6395'
    'L17.3182 30.0272C16.1969 30.9827 14.5469 30.9827 13.4256 30.0272'
    'L10.6239 27.6395C10.4637 27.503 10.2643 27.4209 10.0545 27.4042'
    'L6.38462 27.1112C4.91619 26.9939 3.74991 25.8277 3.63267 24.3592'
    'L3.3397 20.6893C3.32296 20.4795 3.24084 20.2801 3.10435 20.12'
    'L0.716656 17.3182C-0.238886 16.1969 -0.238885 14.5469 0.716656 13.4256'
    'L3.10435 10.6239C3.24084 10.4637 3.32296 10.2643 3.3397 10.0545'
    'L3.63267 6.38462C3.74991 4.91619 4.91619 3.74991 6.38462 3.63267'
    'L10.0545 3.3397C10.2643 3.32296 10.4637 3.24084 10.6239 3.10435'
    'L13.4256 0.716656Z'
    'M16.0204 2.23814C15.6467 1.91997 15.0971 1.91997 14.7235 2.23814'
    'L11.9208 4.62681C11.4403 5.03612 10.8429 5.28364 10.2137 5.33384'
    'L6.5438 5.62681C6.05435 5.66591 5.66591 6.05436 5.62681 6.5438'
    'L5.33384 10.2137C5.28364 10.8429 5.03612 11.4403 4.62681 11.9208'
    'L2.23814 14.7235C1.91997 15.0971 1.91997 15.6467 2.23814 16.0204'
    'L4.62681 18.8231C5.03612 19.3035 5.28364 19.901 5.33384 20.5301'
    'L5.62681 24.2001C5.66591 24.6895 6.05436 25.078 6.5438 25.117'
    'L10.2137 25.41C10.8429 25.4602 11.4403 25.7077 11.9208 26.117'
    'L14.7235 28.5057C15.0971 28.8239 15.6467 28.8239 16.0204 28.5057'
    'L18.8231 26.117C19.3035 25.7077 19.901 25.4602 20.5301 25.41'
    'L24.2001 25.117C24.6895 25.078 25.078 24.6895 25.117 24.2001'
    'L25.41 20.5301C25.4602 19.901 25.7077 19.3035 26.117 18.8231'
    'L28.5057 16.0204C28.8239 15.6467 28.8239 15.0971 28.5057 14.7235'
    'L26.117 11.9208C25.7077 11.4403 25.4602 10.8429 25.41 10.2137'
    'L25.117 6.5438C25.078 6.05435 24.6895 5.66591 24.2001 5.62681'
    'L20.5301 5.33384C19.901 5.28364 19.3035 5.03612 18.8231 4.62681'
    'L16.0204 2.23814Z';
