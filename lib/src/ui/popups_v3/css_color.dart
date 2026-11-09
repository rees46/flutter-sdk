import 'dart:ui' show Color;

/// Цвет CSS из документа попапа v3: `#rgb`, `#rgba`, `#rrggbb`, `#rrggbbaa` (порядок
/// CSS — альфа в конце), `rgb()`/`rgba()` через запятые или пробелы (альфа после `/`,
/// числом или процентом), 148 именованных цветов и `transparent`. Остальное — `null`:
/// элемент возьмёт свой цвет по умолчанию.
Color? parseCssColor(Object? value) {
  if (value is! String) return null;
  final text = value.trim().toLowerCase();
  if (text.isEmpty) return null;
  if (text.startsWith('#')) return _hex(text.substring(1));
  if (text == 'transparent') return const Color(0x00000000);
  if (text.startsWith('rgb')) return _rgb(text);
  final named = _named[text];
  return named == null ? null : Color(0xff000000 | named);
}

/// Цвет строкой `#rrggbbaa` в нижнем регистре — для тестов и логов.
String cssColorHex(Color color) {
  String two(int value) => value.toRadixString(16).padLeft(2, '0');
  final argb = color.toARGB32();
  return '#${two((argb >> 16) & 0xff)}${two((argb >> 8) & 0xff)}'
      '${two(argb & 0xff)}${two((argb >> 24) & 0xff)}';
}

final RegExp _hexDigits = RegExp(r'^[0-9a-f]+$');

Color? _hex(String digits) {
  if (!_hexDigits.hasMatch(digits)) return null;
  int channel(String part) =>
      int.parse(part.length == 1 ? '$part$part' : part, radix: 16);
  switch (digits.length) {
    case 3:
    case 4:
      final alpha = digits.length == 4 ? channel(digits[3]) : 255;
      return Color.fromARGB(
        alpha,
        channel(digits[0]),
        channel(digits[1]),
        channel(digits[2]),
      );
    case 6:
    case 8:
      final alpha = digits.length == 8 ? channel(digits.substring(6, 8)) : 255;
      return Color.fromARGB(
        alpha,
        channel(digits.substring(0, 2)),
        channel(digits.substring(2, 4)),
        channel(digits.substring(4, 6)),
      );
  }
  return null;
}

final RegExp _rgbFunction = RegExp(r'^rgba?\((.*)\)$');

Color? _rgb(String text) {
  final match = _rgbFunction.firstMatch(text);
  if (match == null) return null;
  var body = match.group(1)!.trim();
  String? alphaPart;
  final slash = body.indexOf('/');
  if (slash >= 0) {
    alphaPart = body.substring(slash + 1).trim();
    body = body.substring(0, slash).trim();
  }
  final parts = body
      .split(RegExp(r'[\s,]+'))
      .where((part) => part.isNotEmpty)
      .toList();
  if (alphaPart == null && parts.length == 4) alphaPart = parts.removeLast();
  if (parts.length != 3) return null;
  final channels = <int>[];
  for (final part in parts) {
    final value = _number(part, 255);
    if (value == null) return null;
    channels.add(value.clamp(0, 255).round());
  }
  var alpha = 255;
  if (alphaPart != null) {
    final value = _number(alphaPart, 1);
    if (value == null) return null;
    alpha = (value.clamp(0, 1) * 255).round();
  }
  return Color.fromARGB(alpha, channels[0], channels[1], channels[2]);
}

/// Число или процент от [scale].
double? _number(String part, double scale) {
  if (part.endsWith('%')) {
    final value = double.tryParse(part.substring(0, part.length - 1));
    return value == null ? null : value / 100 * scale;
  }
  return double.tryParse(part);
}

/// Именованные цвета CSS (RGB без альфы).
const Map<String, int> _named = <String, int>{
  'aliceblue': 0xf0f8ff,
  'antiquewhite': 0xfaebd7,
  'aqua': 0x00ffff,
  'aquamarine': 0x7fffd4,
  'azure': 0xf0ffff,
  'beige': 0xf5f5dc,
  'bisque': 0xffe4c4,
  'black': 0x000000,
  'blanchedalmond': 0xffebcd,
  'blue': 0x0000ff,
  'blueviolet': 0x8a2be2,
  'brown': 0xa52a2a,
  'burlywood': 0xdeb887,
  'cadetblue': 0x5f9ea0,
  'chartreuse': 0x7fff00,
  'chocolate': 0xd2691e,
  'coral': 0xff7f50,
  'cornflowerblue': 0x6495ed,
  'cornsilk': 0xfff8dc,
  'crimson': 0xdc143c,
  'cyan': 0x00ffff,
  'darkblue': 0x00008b,
  'darkcyan': 0x008b8b,
  'darkgoldenrod': 0xb8860b,
  'darkgray': 0xa9a9a9,
  'darkgreen': 0x006400,
  'darkgrey': 0xa9a9a9,
  'darkkhaki': 0xbdb76b,
  'darkmagenta': 0x8b008b,
  'darkolivegreen': 0x556b2f,
  'darkorange': 0xff8c00,
  'darkorchid': 0x9932cc,
  'darkred': 0x8b0000,
  'darksalmon': 0xe9967a,
  'darkseagreen': 0x8fbc8f,
  'darkslateblue': 0x483d8b,
  'darkslategray': 0x2f4f4f,
  'darkslategrey': 0x2f4f4f,
  'darkturquoise': 0x00ced1,
  'darkviolet': 0x9400d3,
  'deeppink': 0xff1493,
  'deepskyblue': 0x00bfff,
  'dimgray': 0x696969,
  'dimgrey': 0x696969,
  'dodgerblue': 0x1e90ff,
  'firebrick': 0xb22222,
  'floralwhite': 0xfffaf0,
  'forestgreen': 0x228b22,
  'fuchsia': 0xff00ff,
  'gainsboro': 0xdcdcdc,
  'ghostwhite': 0xf8f8ff,
  'gold': 0xffd700,
  'goldenrod': 0xdaa520,
  'gray': 0x808080,
  'green': 0x008000,
  'greenyellow': 0xadff2f,
  'grey': 0x808080,
  'honeydew': 0xf0fff0,
  'hotpink': 0xff69b4,
  'indianred': 0xcd5c5c,
  'indigo': 0x4b0082,
  'ivory': 0xfffff0,
  'khaki': 0xf0e68c,
  'lavender': 0xe6e6fa,
  'lavenderblush': 0xfff0f5,
  'lawngreen': 0x7cfc00,
  'lemonchiffon': 0xfffacd,
  'lightblue': 0xadd8e6,
  'lightcoral': 0xf08080,
  'lightcyan': 0xe0ffff,
  'lightgoldenrodyellow': 0xfafad2,
  'lightgray': 0xd3d3d3,
  'lightgreen': 0x90ee90,
  'lightgrey': 0xd3d3d3,
  'lightpink': 0xffb6c1,
  'lightsalmon': 0xffa07a,
  'lightseagreen': 0x20b2aa,
  'lightskyblue': 0x87cefa,
  'lightslategray': 0x778899,
  'lightslategrey': 0x778899,
  'lightsteelblue': 0xb0c4de,
  'lightyellow': 0xffffe0,
  'lime': 0x00ff00,
  'limegreen': 0x32cd32,
  'linen': 0xfaf0e6,
  'magenta': 0xff00ff,
  'maroon': 0x800000,
  'mediumaquamarine': 0x66cdaa,
  'mediumblue': 0x0000cd,
  'mediumorchid': 0xba55d3,
  'mediumpurple': 0x9370db,
  'mediumseagreen': 0x3cb371,
  'mediumslateblue': 0x7b68ee,
  'mediumspringgreen': 0x00fa9a,
  'mediumturquoise': 0x48d1cc,
  'mediumvioletred': 0xc71585,
  'midnightblue': 0x191970,
  'mintcream': 0xf5fffa,
  'mistyrose': 0xffe4e1,
  'moccasin': 0xffe4b5,
  'navajowhite': 0xffdead,
  'navy': 0x000080,
  'oldlace': 0xfdf5e6,
  'olive': 0x808000,
  'olivedrab': 0x6b8e23,
  'orange': 0xffa500,
  'orangered': 0xff4500,
  'orchid': 0xda70d6,
  'palegoldenrod': 0xeee8aa,
  'palegreen': 0x98fb98,
  'paleturquoise': 0xafeeee,
  'palevioletred': 0xdb7093,
  'papayawhip': 0xffefd5,
  'peachpuff': 0xffdab9,
  'peru': 0xcd853f,
  'pink': 0xffc0cb,
  'plum': 0xdda0dd,
  'powderblue': 0xb0e0e6,
  'purple': 0x800080,
  'rebeccapurple': 0x663399,
  'red': 0xff0000,
  'rosybrown': 0xbc8f8f,
  'royalblue': 0x4169e1,
  'saddlebrown': 0x8b4513,
  'salmon': 0xfa8072,
  'sandybrown': 0xf4a460,
  'seagreen': 0x2e8b57,
  'seashell': 0xfff5ee,
  'sienna': 0xa0522d,
  'silver': 0xc0c0c0,
  'skyblue': 0x87ceeb,
  'slateblue': 0x6a5acd,
  'slategray': 0x708090,
  'slategrey': 0x708090,
  'snow': 0xfffafa,
  'springgreen': 0x00ff7f,
  'steelblue': 0x4682b4,
  'tan': 0xd2b48c,
  'teal': 0x008080,
  'thistle': 0xd8bfd8,
  'tomato': 0xff6347,
  'turquoise': 0x40e0d0,
  'violet': 0xee82ee,
  'wheat': 0xf5deb3,
  'white': 0xffffff,
  'whitesmoke': 0xf5f5f5,
  'yellow': 0xffff00,
  'yellowgreen': 0x9acd32,
};
