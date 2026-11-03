import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import '../../popups_v3/popup_v3.dart';
import '../../popups_v3/popup_v3_values.dart';
import 'css_color.dart';
import 'popup_markup.dart';

/// Выравнивание по горизонтали.
enum PopupV3Align { left, center, right }

/// Выравнивание по вертикали.
enum PopupV3VerticalAlign { top, center, bottom }

PopupV3Align? _align(Object? value) => switch (value) {
  'left' => PopupV3Align.left,
  'center' => PopupV3Align.center,
  'right' => PopupV3Align.right,
  _ => null,
};

PopupV3VerticalAlign? _verticalAlign(Object? value) => switch (value) {
  'top' => PopupV3VerticalAlign.top,
  'center' => PopupV3VerticalAlign.center,
  'bottom' => PopupV3VerticalAlign.bottom,
  _ => null,
};

/// Переменные дизайна: статические из `design.variables` и витринные, которые SDK
/// подставляет при показе (`promo_code`). Неизвестный ключ остаётся токеном.
class PopupV3Variables {
  PopupV3Variables({
    Map<String, String> statics = const <String, String>{},
    Map<String, String> runtime = const <String, String>{},
    this.platform,
  }) : statics = <String, String>{
         for (final entry in statics.entries)
           if (!runtimeKeys.contains(entry.key)) entry.key: entry.value,
       },
       runtime = Map<String, String>.unmodifiable(runtime);

  /// Из `design.variables`: объект или старый массив `{key, value}`.
  factory PopupV3Variables.fromDesign(
    Object? raw, {
    Map<String, String> runtime = const <String, String>{},
    TargetPlatform? platform,
  }) {
    final statics = <String, String>{};
    if (raw is Map) {
      raw.forEach((key, value) => statics['$key'] = cssString(value));
    } else if (raw is List) {
      for (final item in raw) {
        if (item is! Map) continue;
        final key = cssPresent(item['key']);
        if (key != null) statics[key] = cssString(item['value']);
      }
    }
    return PopupV3Variables(
      statics: statics,
      runtime: runtime,
      platform: platform,
    );
  }

  /// Витринные переменные: их значения не из дизайна, а от SDK при показе.
  static const List<String> runtimeKeys = <String>[
    'promo_code',
    'coupon_code',
    'campaign_end',
    'remaining',
    'progress',
    'cart_total',
    'wheel_prize',
  ];

  static final RegExp token = RegExp(r'\{\{\s*([a-zA-Z0-9_]+)\s*\}\}');

  final Map<String, String> statics;
  final Map<String, String> runtime;

  /// Платформа ссылок: `{{key}}` ссылки берёт сначала `key_ios` / `key_android`.
  final TargetPlatform? platform;

  /// Статические переменные — до разбора разметки.
  String applyStatic(String text) => text.replaceAllMapped(
    token,
    (match) => statics[match.group(1)!] ?? match.group(0)!,
  );

  /// Витринные переменные.
  String applyRuntime(String text) => text.replaceAllMapped(
    token,
    (match) => runtime[match.group(1)!] ?? match.group(0)!,
  );

  /// Все переменные — в плейсхолдерах, адресах картинок и копируемом тексте.
  String apply(String text) => applyRuntime(applyStatic(text));

  /// Ссылка: для `{{key}}` сначала `key_ios` / `key_android` этой платформы, потом
  /// `key`; витринные — как везде.
  String applyLink(String text) {
    final suffix = switch (platform ?? defaultTargetPlatform) {
      TargetPlatform.iOS => 'ios',
      TargetPlatform.android => 'android',
      _ => null,
    };
    final linked = text.replaceAllMapped(token, (match) {
      final key = match.group(1)!;
      return (suffix == null ? null : statics['${key}_$suffix']) ??
          statics[key] ??
          match.group(0)!;
    });
    return applyRuntime(linked);
  }

  /// Текст с разметкой: статические переменные, разбор, витринные — в готовые куски
  /// (их значения разметкой не становятся).
  List<PopupMarkupSpan> rich(String? text) {
    if (text == null || text.isEmpty) return const <PopupMarkupSpan>[];
    return <PopupMarkupSpan>[
      for (final span in parsePopupMarkup(applyStatic(text)))
        span.withText(applyRuntime(span.text)),
    ];
  }
}

/// Тень элемента.
typedef PopupV3Shadow = ({double y, double blur, Color color});

/// «Коробка» элемента — общие стили обёртки, как `Context#box_declarations`.
class PopupV3Box {
  const PopupV3Box({
    required this.background,
    required this.textColor,
    required this.borderWidth,
    required this.borderColor,
    required this.radius,
    required this.paddingX,
    required this.paddingY,
    required this.fontFamily,
    required this.fontSize,
    required this.fontWeight,
    required this.letterSpacing,
    required this.lineHeight,
    required this.opacity,
    required this.shadow,
  });

  final Color background;
  final Color textColor;
  final double borderWidth;
  final Color borderColor;
  final double radius;
  final double paddingX;
  final double paddingY;

  /// `fontFamily` дизайна как есть; `null` — шрифт приложения.
  final String? fontFamily;
  final double fontSize;
  final double fontWeight;
  final double letterSpacing;

  /// Множитель высоты строки.
  final double lineHeight;
  final double opacity;

  /// `null` — без тени (нулевые смещение и размытие).
  final PopupV3Shadow? shadow;
}

/// Значения по умолчанию нового элемента в редакторе (`DEFAULTS` компилятора): их берём,
/// когда в документе ключа нет. Ключи поведения (`emailLayout`, `emailConsentFields`,
/// `formFields`, `formConsentFields`) сюда не входят: без них компилятор рисует по-своему,
/// и мы так же.
const Map<String, Map<String, Object>> popupV3ElementDefaults =
    <String, Map<String, Object>>{
      'text': <String, Object>{
        'fontSize': 16,
        'bgColor': 'transparent',
        'messageAlign': 'left',
      },
      'box': <String, Object>{
        'bgColor': '#f8fafc',
        'borderRadius': 12,
        'paddingX': 16,
        'paddingY': 16,
      },
      'button': <String, Object>{
        'buttonAction': 'link',
        'buttonAlign': 'center',
        'buttonBgColor': '#2563eb',
        'buttonTextColor': '#ffffff',
        'buttonFontSize': 14,
        'buttonPaddingX': 20,
        'buttonPaddingY': 10,
        'buttonRadius': 10,
      },
      'close': <String, Object>{
        'closeIconMode': 'text',
        'buttonAlign': 'right',
        'buttonBgColor': 'transparent',
        'buttonTextColor': '#71717a',
        'buttonFontSize': 22,
        'buttonPaddingX': 8,
        'buttonPaddingY': 2,
        'buttonRadius': 999,
      },
      'image': <String, Object>{
        'bgColor': 'transparent',
        'imageHeightMode': 'auto',
        'imageObjectFit': 'cover',
        'imageRadius': 8,
      },
      'emailCollector': <String, Object>{
        'borderRadius': 12,
        'buttonBgColor': '#2563eb',
        'buttonTextColor': '#ffffff',
      },
      'form': <String, Object>{
        'borderRadius': 12,
        'buttonBgColor': '#2563eb',
        'buttonTextColor': '#ffffff',
      },
      'promoCode': <String, Object>{
        'promoSource': 'personal',
        'promoShowCopy': true,
        'promoCodeBg': '#fef3c7',
        'promoCodeColor': '#92400e',
        'promoCodeRadius': 10,
        'promoCodeFontSize': 20,
        'messageAlign': 'center',
        'bgColor': 'transparent',
      },
      'survey': <String, Object>{
        'surveyType': 'nps',
        'surveyScaleBg': '#f3f4f6',
        'surveyScaleColor': '#111827',
        'surveyScaleActiveBg': '#2563eb',
        'surveyScaleActiveColor': '#ffffff',
        'buttonBgColor': '#2563eb',
        'buttonTextColor': '#ffffff',
      },
      'recommendation': <String, Object>{'bgColor': 'transparent'},
    };

/// Типы, которые тянутся на всю ширину ячейки (`STRETCH`).
const Set<String> popupV3StretchTypes = <String>{
  'image',
  'emailCollector',
  'form',
  'promoCode',
  'survey',
  'recommendation',
};

/// Типы со ссылкой на всём элементе (`LINKABLE`).
const Set<String> popupV3LinkableTypes = <String>{'text', 'box', 'image'};

/// Флаги подписки на email.
const List<String> popupV3ConsentFields = <String>[
  'email_bulk',
  'email_chain',
  'email_transactional',
];

/// Элемент документа: тип и стиль. Значение ключа — из документа, без него — из
/// [popupV3ElementDefaults] типа; `null` и пустая строка — «нет значения».
class PopupV3Element {
  PopupV3Element({
    required this.id,
    required this.type,
    required Map<String, Object?> style,
  }) : style = Map<String, Object?>.unmodifiable(style),
       defaults = popupV3ElementDefaults[type] ?? const <String, Object>{};

  final String id;
  final String type;
  final Map<String, Object?> style;
  final Map<String, Object> defaults;

  bool get stretch => popupV3StretchTypes.contains(type);

  /// Значение [key]: документ, затем `DEFAULTS` типа.
  Object? value(String key) {
    final own = style[key];
    if (own != null && !(own is String && own.isEmpty)) return own;
    return defaults[key];
  }

  /// Строка с содержимым или `null`.
  String? text(String key) => cssPresent(value(key));

  /// Строка как есть (`to_s`).
  String string(String key) => cssString(value(key));

  double number(String key, double fallback) => cssNum(value(key), fallback);

  /// Цвет [key] или [fallback] (hex).
  Color color(String key, String fallback) =>
      parseCssColor(value(key)) ?? parseCssColor(fallback)!;

  /// Цвет [key] или `null`.
  Color? colorOrNull(String key) => parseCssColor(value(key));

  /// Коробка обёртки по правилам компилятора и переопределениям типа.
  PopupV3Box get box {
    final shadowRaw = value('shadowColor');
    final shadowText = shadowRaw is String ? shadowRaw.trim() : '';
    final shadowParsed = parseCssColor(shadowRaw);
    // Как `Context#shadow_color`: к шестизначному hex (и к запасному #000000)
    // дописывается альфа 55, остальные форматы — как есть.
    final shadowColor =
        shadowParsed == null ||
            RegExp(r'^#[0-9a-fA-F]{6}$').hasMatch(shadowText)
        ? (shadowParsed ?? const Color(0xff000000)).withAlpha(0x55)
        : shadowParsed;
    final shadowY = number('shadowY', 0);
    final shadowBlur = number('shadowBlur', 0);
    var background = color('bgColor', '#ffffff');
    var textColor = color('textColor', '#111827');
    var borderWidth = number('borderWidth', 0);
    var borderColor = color('borderColor', '#d4d4d8');
    var radius = number('borderRadius', 0);
    var paddingX = number('paddingX', 0);
    var paddingY = number('paddingY', 0);
    PopupV3Shadow? shadow = shadowY == 0 && shadowBlur == 0
        ? null
        : (y: shadowY, blur: shadowBlur, color: shadowColor);
    switch (type) {
      case 'button':
      case 'close':
        background = const Color(0x00000000);
        borderWidth = 0;
      case 'emailCollector':
      case 'form':
        textColor = color('textColor', '#0f172a');
        borderColor = color('borderColor', '#e2e8f0');
        radius = number('borderRadius', 12);
        paddingX = number('paddingX', 12);
        paddingY = number('paddingY', 12);
      case 'recommendation':
        background = const Color(0x00000000);
        borderWidth = 0;
        paddingX = 0;
        paddingY = 0;
        shadow = null;
    }
    return PopupV3Box(
      background: background,
      textColor: textColor,
      borderWidth: math.max(0, borderWidth),
      borderColor: borderColor,
      radius: math.max(0, radius),
      paddingX: math.max(0, paddingX),
      paddingY: math.max(0, paddingY),
      fontFamily: text('fontFamily'),
      fontSize: number('fontSize', 12),
      fontWeight: number('fontWeight', 500),
      letterSpacing: number('letterSpacing', 0),
      lineHeight: number('lineHeight', 1.35),
      opacity: number('opacity', 1).clamp(0, 1).toDouble(),
      shadow: shadow,
    );
  }

  /// Выравнивание обёртки в ячейке (у растянутых типов — не нужно): `cellAlign`, у
  /// кнопок — затем `buttonAlign`, иначе выравнивание ячейки [cellAlign].
  PopupV3Align alignIn(PopupV3Align cellAlign) {
    final own = _align(value('cellAlign'));
    if (own != null) return own;
    if (type == 'button' || type == 'close') {
      return _align(value('buttonAlign')) ?? cellAlign;
    }
    return cellAlign;
  }

  /// Своя вертикаль в ячейке (`cellVerticalAlign`).
  PopupV3VerticalAlign? get verticalAlign =>
      _verticalAlign(style['cellVerticalAlign']);

  /// Выравнивание текста (`messageAlign`).
  TextAlign get messageAlign => switch (value('messageAlign')) {
    'center' => TextAlign.center,
    'right' => TextAlign.right,
    _ => TextAlign.left,
  };

  /// Кегль текста: `messageFontSize`, затем `fontSize`, затем 12.
  double get messageFontSize =>
      cssNum(value('messageFontSize'), number('fontSize', 12));

  /// Насыщенность текста: `messageFontWeight`, затем `fontWeight`, затем 500.
  double get messageFontWeight =>
      cssNum(value('messageFontWeight'), number('fontWeight', 500));

  /// Ссылка на всём элементе (только у `text`, `box`, `image`).
  String? link(PopupV3Variables variables) {
    if (!popupV3LinkableTypes.contains(type)) return null;
    final href = text('linkHref');
    return href == null ? null : cssPresent(variables.applyLink(href))?.trim();
  }

  // --- button / close ---

  /// Действие кнопки: `link`, `close` или `copy`; неизвестное — `link`. У крестика —
  /// всегда `close`.
  String get buttonAction {
    if (type == 'close') return 'close';
    final action = value('buttonAction');
    return action == 'close' || action == 'copy' ? action as String : 'link';
  }

  /// Адрес кнопки-ссылки: `linkHref`, у старых документов `buttonHref`.
  String? buttonHref(PopupV3Variables variables) {
    final href = text('linkHref') ?? text('buttonHref');
    return href == null ? null : cssPresent(variables.applyLink(href))?.trim();
  }

  /// Что копирует кнопка: `copyText`, без него — текст кнопки как есть.
  String copyText(PopupV3Variables variables) =>
      variables.apply(text('copyText') ?? string('buttonText'));

  /// Вид крестика: `text`, `image` или `svg`.
  String get closeMode {
    final mode = value('closeIconMode');
    return mode == 'image' || mode == 'svg' ? mode as String : 'text';
  }

  /// Размер иконки крестика: `closeIconSize`, затем `buttonFontSize`, 8–128.
  double get closeIconSize => cssNum(
    value('closeIconSize'),
    number('buttonFontSize', 22),
  ).clamp(8, 128).toDouble();

  /// Картинка крестика (режим `image`, только http/https).
  String? closeImageUrl(PopupV3Variables variables) {
    if (closeMode != 'image') return null;
    return popupV3ImageUrl(text('imageUrl'), variables);
  }

  /// SVG крестика без скриптов (режим `svg`); не SVG — `null`.
  String? get closeSvg {
    if (closeMode != 'svg') return null;
    final svg = string('closeSvg').trim();
    final start = RegExp(r'^<svg[\s>]', caseSensitive: false);
    if (!start.hasMatch(svg)) return null;
    final cleaned = svg
        .replaceAll(
          RegExp(
            r'<script\b[^>]*>.*?</script>',
            caseSensitive: false,
            dotAll: true,
          ),
          '',
        )
        .replaceAll(
          RegExp(
            r'''\s+on\w+\s*=\s*("[^"]*"|'[^']*'|[^\s>]+)''',
            caseSensitive: false,
          ),
          '',
        )
        .replaceAll(RegExp('javascript:', caseSensitive: false), '');
    return start.hasMatch(cleaned) ? cleaned : null;
  }

  // --- image ---

  /// Рисовать ли картинку (`showImage: false` — нет).
  bool get showImage => style['showImage'] != false;

  /// Высота картинки.
  PopupV3ImageHeight get imageHeight {
    final mode = text('imageHeightMode') ?? 'auto';
    return switch (mode) {
      'auto' => const PopupV3ImageHeight.auto(),
      '%' => PopupV3ImageHeight.percent(
        number('imageHeight', 100).clamp(1, 100).toDouble(),
      ),
      'vh' => PopupV3ImageHeight.vh(
        number('imageHeight', 40).clamp(1, 100).toDouble(),
      ),
      _ => PopupV3ImageHeight.px(number('imageHeight', 120)),
    };
  }

  /// Ширина к высоте из `imageAspectRatio` вида `16 / 9`; иначе `null`.
  double? get imageAspectRatio {
    final match = RegExp(
      r'^(\d+(?:\.\d+)?)\s*/\s*(\d+(?:\.\d+)?)$',
    ).firstMatch(string('imageAspectRatio').trim());
    if (match == null) return null;
    final width = double.parse(match.group(1)!);
    final height = double.parse(match.group(2)!);
    return width > 0 && height > 0 ? width / height : null;
  }

  BoxFit get imageFit => switch (value('imageObjectFit')) {
    'contain' => BoxFit.contain,
    'fill' => BoxFit.fill,
    'none' => BoxFit.none,
    _ => BoxFit.cover,
  };

  // --- emailCollector ---

  /// Поле и кнопка в строку (`inline`) или столбиком (всё остальное).
  bool get emailInline => style['emailLayout'] == 'inline';

  /// Флаги подписки: `emailConsentFields`, старые `emailConsents[].field`, подписи
  /// `email*Label`, иначе все три — как `EmailCollector#consent_fields`.
  List<String> get emailConsentFields {
    List<String> known(Iterable<Object?> values) => <String>[
      for (final value in values)
        if (popupV3ConsentFields.contains(value)) value as String,
    ];
    final own = style['emailConsentFields'];
    if (own is List) {
      final fields = known(own);
      if (fields.isNotEmpty) return fields;
    }
    final consents = style['emailConsents'];
    if (consents is List) {
      final fields = known(<Object?>[
        for (final item in consents)
          if (item is Map) item['field'],
      ]);
      if (fields.isNotEmpty) return fields;
    }
    final labelled = <String>[
      if (cssPresent(style['emailConsentBulkLabel']) != null) 'email_bulk',
      if (cssPresent(style['emailConsentChainLabel']) != null) 'email_chain',
      if (cssPresent(style['emailConsentTransactionalLabel']) != null)
        'email_transactional',
    ];
    return labelled.isNotEmpty ? labelled : popupV3ConsentFields;
  }

  /// Подпись согласия: `emailConsentLabel`, первая из `emailConsents`,
  /// `emailConsentBulkLabel`; нет — `null` (текст по умолчанию).
  String? get emailConsentLabel {
    final own = cssPresent(style['emailConsentLabel']);
    if (own != null) return own.trim();
    final consents = style['emailConsents'];
    if (consents is List && consents.isNotEmpty && consents.first is Map) {
      final label = cssPresent((consents.first as Map)['label']);
      if (label != null) return label;
    }
    return cssPresent(style['emailConsentBulkLabel']);
  }

  /// Сегмент после подписки или формы; пусто — `null`.
  String? segmentId(String key) => cssPresent(style[key])?.trim();

  // --- form ---

  /// Поля формы как `Form#normalized_fields`: только известные виды, не больше 8, id
  /// из `[A-Za-z0-9_-]` (пусто — `field-N`), `required` — только `true`,
  /// `propertyKey` — `[a-z0-9_]`.
  List<PopupV3FormField> get formFields {
    final raw = style['formFields'];
    if (raw is! List) return const <PopupV3FormField>[];
    final fields = <PopupV3FormField>[];
    for (final item in raw) {
      if (item is! Map || !PopupV3FormField.kinds.contains(item['kind'])) {
        continue;
      }
      if (fields.length == 8) break;
      final index = fields.length;
      final id = cssString(
        item['id'],
      ).replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '');
      fields.add(
        PopupV3FormField(
          id: id.isEmpty ? 'field-$index' : id,
          kind: item['kind'] as String,
          label: cssString(item['label']),
          placeholder: cssString(item['placeholder']),
          required: item['required'] == true,
          propertyKey: cssString(
            item['propertyKey'],
          ).toLowerCase().replaceAll(RegExp(r'[^a-z0-9_]'), ''),
        ),
      );
    }
    return fields;
  }

  /// Флаги формы при отмеченном согласии; пусто — флагов нет.
  List<String> get formConsentFields {
    final own = style['formConsentFields'];
    if (own is! List) return const <String>[];
    return <String>[
      for (final value in own)
        if (popupV3ConsentFields.contains(value)) value as String,
    ];
  }

  // --- promoCode ---

  /// Статический код или `null` у персонального.
  bool get promoStatic => value('promoSource') == 'static';

  /// Код промокода: статический или `{{promo_code}}` с подстановкой.
  String promoCode(PopupV3Variables variables) => promoStatic
      ? string('promoStaticCode').trim()
      : variables.applyRuntime('{{promo_code}}');

  bool get promoShowCopy => value('promoShowCopy') != false;

  /// Ссылка «применить» после копирования.
  String? promoApplyHref(PopupV3Variables variables) {
    final href = text('promoApplyHref');
    return href == null ? null : cssPresent(variables.applyLink(href))?.trim();
  }

  // --- survey ---

  /// Тип опроса: `nps`, `csat`, `ces`; неизвестный — `nps`.
  String get surveyType {
    final type = value('surveyType');
    return type == 'csat' || type == 'ces' ? type as String : 'nps';
  }

  /// Шкала оценок опроса.
  List<int> get surveyScale => switch (surveyType) {
    'csat' => <int>[for (var rate = 1; rate <= 5; rate++) rate],
    'ces' => <int>[for (var rate = 1; rate <= 7; rate++) rate],
    _ => <int>[for (var rate = 0; rate <= 10; rate++) rate],
  };

  // --- recommendation ---

  /// Код блока рекомендаций; пусто — элемент не рисуется.
  String? get recommenderCode => cssPresent(style['recommenderCode'])?.trim();

  @override
  String toString() => 'PopupV3Element($id, $type)';
}

/// Адрес картинки с переменными; только http и https.
String? popupV3ImageUrl(String? raw, PopupV3Variables variables) {
  if (raw == null) return null;
  final url = variables.apply(raw).trim();
  final uri = Uri.tryParse(url);
  if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https')) {
    return null;
  }
  return url;
}

/// Высота картинки: по пропорциям, в px, в % или vh экрана.
class PopupV3ImageHeight {
  const PopupV3ImageHeight.auto() : mode = 'auto', value = 0;
  const PopupV3ImageHeight.px(this.value) : mode = 'px';
  const PopupV3ImageHeight.percent(this.value) : mode = '%';
  const PopupV3ImageHeight.vh(this.value) : mode = 'vh';

  final String mode;
  final double value;

  /// Высота в логических px на экране высотой [screenHeight]; `auto` — `null`.
  double? resolve(double screenHeight) => switch (mode) {
    'auto' => null,
    'px' => value,
    // % на mobile — от высоты экрана, как vh (у сайта — от контейнера).
    _ => screenHeight * value / 100,
  };

  @override
  bool operator ==(Object other) =>
      other is PopupV3ImageHeight && other.mode == mode && other.value == value;

  @override
  int get hashCode => Object.hash(mode, value);

  @override
  String toString() => 'PopupV3ImageHeight($mode $value)';
}

/// Поле формы профиля.
class PopupV3FormField {
  const PopupV3FormField({
    required this.id,
    required this.kind,
    required this.label,
    required this.placeholder,
    required this.required,
    required this.propertyKey,
  });

  static const List<String> kinds = <String>[
    'email',
    'phone',
    'first_name',
    'last_name',
    'birthday',
    'gender',
    'custom',
  ];

  final String id;
  final String kind;
  final String label;
  final String placeholder;
  final bool required;
  final String propertyKey;
}

/// Ячейка строки: выравнивание и элементы по порядку.
class PopupV3Cell {
  const PopupV3Cell({
    required this.align,
    required this.verticalAlign,
    required this.elements,
  });

  final PopupV3Align align;

  /// Вертикаль ячейки; если у элемента своя (`cellVerticalAlign`) — ячейка сверху, а
  /// элемент встаёт сам.
  final PopupV3VerticalAlign verticalAlign;
  final List<PopupV3Element> elements;
}

/// Строка сетки.
class PopupV3Row {
  const PopupV3Row({
    required this.id,
    required this.fractions,
    required this.gap,
    required this.minHeight,
    required this.cells,
    this.background,
    this.backgroundImage,
    this.backgroundSize = 'cover',
    this.backgroundPosition = 'center',
    this.backgroundRepeat = 'no-repeat',
  });

  final String id;

  /// Доли колонок, в сумме 1.
  final List<double> fractions;
  final double gap;
  final double minHeight;
  final List<PopupV3Cell> cells;
  final Color? background;
  final String? backgroundImage;
  final String backgroundSize;
  final String backgroundPosition;
  final String backgroundRepeat;
}

/// Затемнение под попапом.
typedef PopupV3Overlay = ({Color color, bool enabled});

/// Рамка, посчитанная для экрана.
class PopupV3FrameMetrics {
  const PopupV3FrameMetrics({
    required this.width,
    required this.maxWidth,
    required this.height,
    required this.minHeight,
    required this.padding,
    required this.radius,
  });

  /// Ширина рамки в логических px (до ограничения экраном).
  final double width;

  /// Предел ширины; `null` — без предела.
  final double? maxWidth;

  /// Высота; `null` — по содержимому.
  final double? height;
  final double minHeight;
  final double padding;
  final double radius;

  /// Итоговая ширина: [width] не шире [maxWidth] и [available].
  double resolveWidth(double available) =>
      math.max(0, math.min(available, math.min(width, maxWidth ?? width)));
}

/// Рамка попапа (`frameStyle`): размеры с breakpoints, фон, граница, затемнение,
/// отступы баннера.
class PopupV3Frame {
  PopupV3Frame(Map<String, Object?> raw, {required this.layout})
    : _raw = raw,
      background = parseCssColor(raw['bgColor']) ?? const Color(0xffffffff),
      borderWidth = math.max(0, cssNum(raw['borderWidth'], 1)),
      borderColor =
          parseCssColor(raw['borderColor']) ?? const Color(0xffe5e7eb),
      offsetX = math.max(0, cssNum(raw['offsetX'], 0)),
      offsetY = math.max(0, cssNum(raw['offsetY'], 0)),
      lockBackground = cssBool(raw['lockBackgroundScroll']) ?? false,
      overlay = _overlay(raw, layout);

  final Map<String, Object?> _raw;
  final PopupV3Layout layout;
  final Color background;
  final double borderWidth;
  final Color borderColor;

  /// Отступы баннера от краёв: X — слева и справа, Y — от своего края.
  final double offsetX;
  final double offsetY;

  /// Блокировать приложение под баннером без затемнения.
  final bool lockBackground;
  final PopupV3Overlay overlay;

  static PopupV3Overlay _overlay(
    Map<String, Object?> raw,
    PopupV3Layout layout,
  ) {
    final enabled =
        cssBool(raw['overlayEnabled']) ?? layout == PopupV3Layout.modal;
    final color = parseCssColor(raw['overlayColor']) ?? const Color(0xff000000);
    final opacity = cssNum(raw['overlayOpacity'], 0.5).clamp(0, 1).toDouble();
    return (
      color: color.withValues(alpha: color.a * opacity),
      enabled: enabled,
    );
  }

  /// Размеры для экрана [screen]: breakpoints, у которых `mediaMaxWidth` не меньше
  /// ширины экрана, применяются от широкого к узкому (узкий побеждает).
  PopupV3FrameMetrics metrics(Size screen) {
    final style = Map<String, Object?>.from(_raw);
    final breakpoints = _raw['breakpoints'];
    if (breakpoints is List) {
      final matching =
          <Map<Object?, Object?>>[
            for (final item in breakpoints)
              if (item is Map &&
                  cssNum(item['mediaMaxWidth'], -1) >= screen.width)
                item,
          ]..sort(
            (a, b) => cssNum(
              b['mediaMaxWidth'],
              0,
            ).compareTo(cssNum(a['mediaMaxWidth'], 0)),
          );
      for (final breakpoint in matching) {
        for (final key in _breakpointKeys) {
          final value = breakpoint[key];
          if (value != null && !(value is String && value.isEmpty)) {
            style[key] = value;
          }
        }
      }
    }
    double size(Object? value, Object? mode, double fallback, double base) {
      final number = cssNum(value, fallback);
      return switch (mode) {
        '%' || 'vw' || 'vh' => base * number / 100,
        _ => number,
      };
    }

    final widthMode = cssPresent(style['widthMode']) ?? '%';
    final width = size(
      style['width'],
      widthMode == 'vh' ? 'vw' : widthMode,
      92,
      screen.width,
    );
    final maxWidthMode = cssPresent(style['maxWidthMode']) ?? 'px';
    final maxWidth = maxWidthMode == 'none'
        ? null
        : size(style['maxWidth'], maxWidthMode, 480, screen.width);
    final heightMode = cssPresent(style['heightMode']) ?? 'auto';
    final height = heightMode == 'auto'
        ? null
        : size(style['height'], heightMode, 320, screen.height);
    final minHeightMode = cssPresent(style['minHeightMode']) ?? 'px';
    final minHeight = size(style['minHeight'], minHeightMode, 0, screen.height);
    return PopupV3FrameMetrics(
      width: math.max(0, width),
      maxWidth: maxWidth == null ? null : math.max(0, maxWidth),
      height: height == null ? null : math.max(0, height),
      minHeight: math.max(0, minHeight),
      padding: math.max(0, cssNum(style['padding'], 20)),
      radius: math.max(0, cssNum(style['borderRadius'], 16)),
    );
  }

  static const List<String> _breakpointKeys = <String>[
    'width',
    'widthMode',
    'height',
    'heightMode',
    'maxWidth',
    'maxWidthMode',
    'minHeight',
    'minHeightMode',
    'padding',
    'borderRadius',
  ];
}

/// Документ design, разобранный один раз до показа: рамка, строки с ячейками и
/// элементами, переменные. Чистый: без виджетов.
class PopupV3Design {
  PopupV3Design._({
    required this.frame,
    required this.rows,
    required this.variables,
    required this.dropped,
  });

  /// Лимиты компилятора.
  static const int maxRows = 50;
  static const int maxColumns = 6;
  static const int maxElements = 200;

  final PopupV3Frame frame;
  final List<PopupV3Row> rows;
  final PopupV3Variables variables;

  /// Не попавшие в рендер элементы: id → причина (лог).
  final Map<String, String> dropped;

  /// Нечего показывать.
  bool get isEmpty =>
      rows.every((row) => row.cells.every((cell) => cell.elements.isEmpty));

  /// Все элементы по порядку строк и ячеек.
  List<PopupV3Element> get elements => <PopupV3Element>[
    for (final row in rows)
      for (final cell in row.cells) ...cell.elements,
  ];

  PopupV3Element? element(String id) {
    for (final element in elements) {
      if (element.id == id) return element;
    }
    return null;
  }

  /// Разбор документа [design] попапа макета [layout]. Элементы неизвестных типов
  /// (нет в [types]), с несуществующей строкой или колонкой выпадают в [dropped].
  /// Дизайн без строк — старый формат с `x/y`: элементы идут столбиком по `y`, при
  /// равном `y` — по `x`.
  factory PopupV3Design.parse(
    Map<String, Object?> design, {
    required PopupV3Layout layout,
    required Set<String> types,
    Map<String, String> runtime = const <String, String>{},
    TargetPlatform? platform,
  }) {
    final dropped = <String, String>{};
    final frameRaw = design['frameStyle'];
    final frame = PopupV3Frame(
      frameRaw is Map
          ? Map<String, Object?>.from(frameRaw)
          : <String, Object?>{},
      layout: layout,
    );
    final variables = PopupV3Variables.fromDesign(
      design['variables'],
      runtime: runtime,
      platform: platform,
    );

    final rawElements = <Map<Object?, Object?>>[
      for (final item
          in design['elements'] is List
              ? design['elements'] as List
              : const <Object?>[])
        if (item is Map) item,
    ];
    if (rawElements.length > maxElements) {
      for (final item in rawElements.skip(maxElements)) {
        dropped['${item['id']}'] = 'over the limit of $maxElements elements';
      }
      rawElements.removeRange(maxElements, rawElements.length);
    }

    PopupV3Element? element(Map<Object?, Object?> item) {
      final id = cssString(item['id']);
      final type = cssString(item['type']);
      if (!types.contains(type)) {
        dropped[id] = 'unknown type "$type"';
        return null;
      }
      final style = item['style'];
      return PopupV3Element(
        id: id,
        type: type,
        style: style is Map
            ? Map<String, Object?>.from(style)
            : const <String, Object?>{},
      );
    }

    final rawRows = <Map<Object?, Object?>>[
      for (final item
          in design['rows'] is List
              ? design['rows'] as List
              : const <Object?>[])
        if (item is Map) item,
    ];

    if (rawRows.isEmpty) {
      final sorted = rawElements.toList()
        ..sort((a, b) {
          final byY = cssNum(a['y'], 0).compareTo(cssNum(b['y'], 0));
          return byY != 0
              ? byY
              : cssNum(a['x'], 0).compareTo(cssNum(b['x'], 0));
        });
      final elements = <PopupV3Element>[
        for (final item in sorted) ?element(item),
      ];
      return PopupV3Design._(
        frame: frame,
        rows: elements.isEmpty
            ? const <PopupV3Row>[]
            : <PopupV3Row>[
                PopupV3Row(
                  id: '',
                  fractions: const <double>[1],
                  gap: 8,
                  minHeight: 0,
                  cells: <PopupV3Cell>[
                    PopupV3Cell(
                      align: PopupV3Align.left,
                      verticalAlign: PopupV3VerticalAlign.top,
                      elements: elements,
                    ),
                  ],
                ),
              ],
        variables: variables,
        dropped: dropped,
      );
    }

    if (rawRows.length > maxRows) rawRows.removeRange(maxRows, rawRows.length);
    final byCell = <String, List<Map<Object?, Object?>>>{};
    for (final item in rawElements) {
      final key =
          '${cssString(item['rowId'])}:${cssNum(item['partIndex'], 0).toInt()}';
      (byCell[key] ??= <Map<Object?, Object?>>[]).add(item);
    }
    final placed = <String>{};
    final rows = <PopupV3Row>[];
    for (final row in rawRows) {
      final id = cssString(row['id']);
      final fractions = _fractions(row);
      final cellsRaw = row['cells'] is List ? row['cells'] as List : const [];
      final rowAlign = _align(row['align']);
      final rowVertical = _verticalAlign(row['verticalAlign']);
      final cells = <PopupV3Cell>[];
      for (var index = 0; index < fractions.length; index++) {
        final cell = index < cellsRaw.length && cellsRaw[index] is Map
            ? cellsRaw[index] as Map
            : const <Object?, Object?>{};
        final items = byCell['$id:$index'] ?? const <Map<Object?, Object?>>[];
        placed.add('$id:$index');
        final elements = <PopupV3Element>[
          for (final item in items) ?element(item),
        ];
        final overridden = items.any(
          (item) =>
              item['style'] is Map &&
              _verticalAlign((item['style'] as Map)['cellVerticalAlign']) !=
                  null,
        );
        cells.add(
          PopupV3Cell(
            align: _align(cell['align']) ?? rowAlign ?? PopupV3Align.left,
            verticalAlign: overridden
                ? PopupV3VerticalAlign.top
                : _verticalAlign(cell['verticalAlign']) ??
                      rowVertical ??
                      PopupV3VerticalAlign.top,
            elements: elements,
          ),
        );
      }
      final bgImage = popupV3ImageUrl(cssPresent(row['bgImageUrl']), variables);
      rows.add(
        PopupV3Row(
          id: id,
          fractions: fractions,
          gap: math.max(0, cssNum(row['gap'], 8)),
          minHeight: math.max(0, cssNum(row['minHeight'], 110)),
          cells: cells,
          background: cssPresent(row['bgColor']) == null
              ? null
              : parseCssColor(row['bgColor']),
          backgroundImage: bgImage,
          backgroundSize:
              cssEnum(row['bgSize'], const <String>[
                'cover',
                'contain',
                'auto',
              ]) ??
              'cover',
          backgroundPosition:
              cssEnum(row['bgPosition'], const <String>[
                'center',
                'top',
                'bottom',
                'left',
                'right',
              ]) ??
              'center',
          backgroundRepeat:
              cssEnum(row['bgRepeat'], const <String>[
                'no-repeat',
                'repeat',
                'repeat-x',
                'repeat-y',
              ]) ??
              'no-repeat',
        ),
      );
    }
    byCell.forEach((key, items) {
      if (placed.contains(key)) return;
      for (final item in items) {
        dropped[cssString(item['id'])] = 'no row or column $key';
      }
    });
    return PopupV3Design._(
      frame: frame,
      rows: rows,
      variables: variables,
      dropped: dropped,
    );
  }

  /// Доли колонок: проценты `columns`, у старых документов — `parts` равных частей;
  /// не больше 6.
  static List<double> _fractions(Map<Object?, Object?> row) {
    final columns = row['columns'];
    var parts = <double>[];
    if (columns is List) {
      parts = <double>[
        for (final column in columns)
          if (cssNum(column, 0) > 0) cssNum(column, 0),
      ];
    }
    if (parts.isEmpty) {
      final count = cssNum(row['parts'], 1).toInt().clamp(1, maxColumns);
      parts = List<double>.filled(count, 1);
    }
    if (parts.length > maxColumns) parts = parts.sublist(0, maxColumns);
    final sum = parts.fold<double>(0, (total, part) => total + part);
    return <double>[for (final part in parts) part / sum];
  }
}
