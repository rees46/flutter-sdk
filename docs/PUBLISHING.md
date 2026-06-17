# Публикация на pub.dev

Пакет `rees46_sdk` публикуется на pub.dev из этого репозитория
(`rees46/flutter-sdk`).

Схема — **OIDC (automated publishing)**: pub.dev доверяет этому GitHub-репо,
долгоживущие секреты/токены публикации не нужны. Официальная дока:
<https://dart.dev/tools/pub/automated-publishing>.

Ключевое из доки: публикация по OIDC разрешена, только когда workflow запущен
**push'ем git-тега**, и автопубликацию можно включить лишь для **уже
существующего** пакета (первую версию заливают вручную).

## Один раз: со стороны владельца pub.dev-аккаунта

1. (По желанию) Verified publisher: подтвердить домен `rees46.com` в Google
   Search Console (DNS TXT) и создать publisher на pub.dev. Для самой
   публикации не обязательно. См. <https://dart.dev/tools/pub/verified-publishers>.
2. Застолбить имя первым ручным релизом (локальный логин, ничего никому не
   передаётся):
   ```bash
   flutter pub publish        # создаст пакет rees46_sdk
   ```
   `example/` не публикуется (`publish_to: none`).
3. Включить автопубликацию: pub.dev → пакет → Admin → Automated publishing →
   GitHub Actions; **Repository:** `rees46/flutter-sdk`; **Tag pattern:**
   `v{{version}}`.

## Один раз: со стороны репозитория (CI)

Автотегировщику (`deploy.yaml`) нужен токен GitHub App для пуша тега — тег от
`GITHUB_TOKEN` по дизайну не триггерит другой workflow. Задать в репозитории:
- **Variable** `VERSIONER_ID`
- **Secret** `VERSIONER_SECRET`

(источник — versioner-app). Пока они не заданы, автотегирование скипается, а
`Deploy` остаётся зелёным (sync продолжает работать).

## Как работает релиз

1. Поднять `version:` в `pubspec.yaml`, обновить `CHANGELOG.md`, смержить в
   master.
2. `Deploy` (`deploy.yaml`) видит новую версию → создаёт и пушит тег
   `v<version>` app-токеном.
3. Тег запускает `publish.yaml` → `flutter pub publish --force` по OIDC.
   Если версия уже на pub.dev — шаг пропускается (no-op).

Тег всегда выводится из версии в pubspec, поэтому версия и тег синхронизированы
по построению; pub.dev дополнительно проверяет их совпадение.
