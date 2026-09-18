import 'package:flutter/widgets.dart';

import '../personalization_theme.dart';

/// Пропорция изображения товара.
enum PersonalizationProductImageAspect { square, landscape, portrait }

/// Изображение товара с фиксированной пропорцией.
///
/// Источник: Figma Mobile SDK UI Kit, секция Image (88:93), фрейм Product (88:94):
/// три пропорции — 1:1, 4:3, 3:4. Ширину задаёт разметка, высота считается сама.
///
/// Картинку грузит штатный [Image] по [image]: NetworkImage есть в самом фреймворке.
/// До загрузки виден плейсхолдер цвета Background/Card — в макете заливка
/// плейсхолдера к переменной не привязана, взят ближайший токен.
class PersonalizationProductImage extends StatelessWidget {
  const PersonalizationProductImage({
    super.key,
    this.image,
    this.aspect = PersonalizationProductImageAspect.square,
  });

  final ImageProvider? image;
  final PersonalizationProductImageAspect aspect;

  double get _ratio => switch (aspect) {
    PersonalizationProductImageAspect.square => 1,
    PersonalizationProductImageAspect.landscape => 4 / 3,
    PersonalizationProductImageAspect.portrait => 3 / 4,
  };

  @override
  Widget build(BuildContext context) {
    final colors = PersonalizationTheme.of(context).colors;
    return AspectRatio(
      aspectRatio: _ratio,
      child: ColoredBox(
        color: colors.backgroundCard,
        child: image == null ? null : Image(image: image!, fit: BoxFit.cover),
      ),
    );
  }
}
