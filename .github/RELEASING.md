# Выпуск GektusClashX

Основной release workflow собирает Android, Windows и Linux. macOS можно вернуть
в матрицу после настройки подписи и нотариализации Apple.

## Подпись Android

Создайте ключ один раз и храните его вместе с паролями в резервной копии. Все
следующие версии APK должны быть подписаны тем же ключом.

```bash
mkdir -p "$HOME/.local/share/gektusclashx-signing"
chmod 700 "$HOME/.local/share/gektusclashx-signing"

keytool -genkeypair -v \
  -keystore "$HOME/.local/share/gektusclashx-signing/gektusclashx-release.jks" \
  -alias gektusclashx \
  -keyalg RSA \
  -keysize 4096 \
  -validity 10000
```

Получите Base64-представление файла:

```bash
base64 -w 0 "$HOME/.local/share/gektusclashx-signing/gektusclashx-release.jks"
```

В `Settings → Secrets and variables → Actions → Secrets` репозитория добавьте:

- `KEYSTORE` — вывод команды `base64`;
- `KEY_ALIAS` — `gektusclashx` или выбранный при создании alias;
- `STORE_PASSWORD` — пароль хранилища;
- `KEY_PASSWORD` — пароль ключа.

`GOOGLE_SERVICES_JSON` нужен только при использовании Firebase. Без него сборка
работает без Firebase Analytics и Crashlytics.

## Публикация

Версия тега должна совпадать с версией без build number в `pubspec.yaml`.
Workflow проверяет это до запуска платформенных сборок.

```bash
git tag -a v0.5.0 -m "GektusClashX 0.5.0"
git push origin v0.5.0
```

После отправки тега GitHub Actions создаст Release и загрузит universal APK,
установщики и portable-архивы Windows, а также пакеты Linux.

Публикация в AUR и уведомление Telegram выключены по умолчанию. Для AUR создайте
Actions variable `PUBLISH_AUR=true` и добавьте secrets, используемые в
`build.yaml`.

Для уведомлений о релизах в Telegram:

1. Создайте бота через [@BotFather](https://t.me/BotFather) и добавьте его в
   нужную группу, супергруппу или канал. В канале бот должен быть администратором
   с правом публикации сообщений.
2. Отправьте в группе сообщение `/start@имя_бота`, затем получите идентификатор
   чата через Bot API `getUpdates`. Идентификатор группы отрицательный, а у
   супергруппы обычно начинается с `-100`.
3. В `Settings → Secrets and variables → Actions → Secrets` добавьте
   `TELEGRAM_BOT_TOKEN` и `TELEGRAM_CHAT_ID`.
4. В `Settings → Secrets and variables → Actions → Variables` добавьте
   `SEND_TELEGRAM=true`.

`TELEGRAM_CHAT_ID` универсален: в нём можно указать идентификатор личного чата,
группы, супергруппы или канала. Workflow отправит уведомление после успешной
сборки и публикации GitHub Release. Повторно отправить уведомление для уже
существующего релиза можно вручную через workflow `Publish release`.

## Отладка на Android

Debug-вариант использует application ID `com.gektus.clashx.debug` и отображается
как `GektusClashX Debug`, поэтому его можно установить рядом с релизной версией.
После установки Android SDK, включения USB debugging и подключения устройства:

```bash
flutter devices
flutter run -d <device-id>
```

Если Flutter не нашёл SDK автоматически, укажите его каталог один раз:

```bash
flutter config --android-sdk "$HOME/Android/Sdk"
```
