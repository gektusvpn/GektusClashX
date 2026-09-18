<div>

[**Russian**](README.md)

</div>

## GektusClashX

[![Downloads](https://img.shields.io/github/downloads/gektusvpn/GektusClashX/total?style=flat-square&logo=github)](https://github.com/gektusvpn/GektusClashX/releases/)
[![Last Version](https://img.shields.io/github/release/gektusvpn/GektusClashX/all.svg?style=flat-square)](https://github.com/gektusvpn/GektusClashX/releases/)
[![License](https://img.shields.io/github/license/gektusvpn/GektusClashX?style=flat-square)](LICENSE)

A fork of the multi-platform proxy client FlClash based on ClashMeta, simple and easy to use, open source and ad-free.

on Desktop:

<p style="text-align: center;">
    <img alt="desktop" src="snapshots/desktop.gif">
</p>

on Mobile:

<p style="text-align: center;">
    <img alt="mobile" src="snapshots/mobile.gif">
</p>

## Added Functionality

🛠️ Fixed default settings: process search mode on, TUN mode on, system proxy mode off, proxy list display mode set to 'list', changed camera behavior when adding a subscription via QR.

📱 **Android 120Hz Display Support:** Added support for high refresh rate displays (120Hz) on Android devices for smoother animations and scrolling.

🗑️ **Clear Application Data:** Added "Clear Data" button in Application Settings that removes all profiles from the profiles folder. Useful for troubleshooting or resetting the application.

🇷🇺 Added Russian language to the installer and redesigned the localization in the application.

✈️ Transmit HWID to the panel (Works only with <a href="https://github.com/remnawave/panel">Remnawave</a>).

💻 Home displays announcements, subscription details, and support contacts supplied by the provider through HTTP headers.

📺 Optimized controls for Android TV:

- Added a "Paste" button to the menu for adding a subscription via a link.
- Added a profile selection button.
- Added the ability to transfer a profile from the mobile app via a QR code.

🪪 Redesigned the profile card and the Home subscription section:

- Uses a traffic volume indicator with color change (not displayed if traffic is unlimited).
- Displays subscription expiration date (if the year is 2099, it displays "Your subscription is permanent").
- Support contacts and the Home support image can be supplied by the provider.
- The autoupdateinterval parameter for the profile is now correctly transmitted from the panel.

🌐 Added parsing of custom headers from the subscription page:

- `gektusclashx-announce-show`: controls the announcement on Home. `false`
  hides it; `true` or an omitted header shows it.

- gektusclashx-view: Configures the appearance of the proxy page obtained from the subscription.

|  Value   | Description                   | Possible values                   |
| :------: | ----------------------------- | --------------------------------- |
|  `type`  | Display mode                  | `list`,`tab`                      |
|  `sort`  | Sorting type                  | `none`,`delay`,`name`             |
| `layout` | Layout                        | `loose`,`standard`,`tight`        |
|  `icon`  | Icon style (for list display) | `none`,`icon`          |
|  `card`  | Card size                     | `expand`,`shrink`,`min`,`oneline` |

Usage:

```bash
    gektusclashx-view: type:list; sort:delay; layout:tight; icon:icon; card:shrink
```

- gektusclashx-custom: Controls when Locations view settings are applied.

|  Value   | Description                                                  |
| :------: | ------------------------------------------------------------ |
|  `add`   | View settings are applied only when the subscription is first added |
| `update` | View settings are applied every time the subscription is updated    |

Usage:

```bash
    gektusclashx-custom: update
```

- gektusclashx-servicename: Service name displayed at the top of the Home page.

Usage:

```bash
    gektusclashx-servicename: GektusClashX
```

- gektusclashx-servicelogo: Service logo displayed at the top of the Home page. Direct PNG and SVG links are supported.

Usage:

```bash
    gektusclashx-servicelogo: https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/svg/remnawave.svg
```

- gektusclashx-background: Sets a custom background image for the application. Provide a direct link to an image. Optionally append a comma and a transparency (visibility) value from 1 to 100 (higher = more visible image; omit it for the default dimmed look).

**Image Recommendations:**
  - Format: PNG, JPG, or WebP
  - Resolution: 1920x1080 or higher for desktop, 1080x1920 for mobile
  - File size: Keep under 2MB for better performance
  - Content: Use images with subtle patterns or gradients; avoid too bright or busy images
  - Contrast: Ensure good readability of text over the background

Usage:

```bash
    gektusclashx-background: https://example.com/background.jpg
    # with transparency (1-100, higher = more visible background):
    gektusclashx-background: https://example.com/background.jpg,30
```

- gektusclashx-settings: Manage application settings via header (with client-side override option). By default, all parameters are **disabled**. If you pass a parameter, it will be **enabled**. If you don't pass it - it stays **disabled**.

|   Parameter   | Description                                      | Default      |
| :-----------: | ------------------------------------------------ | :----------: |
|  `minimize`   | Minimize application on exit instead of closing  | ❌ Disabled  |
|   `autorun`   | Launch application on system startup             | ❌ Disabled  |
| `shadowstart` | Launch application minimized to tray             | ❌ Disabled  |
|  `autostart`  | Automatically start proxy on application launch  | ❌ Disabled  |
| `autoupdate`  | Automatically check for application updates      | ❌ Disabled  |
|  `openlogs`   | Enable logging (the "Logs" tab and core log stream) | ❌ Disabled |
|`closeconnections`| Drop active connections when switching proxy/mode | ❌ Disabled |

> Note: `closeconnections` is enabled by default in the app itself, but when `gektusclashx-settings` is used the state is set explicitly — if you don't pass the token, the option will be disabled.

On Android, automatic update checks are enabled by default unless the provider manages this setting. An available update is downloaded from GitHub Releases inside the app. The client verifies its SHA-256, package version, and signing certificate before opening the Android system installer.

On Windows and Linux, the update prompt downloads the matching GitHub Release asset for the current operating system and CPU architecture. On Linux it also distinguishes between AppImage, DEB, and RPM packages.

**Client-side override:** Users can enable "Override provider settings" in Application Settings to apply their local configuration instead of subscription settings. The matching toggles in settings (including "Logs" and "Close connections") are editable only when "Override provider settings" is enabled.

Usage:

```bash
    gektusclashx-settings: minimize, autorun, shadowstart, autostart, autoupdate, openlogs, closeconnections
```

- `gektusclashx-gh-proxy`: Base HTTPS proxy URL for GitHub access. The client appends the complete source URL in the format used by `gh-proxy`. It applies to the app's own update checks and downloads, APKs, checksums, and Zashboard. URLs inside the YAML configuration are left unchanged.

Usage:

```bash
    gektusclashx-gh-proxy: https://proxy.example.com/gh-proxy/TOKEN
```

- gektusclashx-globalmode: When set to `false`, hides all proxy-mode controls from the client (tray, proxies page, mode-switch widgets).

Usage:

```bash
    gektusclashx-globalmode: false
```

- gektusclashx-hex: Configures the app theme — primary color, scheme variant, and an optional "pure black" mode via `pureblack`. Variants: `tonalSpot`, `fidelity`, `monochrome`, `neutral`, `vibrant`, `expressive`, `content`, `rainbow`, `fruitSalad`.

Usage:

```bash
    gektusclashx-hex: FF5733
    gektusclashx-hex: FF5733:vibrant
    gektusclashx-hex: FF5733:vibrant:pureblack
```

Parameters can also be used separately:

```bash
    gektusclashx-hex: FF5733
    gektusclashx-hex: vibrant
    gektusclashx-hex: pureblack
```

- gektusclashx-androidsecure: Forces `mixed-port: 0` on Android devices only, even when a port (e.g. 7890) is active in the config.

Usage:

```bash
    gektusclashx-androidsecure: true
```

- gektusclashx-newdomain: Subscription domain migration. If the value differs from the current host of the profile link, on the next update the client automatically replaces the host in the subscription URL with the given one (path and query are preserved). Useful for moving the subscription page to a new domain without users reinstalling the profile.

Usage:

```bash
    gektusclashx-newdomain: new.example.com
```

- `gektusclashx-fallback`: Optional fallback domain used when a request to the profile's primary URL fails. The client replaces only the domain for that request, preserving the original scheme, path, token, and query parameters. The primary profile URL remains unchanged. A fallback learned from an earlier successful response is retained when the fallback endpoint omits this header.

Usage:

```bash
    gektusclashx-fallback: fallback.example.com
```

- gektusclashx-buyplan: Direct subscription purchase/renewal link. The "Renew" button is always displayed in the subscription card on Home. Tapping it opens the given link.

Usage:

```bash
    gektusclashx-buyplan: https://example.com/pay
```

- gektusclashx-buytraffic: Direct extra-traffic purchase link. The "Buy more traffic" button appears on Home when less than 10% of the traffic limit remains.

Usage:

```bash
    gektusclashx-buytraffic: https://example.com/buy-traffic
```

- `gektusclashx-channel-url`: Service channel URL. Adds a "Channel" action to the Links card on Home.
- `gektusclashx-status-url`: Server status page URL. Adds a "Server status" action.
- `gektusclashx-terms-url`: Terms of service URL. Adds a "Terms of service" action.
- `gektusclashx-privacy-url`: Privacy policy URL. Adds a "Privacy policy" action.

The Links card is hidden when none of these headers are present.

Usage:

```bash
    gektusclashx-channel-url: https://t.me/example
    gektusclashx-status-url: https://status.example.com
    gektusclashx-terms-url: https://example.com/terms
    gektusclashx-privacy-url: https://example.com/privacy
```

### YAML keys in the config

These keys are set directly in the subscription's YAML config (in the `proxy-groups` section), not in HTTP response headers.

- gektusclashx-override (inside the GLOBAL group): Set inside the `GLOBAL` proxy-group. With `gektusclashx-override: true` the client uses this group's proxy list and order as a "curated GLOBAL": in Global mode the Proxies screen shows only the `GLOBAL` group with exactly these entries in this order, and the service groups (used by rule mode) are hidden. Without the flag the behavior is unchanged — `GLOBAL` is auto-built by the core from all groups.

Usage:

```yaml
proxy-groups:
  - name: GLOBAL
    gektusclashx-override: true
    type: select
    proxies:
      - 🎲 Any available
      - 🔓 No VPN
      - 🌍 Main VPN
      - 🇩🇪 Germany
      - 🇫🇮 Finland
```

- description (on any proxy-group): A custom subtitle for the group on the Proxies screen. By default the group's type (Selector/URLTest/Fallback…) or the currently selected node is shown under its name; setting `description` displays the given text instead. Handy for clearer labels on nested groups.

Usage:

```yaml
proxy-groups:
  - name: 🌍 Main VPN
    type: select
    description: Auto-pick the best location
    proxies:
      - 🇩🇪 Germany
      - 🇫🇮 Finland
```

### Configuration Settings Override

By default, the following configuration parameters received from the subscription are **not overridden** by the client:

- `allow-lan` - Allow LAN connections
- `ipv6` - Enable IPv6 support
- `find-process-mode` - Process search mode
- `tun-stack` - TUN mode network stack
- `mixed-port` - Mixed port for HTTP/SOCKS proxy

**Client-side override:** Users can enable "Override provider settings" or "Override network settings" in Application Settings to apply their local configuration instead of subscription settings. This is useful when you need custom network settings.

## Application Usage

### Linux

⚠️ Before use, ensure the following dependencies are installed:

```bash
 sudo apt-get install libayatana-appindicator3-dev
 sudo apt-get install libkeybinder-3.0-dev
```

### Android

The following actions are supported:

```bash
 com.gektus.clashx.action.START

 com.gektus.clashx.action.STOP

 com.gektus.clashx.action.CHANGE
```

## Download

<a href="https://github.com/gektusvpn/GektusClashX/releases"><img alt="Get it on GitHub" src="snapshots/get-it-on-github.svg" width="200px"/></a>
<a href="https://apps.obtainium.imranr.dev/redirect?r=obtainium://app/%7B%22id%22%3A%22com.gektus.clashx%22%2C%22url%22%3A%22https%3A%2F%2Fgithub.com%2Fgektusvpn%2FGektusClashX%22%2C%22author%22%3A%22gektusvpn%22%2C%22name%22%3A%22GektusClashX%22%2C%22preferredApkIndex%22%3A0%2C%22additionalSettings%22%3A%22%7B%5C%22includePrereleases%5C%22%3Afalse%2C%5C%22fallbackToOlderReleases%5C%22%3Afalse%2C%5C%22filterReleaseTitlesByRegEx%5C%22%3A%5C%22%5C%22%2C%5C%22filterReleaseNotesByRegEx%5C%22%3A%5C%22%5C%22%2C%5C%22verifyLatestTag%5C%22%3Atrue%2C%5C%22sortMethodChoice%5C%22%3A%5C%22date%5C%22%2C%5C%22useLatestAssetDateAsReleaseDate%5C%22%3Afalse%2C%5C%22releaseTitleAsVersion%5C%22%3Afalse%2C%5C%22trackOnly%5C%22%3Afalse%2C%5C%22versionExtractionRegEx%5C%22%3A%5C%22%5C%22%2C%5C%22matchGroupToUse%5C%22%3A%5C%22%5C%22%2C%5C%22versionDetection%5C%22%3Atrue%2C%5C%22releaseDateAsVersion%5C%22%3Afalse%2C%5C%22useVersionCodeAsOSVersion%5C%22%3Afalse%2C%5C%22apkFilterRegEx%5C%22%3A%5C%22%5C%22%2C%5C%22invertAPKFilter%5C%22%3Afalse%2C%5C%22autoApkFilterByArch%5C%22%3Atrue%2C%5C%22appName%5C%22%3A%5C%22%5C%22%2C%5C%22appAuthor%5C%22%3A%5C%22%5C%22%2C%5C%22shizukuPretendToBeGooglePlay%5C%22%3Afalse%2C%5C%22allowInsecure%5C%22%3Afalse%2C%5C%22exemptFromBackgroundUpdates%5C%22%3Afalse%2C%5C%22skipUpdateNotifications%5C%22%3Afalse%2C%5C%22about%5C%22%3A%5C%22%5C%22%2C%5C%22refreshBeforeDownload%5C%22%3Afalse%2C%5C%22includeZips%5C%22%3Afalse%2C%5C%22zippedApkFilterRegEx%5C%22%3A%5C%22%5C%22%2C%5C%22includeTarballs%5C%22%3Afalse%2C%5C%22tarballedApkFilterRegEx%5C%22%3A%5C%22%5C%22%7D%22%2C%22overrideSource%22%3Anull%7D
"><img alt="Get it on Obtanium" src="snapshots/get-it-on-obtanium.svg" width="200px"/></a>

## Star

<p style="text-align: center;">
The easiest way to support the developers is to click the star (⭐) at the top of the page.<br>
If you want to support with a small donation, you can <a href="https://t.me/tribute/app?startapp=dtyh">do so here.</a>
</p>

**TON USDT:** `UQDSfrJ_k1BdsknhdR_zj4T3Is3OdMylD8PnDJ9mxO35i-TE`
