<div>

[**English**](README_EN.md)

</div>

## GektusClashX

[![Downloads](https://img.shields.io/github/downloads/gektusvpn/GektusClashX/total?style=flat-square&logo=github)](https://github.com/gektusvpn/GektusClashX/releases/)
[![Last Version](https://img.shields.io/github/release/gektusvpn/GektusClashX/all.svg?style=flat-square)](https://github.com/gektusvpn/GektusClashX/releases/)
[![License](https://img.shields.io/github/license/gektusvpn/GektusClashX?style=flat-square)](LICENSE)

Форк многоплатформенного прокси-клиента FlClash на основе ClashMeta, простого и удобного в использовании, с открытым исходным кодом и без рекламы.

Десктопный вид:

<p style="text-align: center;">
    <img alt="desktop" src="snapshots/desktop.gif">
</p>

Мобильный вид:

<p style="text-align: center;">
    <img alt="mobile" src="snapshots/mobile.gif">
</p>

## Добавленный функционал

🛠️ Исправлены стандартные настройки: режим поиска процессов вкл, режим tun вкл, режим системного прокси выкл, режим отображения списка прокси list, изменена работа камеры при добавлении подписки через QR.

📱 **Поддержка 120Гц дисплеев на Android:** Добавлена поддержка высокочастотных дисплеев (120Гц) на устройствах Android для более плавных анимаций и прокрутки.

🗑️ **Очистка данных приложения:** Добавлена кнопка "Очистить данные" в настройках приложения, которая удаляет все профили из папки profiles. Полезно для устранения неполадок или сброса приложения.

🇷🇺 Добавлен русский язык в установщик и переработана локаль в приложении

✈️ Передача HWID в панель (Работает только с <a href="https://github.com/remnawave/panel">Remnawave</a>)

💻 На главной странице отображаются анонс, сведения о подписке и контакты поддержки, переданные провайдером в HTTP-заголовках.

📺 Оптимизация управления на Android TV

- добавлена кнопка "Вставить" для меню добавления подписки по ссылке
- добавлена кнопка выбора профиля
- добавлена передача профиля с мобильного приложения через QR-код

💻 macOS - приложение в нативной строке состояния (status bar) вместо оконного интерфейса.

🪪 Переработаны карточка профиля и блок подписки на главной:

- Используется индикатор объёма трафика с изменением цвета (не отображается, если трафик неограничен).
- Отображается дата окончания подписки (если год — 2099, выводится «Ваша подписка вечная»).
- Контакты поддержки и изображение блока поддержки на главной задаются провайдером.
- Параметр autoupdateinterval для профиля теперь корректно передаётся с панели.

### Добавлен парсинг кастомных хедеров со страницы подписки:

<details>
<summary><strong>gektusclashx-announce-show</strong></summary>

Управляет отображением анонса на главной странице. Значение `false` скрывает
анонс; `true` или отсутствие заголовка показывает его.
</details>

<details>
<summary><strong>gektusclashx-view</strong></summary>

Настраивает вид страницы прокси, полученным с подписки

| Значение | Описание                            | Возможные значения                |
| :------: | ----------------------------------- | --------------------------------- |
|  `type`  | Режим отображения                   | `list`,`tab`                      |
|  `sort`  | Тип сортировки                      | `none`,`delay`,`name`             |
| `layout` | Макет                               | `loose`,`standard`,`tight`        |
|  `icon`  | Стиль иконок (для list-отображения) | `none`,`icon`          |
|  `card`  | Размер карточки                     | `expand`,`shrink`,`min`,`oneline` |

Использование:

```bash
gektusclashx-view: type:list; sort:delay; layout:tight; icon:icon; card:shrink
```
</details>

<details>
<summary><strong>gektusclashx-custom</strong></summary>

Управляет применением настроек вида раздела «Локации»

| Значение | Описание                                                |
| :------: | ------------------------------------------------------- |
|  `add`   | Настройки вида применяются только при первом добавлении подписки |
| `update` | Настройки вида применяются при каждом обновлении подписки    |

Использование:

```bash
gektusclashx-custom: update
```
</details>

<details>
<summary><strong>gektusclashx-servicename</strong></summary>

Название сервиса, отображаемое в верхней части главной страницы.

Использование:

```bash
gektusclashx-servicename: GektusClashX
```
</details>

<details>
<summary><strong>gektusclashx-servicelogo</strong></summary>

Логотип сервиса в верхней части главной страницы. Поддерживаются прямые ссылки на PNG и SVG.

Использование:

```bash
gektusclashx-servicelogo: https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/svg/remnawave.svg
```
</details>

<details>
<summary><strong>gektusclashx-background</strong></summary>

Устанавливает пользовательское фоновое изображение для приложения. Укажите прямую ссылку на изображение. Опционально через запятую можно задать прозрачность (видимость) фона от 1 до 100 (чем больше — тем заметнее изображение; без параметра — стандартный приглушённый вид).

**Рекомендации для изображения:**
- Формат: PNG, JPG или WebP
- Разрешение: 1920x1080 или выше для десктопа, 1080x1920 для мобильных устройств
- Размер файла: Желательно до 2МБ для лучшей производительности
- Содержание: Используйте изображения с тонкими узорами или градиентами; избегайте слишком ярких или загруженных изображений
- Контраст: Обеспечьте хорошую читаемость текста на фоне

Использование:

```bash
gektusclashx-background: https://example.com/background.jpg
# с прозрачностью (1-100, выше = заметнее фон):
gektusclashx-background: https://example.com/background.jpg,30
```
</details>

<details>
<summary><strong>gektusclashx-settings</strong></summary>

Управление настройками приложения через хедер (с возможностью переопределения со стороны клиента). По умолчанию все параметры выключены. Если вы передаёте параметр, то он будет включён. Если не передаёте — останется выключенным.

|   Параметр    | Описание                                                 | По умолчанию |
| :-----------: | -------------------------------------------------------- | :----------: |
|  `minimize`   | Сворачивать приложение при выходе вместо закрытия        | ❌ Выкл      |
|   `autorun`   | Запускать приложение при старте системы                  | ❌ Выкл      |
| `shadowstart` | Запускать приложение свернутым в трей                    | ❌ Выкл      |
|  `autostart`  | Автоматически запускать прокси при запуске приложения    | ❌ Выкл      |
| `autoupdate`  | Автоматически проверять обновления приложения            | ❌ Выкл      |
|  `openlogs`   | Включить логирование (вкладка «Логи» и стрим логов ядра) | ❌ Выкл      |
|`closeconnections`| Разрывать активные соединения при смене прокси/режима | ❌ Выкл      |

> Примечание: `closeconnections` в самом приложении по умолчанию включён, но при использовании `gektusclashx-settings` состояние задаётся явно — если не передать токен, опция будет выключена.

На Android автоматическая проверка обновлений включена по умолчанию, если этой настройкой не управляет провайдер. Найденное обновление загружается из GitHub Releases внутри приложения. Перед установкой клиент проверяет SHA-256, версию пакета и сертификат подписи, после чего открывает системный установщик Android.

На Windows и Linux кнопка в окне обновления скачивает из GitHub Releases файл для текущей системы и архитектуры. Для Linux также учитываются AppImage, DEB и RPM.

Переопределение на стороне клиента: Пользователи могут включить «Переопределить настройки провайдера» в настройках приложения, чтобы применять свою локальную конфигурацию вместо настроек из подписки. Соответствующие переключатели в настройках (в т.ч. «Логи» и «Разрывать соединения») редактируются только при включённом «Переопределить настройки провайдера».

Использование:

```bash
gektusclashx-settings: minimize, autorun, shadowstart, autostart, autoupdate, openlogs, closeconnections
```
</details>

<details>
<summary><strong>gektusclashx-gh-proxy</strong></summary>

Базовый HTTPS-URL прокси для доступа к GitHub. Клиент добавляет к этому URL полную исходную ссылку в формате, который использует `gh-proxy`. Прокси применяется к запросам самого приложения: проверке и загрузке обновлений, APK, контрольных сумм и Zashboard. URL внутри YAML-конфига не изменяются.

Использование:

```bash
gektusclashx-gh-proxy: https://proxy.example.com/gh-proxy/TOKEN
```
</details>

<details>
<summary><strong>gektusclashx-globalmode</strong></summary>

Данный хедер при FALSE позволяет скрыть все настройки режима прокси из клиента (трей, страница прокси, виджеты смены режима)

Использование:
```bash
gektusclashx-globalmode: false
```
</details>

<details>
<summary><strong>gektusclashx-hex</strong></summary>

Данный хедер позволяет настроить тему в приложении, возможность передать основной цвет, вариант, и выбрать "Чисто черный режим" параметром `pureBlack`

Варианты:
|   Вариант    | Название|
| :-----------: | ------ |
|  `tonalSpot`   | Тональный акцент|
|   `fidelity`   | Точная передача |
| `monochrome` | Монохром |
|  `neutral`  | Нейтральные |
| `vibrant`  | Яркие |
| `expressive`  | Экспрессивные |
| `content`  | Контентная тема |
| `rainbow`  | Радужные |
| `fruitSalad`  | Фруктовый микс |

Использование:
```bash
gektusclashx-hex: FF5733
gektusclashx-hex: FF5733:vibrant
gektusclashx-hex: FF5733:vibrant:pureblack
```
Так-же можно параметры использовать по отдельности:
```bash
gektusclashx-hex: FF5733
gektusclashx-hex: vibrant
gektusclashx-hex: pureblack
```
HEX-коды стандартных тем:
|   HEX    | ЦВЕТ|
| :-----------: | ------ |
|  `795548`   | Brown (Коричневый)|
|   `AECC8B`   | Светло-зелёный — по умолчанию |
| `FFFF00` | Yellow (Желтый) |
|  `BBC9CC`  | Light Blue Grey (Светло-серо-голубой) |
| `ABD397`  | Light Green (Светло-зеленый) |
| `D8C0C3`  | Light Pink (Светло-розовый) |
| `665390`  | Deep Purple (Темно-фиолетовый) |
</details>

<details>
<summary><strong>gektusclashx-androidsecure</strong></summary>

Данный хедер позволяет принудительно включить Mixed-port:0 только на Андроид-девайсах, при активном 7890 (например) в конфиге.

Использование:
```bash
gektusclashx-androidsecure: true
```
</details>

<details>
<summary><strong>gektusclashx-newdomain</strong></summary>

Миграция домена подписки. Если значение отличается от текущего хоста ссылки профиля, при следующем обновлении клиент автоматически заменит хост в URL подписки на указанный (путь и параметры сохраняются). Удобно при переезде страницы подписки на новый домен без переустановки профиля у пользователей.

Использование:
```bash
gektusclashx-newdomain: new.example.com
```
</details>

<details>
<summary><strong>gektusclashx-fallback</strong></summary>

Необязательный резервный домен подписки. Клиент всегда сначала запрашивает основной URL профиля и обращается к резервному только при ошибке запроса. Для резервного запроса заменяется только домен: схема, путь, токен и query-параметры сохраняются из основной ссылки. Основной URL профиля не изменяется. Если резервный сервер не вернул этот заголовок в ответе, ранее сохранённый fallback продолжит использоваться.

Использование:
```bash
gektusclashx-fallback: fallback.example.com
```
</details>

<details>
<summary><strong>gektusclashx-buyplan</strong></summary>

Прямая ссылка на оплату/продление подписки. Кнопка «Продлить» всегда отображается в карточке подписки на главной странице. По нажатию открывается переданная ссылка.

Использование:
```bash
gektusclashx-buyplan: https://example.com/pay
```
</details>

<details>
<summary><strong>gektusclashx-buytraffic</strong></summary>

Прямая ссылка на докупку трафика. Кнопка «Докупить трафик» появляется на главной странице, когда остаётся меньше 10% лимита трафика.

Использование:
```bash
gektusclashx-buytraffic: https://example.com/buy-traffic
```
</details>

<details>
<summary><strong>gektusclashx-channel-url</strong></summary>

Ссылка на канал сервиса. Если заголовок передан, на главной странице в блоке «Ссылки» появляется кнопка «Канал».

```bash
gektusclashx-channel-url: https://t.me/example
```
</details>

<details>
<summary><strong>gektusclashx-status-url</strong></summary>

Ссылка на страницу состояния серверов. Если заголовок передан, на главной странице появляется кнопка «Статус серверов».

```bash
gektusclashx-status-url: https://status.example.com
```
</details>

<details>
<summary><strong>gektusclashx-terms-url</strong></summary>

Ссылка на пользовательское соглашение. Если заголовок передан, на главной странице появляется соответствующая кнопка.

```bash
gektusclashx-terms-url: https://example.com/terms
```
</details>

<details>
<summary><strong>gektusclashx-privacy-url</strong></summary>

Ссылка на политику конфиденциальности. Если заголовок передан, на главной странице появляется соответствующая кнопка. Если ни один из четырёх заголовков ссылок не задан, блок «Ссылки» скрыт целиком.

```bash
gektusclashx-privacy-url: https://example.com/privacy
```
</details>

### YAML-ключи в конфиге

Эти ключи указываются не в HTTP-заголовках ответа, а прямо в YAML-конфиге подписки (в секции `proxy-groups`).

<details>
<summary><strong>gektusclashx-override</strong> (в группе GLOBAL)</summary>

Указывается внутри прокси-группы `GLOBAL`. При `gektusclashx-override: true` клиент берёт список и порядок прокси из этой группы как «курированный GLOBAL»: в режиме «Глобальный» в разделе Proxies показывается только группа `GLOBAL` ровно с этими элементами и в этом порядке, а сервисные группы (нужные для rule-режима) скрываются. Без флага поведение прежнее — `GLOBAL` формируется ядром автоматически из всех групп.

Использование:
```yaml
proxy-groups:
  - name: GLOBAL
    gektusclashx-override: true
    type: select
    proxies:
      - 🎲 Любой доступный
      - 🔓 Без VPN
      - 🌍 Основной VPN
      - 🇩🇪 Германия
      - 🇫🇮 Финляндия
```
</details>

<details>
<summary><strong>description</strong> (в любой прокси-группе)</summary>

Кастомный подзаголовок группы в разделе Proxies. По умолчанию под названием группы показывается её тип (Selector/URLTest/Fallback…) либо текущий выбранный узел; если задать `description`, вместо этого выводится указанный текст. Удобно для понятных подписей вложенных групп.

Использование:
```yaml
proxy-groups:
  - name: 🌍 Основной VPN
    type: select
    description: Авто-выбор лучшей локации
    proxies:
      - 🇩🇪 Германия
      - 🇫🇮 Финляндия
```
</details>

### Переопределение настроек конфигурации
По умолчанию следующие параметры конфигурации, полученные от подписки, **не переопределяются** клиентом:

- `allow-lan` - Разрешить подключения из локальной сети
- `ipv6` - Включить поддержку IPv6
- `find-process-mode` - Режим поиска процессов
- `tun-stack` - Сетевой стек режима TUN
- `mixed-port` - Смешанный порт для HTTP/SOCKS прокси

**Переопределение на стороне клиента:** Пользователи могут включить "Переопределить настройки провайдера" или "Переопределить сетевые настройки" в настройках приложения, чтобы применять свою локальную конфигурацию вместо настроек из подписки. Это полезно, когда нужны кастомные сетевые настройки.

## Использование

### Linux

⚠️ Перед использованием убедитесь, что установлены следующие зависимости:

```bash
 sudo apt-get install libayatana-appindicator3-dev
 sudo apt-get install libkeybinder-3.0-dev
```

### Android

Поддерживаются следующие действия:

```bash
 com.gektus.clashx.action.START

 com.gektus.clashx.action.STOP

 com.gektus.clashx.action.CHANGE
```

## Скачать

<a href="https://github.com/gektusvpn/GektusClashX/releases"><img alt="Get it on GitHub" src="snapshots/get-it-on-github.svg" width="200px"/></a>
<a href="https://apps.obtainium.imranr.dev/redirect?r=obtainium://app/%7B%22id%22%3A%22com.gektus.clashx%22%2C%22url%22%3A%22https%3A%2F%2Fgithub.com%2Fgektusvpn%2FGektusClashX%22%2C%22author%22%3A%22gektusvpn%22%2C%22name%22%3A%22GektusClashX%22%2C%22preferredApkIndex%22%3A0%2C%22additionalSettings%22%3A%22%7B%5C%22includePrereleases%5C%22%3Afalse%2C%5C%22fallbackToOlderReleases%5C%22%3Afalse%2C%5C%22filterReleaseTitlesByRegEx%5C%22%3A%5C%22%5C%22%2C%5C%22filterReleaseNotesByRegEx%5C%22%3A%5C%22%5C%22%2C%5C%22verifyLatestTag%5C%22%3Atrue%2C%5C%22sortMethodChoice%5C%22%3A%5C%22date%5C%22%2C%5C%22useLatestAssetDateAsReleaseDate%5C%22%3Afalse%2C%5C%22releaseTitleAsVersion%5C%22%3Afalse%2C%5C%22trackOnly%5C%22%3Afalse%2C%5C%22versionExtractionRegEx%5C%22%3A%5C%22%5C%22%2C%5C%22matchGroupToUse%5C%22%3A%5C%22%5C%22%2C%5C%22versionDetection%5C%22%3Atrue%2C%5C%22releaseDateAsVersion%5C%22%3Afalse%2C%5C%22useVersionCodeAsOSVersion%5C%22%3Afalse%2C%5C%22apkFilterRegEx%5C%22%3A%5C%22%5C%22%2C%5C%22invertAPKFilter%5C%22%3Afalse%2C%5C%22autoApkFilterByArch%5C%22%3Atrue%2C%5C%22appName%5C%22%3A%5C%22%5C%22%2C%5C%22appAuthor%5C%22%3A%5C%22%5C%22%2C%5C%22shizukuPretendToBeGooglePlay%5C%22%3Afalse%2C%5C%22allowInsecure%5C%22%3Afalse%2C%5C%22exemptFromBackgroundUpdates%5C%22%3Afalse%2C%5C%22skipUpdateNotifications%5C%22%3Afalse%2C%5C%22about%5C%22%3A%5C%22%5C%22%2C%5C%22refreshBeforeDownload%5C%22%3Afalse%2C%5C%22includeZips%5C%22%3Afalse%2C%5C%22zippedApkFilterRegEx%5C%22%3A%5C%22%5C%22%2C%5C%22includeTarballs%5C%22%3Afalse%2C%5C%22tarballedApkFilterRegEx%5C%22%3A%5C%22%5C%22%7D%22%2C%22overrideSource%22%3Anull%7D
"><img alt="Get it on Obtanium" src="snapshots/get-it-on-obtanium.svg" width="200px"/></a>

## Star

<p style="text-align: center;">
Самый простой способ поддержать разработчиков — нажать на звездочку (⭐) в верхней части страницы.<br>
Если хотите поддержать копеечкой, то можно <a href="https://t.me/tribute/app?startapp=dtyh">сделать это тут.</a></p>

**TON USDT:** `UQDSfrJ_k1BdsknhdR_zj4T3Is3OdMylD8PnDJ9mxO35i-TE`
