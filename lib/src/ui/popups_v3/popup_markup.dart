import 'package:flutter/painting.dart';

/// Кусок текста с облегчённой разметкой конструктора попапов.
class PopupMarkupSpan {
  const PopupMarkupSpan(
    this.text, {
    this.bold = false,
    this.italic = false,
    this.underline = false,
    this.strike = false,
    this.overline = false,
  });

  final String text;
  final bool bold;
  final bool italic;
  final bool underline;
  final bool strike;
  final bool overline;

  PopupMarkupSpan withText(String text) => PopupMarkupSpan(
    text,
    bold: bold,
    italic: italic,
    underline: underline,
    strike: strike,
    overline: overline,
  );

  @override
  String toString() =>
      'PopupMarkupSpan(${<String>[text, if (bold) 'bold', if (italic) 'italic', if (underline) 'underline', if (strike) 'strike', if (overline) 'overline'].join(', ')})';
}

/// Регэксп разметки компилятора (`Context::RICH_TEXT_RE`): `***жирный курсив***`,
/// `**жирный**`, `~~зачёркнутый~~`, `__подчёркнутый__`, `^^надчёркнутый^^`, `*курсив*`.
final RegExp _richText = RegExp(
  r'\*\*\*([^*]+)\*\*\*|\*\*([^*]+)\*\*|~~([^~]+)~~|__([^_]+)__|\^\^([^^]+)\^\^|\*([^*]+)\*',
);

/// Разбор разметки [text] слева направо одним регэкспом, без вложенности — как
/// `gsub(RICH_TEXT_RE)` компилятора. HTML остаётся текстом, `\n` — перенос строки.
List<PopupMarkupSpan> parsePopupMarkup(String text) {
  final spans = <PopupMarkupSpan>[];
  var position = 0;
  for (final match in _richText.allMatches(text)) {
    if (match.start > position) {
      spans.add(PopupMarkupSpan(text.substring(position, match.start)));
    }
    final group = <int>[
      1,
      2,
      3,
      4,
      5,
      6,
    ].firstWhere((index) => match.group(index) != null);
    final content = match.group(group)!;
    spans.add(switch (group) {
      1 => PopupMarkupSpan(content, bold: true, italic: true),
      2 => PopupMarkupSpan(content, bold: true),
      3 => PopupMarkupSpan(content, strike: true),
      4 => PopupMarkupSpan(content, underline: true),
      5 => PopupMarkupSpan(content, overline: true),
      _ => PopupMarkupSpan(content, italic: true),
    });
    position = match.end;
  }
  if (position < text.length) {
    spans.add(PopupMarkupSpan(text.substring(position)));
  }
  return spans;
}

/// [spans] текстом Flutter со стилем [base]: жирный — 700, курсив, линии.
TextSpan popupMarkupTextSpan(List<PopupMarkupSpan> spans, TextStyle base) {
  return TextSpan(
    style: base,
    children: <InlineSpan>[
      for (final span in spans)
        TextSpan(
          text: span.text,
          style: TextStyle(
            fontWeight: span.bold ? FontWeight.w700 : null,
            fontStyle: span.italic ? FontStyle.italic : null,
            decoration: _decoration(span),
            decorationColor: base.color,
          ),
        ),
    ],
  );
}

TextDecoration? _decoration(PopupMarkupSpan span) {
  final lines = <TextDecoration>[
    if (span.underline) TextDecoration.underline,
    if (span.strike) TextDecoration.lineThrough,
    if (span.overline) TextDecoration.overline,
  ];
  return lines.isEmpty ? null : TextDecoration.combine(lines);
}
