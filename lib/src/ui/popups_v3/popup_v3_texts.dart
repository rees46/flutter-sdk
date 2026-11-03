import 'dart:ui' show PlatformDispatcher;

/// Тексты попапа v3 на случай пустого поля в дизайне: русские или английские по языку
/// устройства. На сайте их подставляет компилятор из локали ЛК (`popups.compiler.*`).
class PopupV3Texts {
  const PopupV3Texts._({
    required this.close,
    required this.detail,
    required this.image,
    required this.email,
    required this.subscribe,
    required this.emailConsent,
    required this.emailError,
    required this.formError,
    required this.send,
    required this.copy,
    required this.copied,
    required this.thanks,
    required this.genderMale,
    required this.genderFemale,
    required this.sendError,
  });

  /// Подпись кнопки закрытия для скринридера.
  final String close;

  /// Кнопка без текста.
  final String detail;

  /// Подпись картинки без `imageAlt`.
  final String image;

  /// Плейсхолдер поля email.
  final String email;
  final String subscribe;
  final String emailConsent;
  final String emailError;
  final String formError;
  final String send;
  final String copy;
  final String copied;
  final String thanks;
  final String genderMale;
  final String genderFemale;

  /// Отправка формы или опроса не удалась (сеть, сервер).
  final String sendError;

  static const PopupV3Texts ru = PopupV3Texts._(
    close: 'Закрыть',
    detail: 'Подробнее',
    image: 'Изображение',
    email: 'Email',
    subscribe: 'Подписаться',
    emailConsent: 'Я согласен(на) получать рассылку',
    emailError: 'Введите корректный email и отметьте согласие',
    formError: 'Заполните обязательные поля',
    send: 'Отправить',
    copy: 'Скопировать',
    copied: 'Скопировано',
    thanks: 'Спасибо!',
    genderMale: 'Мужской',
    genderFemale: 'Женский',
    sendError: 'Не удалось отправить. Попробуйте ещё раз',
  );

  static const PopupV3Texts en = PopupV3Texts._(
    close: 'Close',
    detail: 'Learn more',
    image: 'Image',
    email: 'Email',
    subscribe: 'Subscribe',
    emailConsent: 'I agree to receive emails',
    emailError: 'Enter a valid email and accept the terms',
    formError: 'Fill in the required fields',
    send: 'Send',
    copy: 'Copy',
    copied: 'Copied',
    thanks: 'Thank you!',
    genderMale: 'Male',
    genderFemale: 'Female',
    sendError: 'Could not send. Please try again',
  );

  /// По языку устройства: русский — для `ru`, остальные — английский.
  static PopupV3Texts get device =>
      PlatformDispatcher.instance.locale.languageCode == 'ru' ? ru : en;
}
