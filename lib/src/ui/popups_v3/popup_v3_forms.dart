import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../popups_v3/popups_v3_engine.dart';
import '../components/personalization_checkbox.dart';
import '../widgets/stories_api_v3.dart';
import 'popup_markup.dart';
import 'popup_v3_design.dart';
import 'popup_v3_view.dart';

final RegExp _emailFormat = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
final RegExp _phoneFormat = RegExp(r'^\+?[\d\s\-()]{5,20}$');

/// Похож ли [value] на email.
bool popupV3ValidEmail(String value) => _emailFormat.hasMatch(value.trim());

/// Похож ли [value] на телефон.
bool popupV3ValidPhone(String value) => _phoneFormat.hasMatch(value.trim());

const Color _errorColor = Color(0xffb91c1c);

/// Поле ввода формы попапа по стилям дизайна: фон, цвет, рамка, радиус.
class PopupV3Input extends StatelessWidget {
  const PopupV3Input({
    super.key,
    required this.controller,
    required this.style,
    required this.background,
    required this.borderColor,
    required this.radius,
    required this.paddingY,
    this.placeholder,
    this.keyboardType,
    this.maxLines = 1,
    this.minLines,
    this.enabled = true,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final TextStyle style;
  final Color background;
  final Color borderColor;
  final double radius;
  final double paddingY;
  final String? placeholder;
  final TextInputType? keyboardType;
  final int? maxLines;
  final int? minLines;
  final bool enabled;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(radius),
      borderSide: BorderSide(color: borderColor),
    );
    return TextField(
      controller: controller,
      enabled: enabled,
      style: style,
      keyboardType: keyboardType,
      maxLines: maxLines,
      minLines: minLines,
      cursorColor: style.color,
      textInputAction: maxLines == 1 ? TextInputAction.done : null,
      onSubmitted: onSubmitted,
      onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
      decoration: InputDecoration(
        isDense: true,
        filled: true,
        fillColor: background,
        hintText: placeholder,
        hintStyle: style.copyWith(color: style.color?.withValues(alpha: 0.5)),
        contentPadding: EdgeInsets.symmetric(
          horizontal: 12,
          vertical: paddingY,
        ),
        border: border,
        enabledBorder: border,
        disabledBorder: border,
        focusedBorder: border,
      ),
    );
  }
}

/// Кнопка отправки формы по стилям `button*` дизайна; пока идёт отправка — приглушена
/// и не нажимается.
class PopupV3SubmitButton extends StatelessWidget {
  const PopupV3SubmitButton({
    super.key,
    required this.element,
    required this.label,
    required this.busy,
    required this.onPressed,
    this.paddingX = 18,
  });

  final PopupV3Element element;
  final String label;
  final bool busy;
  final VoidCallback onPressed;
  final double paddingX;

  @override
  Widget build(BuildContext context) {
    final scope = PopupV3Scope.of(context);
    return Semantics(
      button: true,
      enabled: !busy,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: busy ? null : onPressed,
        child: Opacity(
          opacity: busy ? 0.6 : 1,
          child: Container(
            decoration: BoxDecoration(
              color: element.color('buttonBgColor', '#2563eb'),
              borderRadius: BorderRadius.circular(
                element.number('buttonRadius', 10),
              ),
            ),
            padding: EdgeInsets.symmetric(
              horizontal: element.number('buttonPaddingX', paddingX),
              vertical: element.number('buttonPaddingY', 10),
            ),
            child: PopupV3RichText(
              scope.variables.rich(label),
              textAlign: TextAlign.center,
              style: popupV3TextStyle(
                element.box,
                color: element.color('buttonTextColor', '#ffffff'),
                fontSize: element.number('buttonFontSize', 14),
                fontWeight: 500,
                height: 1.25,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Согласие: чекбокс кита и подпись с разметкой.
class PopupV3Consent extends StatelessWidget {
  const PopupV3Consent({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    required this.style,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    final scope = PopupV3Scope.of(context);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onChanged(!value),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          PersonalizationCheckbox(
            state: value
                ? PersonalizationCheckboxState.checked
                : PersonalizationCheckboxState.unchecked,
            onChanged: (state) =>
                onChanged(state == PersonalizationCheckboxState.checked),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 2),
              child: PopupV3RichText(scope.variables.rich(label), style: style),
            ),
          ),
        ],
      ),
    );
  }
}

/// Текст ошибки формы.
class PopupV3Status extends StatelessWidget {
  const PopupV3Status({super.key, required this.text, required this.box});

  final String text;
  final PopupV3Box box;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: popupV3TextStyle(
      box,
      color: _errorColor,
      fontSize: 12,
      fontWeight: 400,
      height: 1.35,
    ),
  );
}

/// Экран успеха формы: заголовок и текст.
class PopupV3Success extends StatelessWidget {
  const PopupV3Success({
    super.key,
    required this.box,
    required this.title,
    required this.message,
    this.background = const Color(0x00000000),
    this.color,
    this.titleColor,
    this.align = TextAlign.center,
    this.radius = 0,
    this.paddingX = 0,
    this.paddingY = 0,
    this.titleSize = 16,
    this.messageSize = 13,
  });

  final PopupV3Box box;
  final String? title;
  final String? message;
  final Color background;
  final Color? color;
  final Color? titleColor;
  final TextAlign align;
  final double radius;
  final double paddingX;
  final double paddingY;
  final double titleSize;
  final double messageSize;

  @override
  Widget build(BuildContext context) {
    final scope = PopupV3Scope.of(context);
    final title = this.title ?? (message == null ? scope.texts.thanks : null);
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(radius),
      ),
      padding: EdgeInsets.symmetric(horizontal: paddingX, vertical: paddingY),
      child: Column(
        crossAxisAlignment: switch (align) {
          TextAlign.left => CrossAxisAlignment.start,
          TextAlign.right => CrossAxisAlignment.end,
          _ => CrossAxisAlignment.center,
        },
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (title != null)
            PopupV3RichText(
              scope.variables.rich(title),
              textAlign: align,
              style: popupV3TextStyle(
                box,
                color: titleColor ?? color,
                fontSize: titleSize,
                fontWeight: 600,
                height: 1.3,
              ),
            ),
          if (message != null) ...<Widget>[
            if (title != null) const SizedBox(height: 6),
            PopupV3RichText(
              scope.variables.rich(message),
              textAlign: align,
              style: popupV3TextStyle(
                box,
                color: color,
                fontSize: messageSize,
                fontWeight: 400,
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Шрифт полей форм: `fontSize` (13), не меньше 12.
double _inputFontSize(PopupV3Element element) =>
    math.max(element.number('fontSize', 13), 12);

/// Форма подписки: email, кнопка, согласие (обязательно), ошибка, экран успеха.
class PopupV3EmailCollector extends StatefulWidget {
  const PopupV3EmailCollector({super.key, required this.element});

  final PopupV3Element element;

  @override
  State<PopupV3EmailCollector> createState() => _PopupV3EmailCollectorState();
}

class _PopupV3EmailCollectorState extends State<PopupV3EmailCollector> {
  final TextEditingController _email = TextEditingController();
  bool _consent = false;
  bool _busy = false;
  bool _done = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    final element = widget.element;
    final scope = PopupV3Scope.of(context);
    final email = _email.text.trim();
    if (!_consent || !popupV3ValidEmail(email)) {
      setState(
        () => _error = scope.variables.apply(
          element.text('emailErrorMessage') ?? scope.texts.emailError,
        ),
      );
      return;
    }
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await scope.actions.subscribeEmail(
        email: email,
        consentFields: element.emailConsentFields,
        segmentId: element.segmentId('emailSegmentId'),
      );
      if (mounted) setState(() => _done = true);
    } catch (error) {
      if (mounted) setState(() => _error = scope.texts.sendError);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final element = widget.element;
    final scope = PopupV3Scope.of(context);
    final box = element.box;
    if (_done) {
      final align = element.value('emailSuccessAlign');
      return PopupV3Success(
        box: box,
        title: element.text('emailSuccessTitle'),
        message: element.text('emailSuccessMessage'),
        background: element.color('emailSuccessBg', '#ecfdf5'),
        color: element.color('emailSuccessColor', '#065f46'),
        titleColor: element.color('emailSuccessTitleColor', '#047857'),
        align: align == 'left'
            ? TextAlign.left
            : align == 'right'
            ? TextAlign.right
            : TextAlign.center,
        radius: element.number('emailSuccessRadius', 12),
        paddingX: element.number('emailSuccessPaddingX', 14),
        paddingY: element.number('emailSuccessPaddingY', 16),
        titleSize: element.number('emailSuccessTitleFontSize', 16),
        messageSize: element.number('emailSuccessFontSize', 13),
      );
    }
    final paddingY = element.number('buttonPaddingY', 10);
    final input = PopupV3Input(
      controller: _email,
      enabled: !_busy,
      keyboardType: TextInputType.emailAddress,
      placeholder: scope.variables.apply(
        element.text('emailPlaceholder') ?? scope.texts.email,
      ),
      style: popupV3TextStyle(
        box,
        color: element.color('emailInputColor', '#0f172a'),
        fontSize: _inputFontSize(element),
        fontWeight: 400,
        height: 1.25,
      ),
      background: element.color('emailInputBg', '#f8fafc'),
      borderColor: element.color('emailInputBorderColor', '#cbd5e1'),
      radius: element.number('emailInputRadius', 10),
      paddingY: paddingY,
      onSubmitted: (_) => _submit(),
    );
    final button = PopupV3SubmitButton(
      element: element,
      label: element.text('emailSubmitText') ?? scope.texts.subscribe,
      busy: _busy,
      onPressed: _submit,
    );
    final error = _error;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (element.emailInline)
          Row(
            children: <Widget>[
              Expanded(child: input),
              const SizedBox(width: 8),
              button,
            ],
          )
        else ...<Widget>[input, const SizedBox(height: 8), button],
        const SizedBox(height: 8),
        PopupV3Consent(
          label: element.emailConsentLabel ?? scope.texts.emailConsent,
          value: _consent,
          onChanged: (value) => setState(() => _consent = value),
          style: popupV3TextStyle(
            box,
            fontSize: 11,
            fontWeight: 400,
            height: 1.35,
          ),
        ),
        if (error != null) ...<Widget>[
          const SizedBox(height: 8),
          PopupV3Status(text: error, box: box),
        ],
      ],
    );
  }
}

/// Форма профиля: до 8 полей, согласие, ошибка, отправка в профиль и сегмент.
class PopupV3ProfileForm extends StatefulWidget {
  const PopupV3ProfileForm({super.key, required this.element});

  final PopupV3Element element;

  @override
  State<PopupV3ProfileForm> createState() => _PopupV3ProfileFormState();
}

class _PopupV3ProfileFormState extends State<PopupV3ProfileForm> {
  late final List<PopupV3FormField> _fields = widget.element.formFields;
  late final Map<String, TextEditingController> _controllers =
      <String, TextEditingController>{
        for (final field in _fields)
          if (field.kind != 'gender' && field.kind != 'birthday')
            field.id: TextEditingController(),
      };
  final Map<String, String> _choices = <String, String>{};
  bool _consent = false;
  bool _busy = false;
  bool _done = false;
  String? _error;

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  String _value(PopupV3FormField field) =>
      (_controllers[field.id]?.text ?? _choices[field.id] ?? '').trim();

  /// Данные формы или `null`, если обязательное поле пусто либо email или телефон не
  /// по формату.
  PopupV3ProfileSubmission? _collect() {
    final standard = <String, String>{};
    final custom = <String, String>{};
    for (final field in _fields) {
      final value = _value(field);
      if (value.isEmpty) {
        if (field.required) return null;
        continue;
      }
      if (field.kind == 'email' && !popupV3ValidEmail(value)) return null;
      if (field.kind == 'phone' && !popupV3ValidPhone(value)) return null;
      if (field.kind == 'custom') {
        if (field.propertyKey.isNotEmpty) custom[field.propertyKey] = value;
      } else {
        standard[field.kind] = value;
      }
    }
    return PopupV3ProfileSubmission(
      email: standard['email'],
      phone: standard['phone'],
      firstName: standard['first_name'],
      lastName: standard['last_name'],
      birthday: standard['birthday'],
      gender: standard['gender'],
      custom: custom,
      consentFields: _consent
          ? widget.element.formConsentFields
          : const <String>[],
      segmentId: widget.element.segmentId('formSegmentId'),
    );
  }

  Future<void> _submit() async {
    if (_busy) return;
    final scope = PopupV3Scope.of(context);
    final submission = _collect();
    if (submission == null) {
      setState(
        () => _error = scope.variables.apply(
          widget.element.text('formErrorMessage') ?? scope.texts.formError,
        ),
      );
      return;
    }
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await scope.actions.submitProfile(submission);
      if (mounted) setState(() => _done = true);
    } catch (error) {
      if (mounted) setState(() => _error = scope.texts.sendError);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pickDate(PopupV3FormField field) async {
    final now = DateTime.now();
    final current = DateTime.tryParse(_choices[field.id] ?? '');
    final picked = await showDatePicker(
      context: context,
      initialDate: current ?? DateTime(now.year - 25),
      firstDate: DateTime(1900),
      lastDate: now,
    );
    if (picked == null || !mounted) return;
    String two(int value) => value.toString().padLeft(2, '0');
    setState(
      () => _choices[field.id] =
          '${picked.year}-${two(picked.month)}-${two(picked.day)}',
    );
  }

  @override
  Widget build(BuildContext context) {
    final element = widget.element;
    final scope = PopupV3Scope.of(context);
    final box = element.box;
    if (_done) {
      return PopupV3Success(
        box: box,
        title: element.text('formSuccessTitle'),
        message: element.text('formSuccessMessage'),
      );
    }
    final inputStyle = popupV3TextStyle(
      box,
      color: element.color('formInputColor', '#0f172a'),
      fontSize: _inputFontSize(element),
      fontWeight: 400,
      height: 1.25,
    );
    final background = element.color('formInputBg', '#f8fafc');
    final borderColor = element.color('formInputBorderColor', '#cbd5e1');
    final radius = element.number('formInputRadius', 10);
    final paddingY = element.number('buttonPaddingY', 10);
    final labelStyle = popupV3TextStyle(box, fontSize: 11, fontWeight: 400);
    final consentFields = element.formConsentFields;
    final consentLabel = element.text('formConsentLabel');
    final error = _error;

    Widget choice(PopupV3FormField field, String value, String label) {
      final selected = _choices[field.id] == value;
      return Expanded(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _busy
              ? null
              : () => setState(
                  () => selected
                      ? _choices.remove(field.id)
                      : _choices[field.id] = value,
                ),
          child: Container(
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(radius),
              border: Border.all(
                color: selected ? inputStyle.color! : borderColor,
                width: selected ? 2 : 1,
              ),
            ),
            padding: EdgeInsets.symmetric(vertical: paddingY, horizontal: 12),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: inputStyle.copyWith(
                fontWeight: selected ? FontWeight.w600 : null,
              ),
            ),
          ),
        ),
      );
    }

    Widget input(PopupV3FormField field) {
      switch (field.kind) {
        case 'gender':
          return Row(
            children: <Widget>[
              choice(field, 'm', scope.texts.genderMale),
              const SizedBox(width: 8),
              choice(field, 'f', scope.texts.genderFemale),
            ],
          );
        case 'birthday':
          final value = _choices[field.id];
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _busy ? null : () => _pickDate(field),
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: background,
                borderRadius: BorderRadius.circular(radius),
                border: Border.all(color: borderColor),
              ),
              padding: EdgeInsets.symmetric(vertical: paddingY, horizontal: 12),
              child: Text(
                value ?? scope.variables.apply(field.placeholder),
                style: value == null
                    ? inputStyle.copyWith(
                        color: inputStyle.color?.withValues(alpha: 0.5),
                      )
                    : inputStyle,
              ),
            ),
          );
        default:
          return PopupV3Input(
            controller: _controllers[field.id]!,
            enabled: !_busy,
            keyboardType: switch (field.kind) {
              'email' => TextInputType.emailAddress,
              'phone' => TextInputType.phone,
              _ => TextInputType.text,
            },
            placeholder: scope.variables.apply(field.placeholder),
            style: inputStyle,
            background: background,
            borderColor: borderColor,
            radius: radius,
            paddingY: paddingY,
          );
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        for (final field in _fields) ...<Widget>[
          if (field.label.isNotEmpty) ...<Widget>[
            PopupV3RichText(<PopupMarkupSpan>[
              ...scope.variables.rich(field.label),
              if (field.required) ...scope.variables.rich(' *'),
            ], style: labelStyle),
            const SizedBox(height: 4),
          ],
          input(field),
          const SizedBox(height: 8),
        ],
        if (consentFields.isNotEmpty || consentLabel != null) ...<Widget>[
          PopupV3Consent(
            label: consentLabel ?? scope.texts.emailConsent,
            value: _consent,
            onChanged: (value) => setState(() => _consent = value),
            style: popupV3TextStyle(
              box,
              fontSize: 11,
              fontWeight: 400,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 8),
        ],
        if (error != null) ...<Widget>[
          PopupV3Status(text: error, box: box),
          const SizedBox(height: 8),
        ],
        PopupV3SubmitButton(
          element: element,
          label: element.text('formSubmitText') ?? scope.texts.send,
          busy: _busy,
          onPressed: _submit,
        ),
      ],
    );
  }
}

/// Мини-опрос NPS / CSAT / CES: вопрос, шкала, после оценки — комментарий и кнопка,
/// затем «спасибо». Ошибка отправки — текстом, можно отправить снова.
class PopupV3Survey extends StatefulWidget {
  const PopupV3Survey({super.key, required this.element});

  final PopupV3Element element;

  @override
  State<PopupV3Survey> createState() => _PopupV3SurveyState();
}

class _PopupV3SurveyState extends State<PopupV3Survey> {
  final TextEditingController _comment = TextEditingController();
  int? _rate;
  bool _busy = false;
  bool _done = false;
  String? _error;

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final rate = _rate;
    if (_busy || rate == null) return;
    final element = widget.element;
    final scope = PopupV3Scope.of(context);
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await scope.actions.review(
        kind: element.surveyType,
        code: element.string('surveyCampaignCode').trim(),
        rate: rate,
        comment: _comment.text,
      );
      if (mounted) setState(() => _done = true);
    } catch (error) {
      // Ответ сервера («Channel not found») — в скобках: без него не понять, что
      // не так с кампанией или каналом опроса.
      final reason = error is StoriesV3Exception ? error.message : null;
      if (mounted) {
        setState(
          () => _error = reason == null
              ? scope.texts.sendError
              : '${scope.texts.sendError} ($reason)',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final element = widget.element;
    final scope = PopupV3Scope.of(context);
    final box = element.box;
    if (_done) {
      return PopupV3RichText(
        scope.variables.rich(
          element.text('surveyThanksText') ?? scope.texts.thanks,
        ),
        style: popupV3TextStyle(box, fontWeight: 600),
      );
    }
    final question = element.text('surveyQuestion');
    final minLabel = element.text('surveyMinLabel');
    final maxLabel = element.text('surveyMaxLabel');
    final scaleBg = element.color('surveyScaleBg', '#f3f4f6');
    final scaleColor = element.color('surveyScaleColor', '#111827');
    final activeBg = element.color('surveyScaleActiveBg', '#2563eb');
    final activeColor = element.color('surveyScaleActiveColor', '#ffffff');
    final labelStyle = popupV3TextStyle(box, fontSize: 11);
    final error = _error;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (question != null) ...<Widget>[
          PopupV3RichText(
            scope.variables.rich(question),
            style: popupV3TextStyle(box, fontWeight: 600),
          ),
          const SizedBox(height: 10),
        ],
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: <Widget>[
            for (final rate in element.surveyScale)
              Semantics(
                button: true,
                selected: rate == _rate,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _busy ? null : () => setState(() => _rate = rate),
                  // Не шире своей цифры (не меньше 30): с `alignment` у Container
                  // ячейка растянулась бы на всю строку Wrap.
                  child: Container(
                    constraints: const BoxConstraints(minWidth: 30),
                    height: 30,
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    decoration: BoxDecoration(
                      color: rate == _rate ? activeBg : scaleBg,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      widthFactor: 1,
                      child: Text(
                        '$rate',
                        style: popupV3TextStyle(
                          box,
                          color: rate == _rate ? activeColor : scaleColor,
                          fontSize: 13,
                          fontWeight: 600,
                          height: 1,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
        if (minLabel != null || maxLabel != null) ...<Widget>[
          const SizedBox(height: 10),
          Opacity(
            opacity: 0.7,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  child: PopupV3RichText(
                    scope.variables.rich(minLabel),
                    style: labelStyle,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: PopupV3RichText(
                    scope.variables.rich(maxLabel),
                    style: labelStyle,
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
          ),
        ],
        if (_rate != null) ...<Widget>[
          const SizedBox(height: 10),
          PopupV3Input(
            controller: _comment,
            enabled: !_busy,
            maxLines: 3,
            minLines: 3,
            keyboardType: TextInputType.multiline,
            placeholder: scope.variables.apply(
              element.string('surveyCommentPlaceholder'),
            ),
            style: popupV3TextStyle(
              box,
              color: const Color(0xff111827),
              fontSize: 13,
              fontWeight: 400,
              height: 1.3,
            ),
            background: const Color(0xffffffff),
            borderColor: const Color(0xffcbd5e1),
            radius: 10,
            paddingY: 8,
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: PopupV3SubmitButton(
              element: element,
              label: element.text('surveySubmitText') ?? scope.texts.send,
              busy: _busy,
              onPressed: _submit,
            ),
          ),
        ],
        if (error != null) ...<Widget>[
          const SizedBox(height: 8),
          PopupV3Status(text: error, box: box),
        ],
      ],
    );
  }
}
