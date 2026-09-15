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

Публикация в AUR и уведомление Telegram выключены по умолчанию. Для их включения
создайте Actions variables `PUBLISH_AUR=true` и `SEND_TELEGRAM=true`, затем
добавьте соответствующие secrets, используемые в `build.yaml`.

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
