# Публикация на pub.dev

Пакет `rees46_sdk` публикуется на pub.dev из этого
репозитория (`rees46/flutter-sdk`).

Схема — **token-based на push в master**: merge в master → `Deploy` →
publish.

## Один раз: аккаунты и первый релиз

1. (Рекомендуется) Создать verified publisher `rees46.com` и сделать его
   владельцем пакета. pub.dev → Create publisher → подтверждение домена
   через DNS TXT.
2. Застолбить имя первым ручным релизом (автопубликацию pub.dev можно
   включить только для уже существующего пакета):
   ```bash
   flutter pub publish --dry-run   # 0 ошибок по метаданным
   flutter pub publish             # интерактивный логин Google
   ```
   `example/` не публикуется (`publish_to: none`).

## Настройка CI

1. Локально получить credentials публикующего аккаунта: один раз
   `flutter pub publish` → файл `~/.config/dart/pub-credentials.json`.
2. Содержимое файла → **Secret** `PUB_DEV_CREDENTIALS`.

`deploy.yaml` на каждый push в master:
- читает имя и версию из `pubspec.yaml`;
- проверяет через pub.dev API, не опубликована ли уже эта версия;
- если версия новая — пишет credentials в `~/.config/dart/pub-credentials.json`
  и публикует `flutter pub publish --force`. Пуши без бампа версии — скип.

## Релиз

1. Поднять `version:` в `pubspec.yaml`, обновить `CHANGELOG.md`.
2. PR → merge в master.
3. `Deploy` видит новую версию (нет на pub.dev) → публикует пакет.

## Альтернатива: OIDC (на будущее)

Безопаснее (без долгоживущих секретов), но требует релизов по git-тегам:
pub.dev → пакет → Admin → Automated publishing → GitHub Actions, репозиторий +
tag pattern `v{{version}}`; в CI — workflow с `permissions: id-token: write` и
триггером `on: push: tags`.
