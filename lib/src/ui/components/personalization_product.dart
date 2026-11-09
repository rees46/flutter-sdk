import 'package:flutter/widgets.dart';

import 'personalization_product_card.dart';

/// Данные товара для карточки и раскладок каталога.
///
/// Строки уже отформатированы: цена с валютой, оценка с запятой, скидка со знаком —
/// форматирование и локализация остаются за интегратором.
/// Картинку грузит штатный [Image] по [image]: NetworkImage есть во фреймворке.
@immutable
class PersonalizationProduct {
  const PersonalizationProduct({
    required this.id,
    required this.name,
    required this.price,
    this.image,
    this.brand,
    this.rating,
    this.oldPrice,
    this.discount,
    this.actionText,
    this.url,
    this.deeplink,
  });

  final String id;
  final String name;
  final String price;
  final ImageProvider? image;
  final String? brand;
  final PersonalizationProductRating? rating;
  final String? oldPrice;
  final String? discount;
  final String? actionText;

  /// Страница товара на сайте магазина.
  final String? url;

  /// Ссылка на товар в приложении для платформы, на которой оно запущено:
  /// `deeplink_android` на Android, `deeplink_ios` на iOS.
  final String? deeplink;
}
