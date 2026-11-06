# Configuring GektusClashX

[← README](../README_EN.md) · [Русский](configuration.md)

A reference for subscription providers and users who need additional client settings.

- [Subscription HTTP headers](#subscription-http-headers)
- [YAML keys in the config](#yaml-keys-in-the-config)
- [Configuration settings override](#configuration-settings-override)
- [Application usage](#application-usage)

## Subscription HTTP headers

Providers supply these headers in the HTTP response when the client downloads a subscription.

### `gektusclashx-announce-show`

Controls the announcement on Home. `false`
hides it; `true` or an omitted header shows it.

### `gektusclashx-view`

Configures the appearance of the proxy page obtained from the subscription.

|  Value   | Description                   | Possible values                   |
| :------: | ----------------------------- | --------------------------------- |
|  `type`  | Display mode                  | `list`,`tab`                      |
|  `sort`  | Sorting type                  | `none`,`delay`,`name`             |
| `layout` | Layout                        | `loose`,`standard`,`tight`        |
|  `icon`  | Icon style (for list display) | `none`,`icon`          |
|  `card`  | Card size                     | `expand`,`shrink`,`min`,`oneline` |

On Android TV, only `card` is applied from this header. The `type`, `layout`,
`icon` and `sort` parameters do not change the TV tabs, three-column grid or sorting.

Usage:

```http
gektusclashx-view: type:list; sort:delay; layout:tight; icon:icon; card:shrink
```

### `gektusclashx-custom`

Controls when Locations view settings are applied.

|  Value   | Description                                                  |
| :------: | ------------------------------------------------------------ |
|  `add`   | View settings are applied only when the subscription is first added |
| `update` | View settings are applied every time the subscription is updated    |

Usage:

```http
gektusclashx-custom: update
```

### `gektusclashx-servicename`

Service name displayed at the top of the Home page.

Usage:

```http
gektusclashx-servicename: GektusClashX
```

### `gektusclashx-servicelogo`

Service logo displayed at the top of the Home page. Direct PNG and SVG links are supported.

Usage:

```http
gektusclashx-servicelogo: https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/svg/remnawave.svg
```

### `gektusclashx-background`

Sets a custom background image for the application. Provide a direct link to an image. Optionally append a comma and a transparency (visibility) value from 1 to 100 (higher = more visible image; omit it for the default dimmed look).

**Image recommendations:**

- Format: PNG, JPG, or WebP
- Resolution: 1920x1080 or higher for desktop, 1080x1920 for mobile
- File size: Keep under 2MB for better performance
- Content: Use images with subtle patterns or gradients; avoid too bright or busy images
- Contrast: Ensure good readability of text over the background

Usage:

```http
gektusclashx-background: https://example.com/background.jpg
# with transparency (1-100, higher = more visible background):
gektusclashx-background: https://example.com/background.jpg,30
```

### `gektusclashx-settings`

Manage application settings via header (with client-side override option). By default, all parameters are **disabled**. If you pass a parameter, it will be **enabled**. If you don't pass it - it stays **disabled**.

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

On new desktop installations, closing the window minimizes the application to
the tray by default. A saved user choice is preserved; the
`gektusclashx-settings` header still controls this explicitly with `minimize`.

On Android, automatic update checks are enabled by default unless the provider manages this setting. An available update is downloaded from GitHub Releases inside the app. The client verifies its SHA-256, package version, and signing certificate before opening the Android system installer.

On Windows and Linux, the update prompt downloads the matching GitHub Release asset for the current operating system and CPU architecture. On Linux it also distinguishes between AppImage, DEB, and RPM packages.

**Client-side override:** Users can enable "Override provider settings" in Application Settings to apply their local configuration instead of subscription settings. The matching toggles in settings (including "Logs" and "Close connections") are editable only when "Override provider settings" is enabled.

Usage:

```http
gektusclashx-settings: minimize, autorun, shadowstart, autostart, autoupdate, openlogs, closeconnections
```

### `gektusclashx-gh-proxy`

Base HTTPS proxy URL for GitHub access. The client appends the complete source URL in the format used by `gh-proxy`. It applies to the app's own update checks and downloads, APKs, checksums, and Zashboard. URLs inside the YAML configuration are left unchanged.

Usage:

```http
gektusclashx-gh-proxy: https://proxy.example.com/gh-proxy/TOKEN
```

### `gektusclashx-globalmode`

When set to `false`, hides all proxy-mode controls from the client (tray, proxies page, mode-switch widgets).

Usage:

```http
gektusclashx-globalmode: false
```

### `gektusclashx-hex`

Configures the app theme — primary color, scheme variant, and an optional "pure black" mode via `pureblack`. Variants: `tonalSpot`, `fidelity`, `monochrome`, `neutral`, `vibrant`, `expressive`, `content`, `rainbow`, `fruitSalad`.

Usage:

```http
gektusclashx-hex: FF5733
gektusclashx-hex: FF5733:vibrant
gektusclashx-hex: FF5733:vibrant:pureblack
```

Parameters can also be used separately:

```http
gektusclashx-hex: FF5733
gektusclashx-hex: vibrant
gektusclashx-hex: pureblack
```

Default theme colors:

| HEX | Color |
| :---: | --- |
| `795548` | Brown |
| `AECC8B` | Light green — default |
| `FFFF00` | Yellow |
| `BBC9CC` | Light blue grey |
| `ABD397` | Light green |
| `D8C0C3` | Light pink |
| `665390` | Deep purple |

### `gektusclashx-androidsecure`

Forces `mixed-port: 0` on Android devices only, even when a port (e.g. 7890) is active in the config.

Usage:

```http
gektusclashx-androidsecure: true
```

### `gektusclashx-newdomain`

Subscription domain migration. If the value differs from the current host of the profile link, on the next update the client automatically replaces the host in the subscription URL with the given one (path and query are preserved). Useful for moving the subscription page to a new domain without users reinstalling the profile.

Usage:

```http
gektusclashx-newdomain: new.example.com
```

### `gektusclashx-fallback`

Optional fallback domain used when a request to the profile's primary URL fails. The client replaces only the domain for that request, preserving the original scheme, path, token, and query parameters. The primary profile URL remains unchanged. A fallback learned from an earlier successful response is retained when the fallback endpoint omits this header.

Usage:

```http
gektusclashx-fallback: fallback.example.com
```

### `gektusclashx-buyplan`

Direct subscription purchase/renewal link. The "Renew" button is always displayed in the subscription card on Home. Tapping it opens the given link.

Usage:

```http
gektusclashx-buyplan: https://example.com/pay
```

### `gektusclashx-buytraffic`

Direct extra-traffic purchase link. The "Buy more traffic" button appears on Home when less than 10% of the traffic limit remains.

Usage:

```http
gektusclashx-buytraffic: https://example.com/buy-traffic
```

### `gektusclashx-news-url`

RSS 2.0, Atom or JSON Feed 1/1.1 URL. Adds the latest post between
Subscription and Support on Home. Open the full post in a bottom sheet, or use
"All news" to open a dedicated feed page with back navigation. Full posts on TV use a remote-friendly dialog. Omit the header
to hide the card. Example: `https://rss.gektus.link/`.
Cards include the cover image, title and first sentence after the heading.
The image sits beside the text on wide screens and above it on narrow screens.
Publication dates appear in the feed list and full post. The feed page shows the
source name and avatar, with its username and a Subscribe action for Telegram.
Trailing hashtags are hidden while reading but remain available for filtering.
The article sheet uses the post title
and places its rounded cover before the body text. Emoji use the bundled Twemoji font.
A self-hosted RSSHub, RSS-Bridge or any reachable feed server can be used. Feeds refresh every
15 minutes while displayed and can be refreshed manually from the list. Cached
posts appear before network requests, with expired data refreshed in the background.
A skeleton appears only when there is no cached feed. Posts remain available
offline, isolated by feed URL. Up to 100 entries from a
response of at most 2 MB are shown; this is not a full Telegram archive. HTML is
rendered as native widgets without JavaScript or embedded video players.

### `gektusclashx-news-tag`

Optional post filter, for example `GektusClashX`.
Home and "All news" then show only posts containing `#GektusClashX` in their text
or feed categories/tags. Matching is case-insensitive, with or without a leading
`#` in the header. Omit the header to show all posts. No matches shows an empty state.

### `gektusclashx-channel-url`

Service channel URL. Adds a "Channel" action to the Links card on Home.

### `gektusclashx-status-url`

Server status page URL. Adds a "Server status" action.

### `gektusclashx-terms-url`

Terms of service URL. Adds a "Terms of service" action.

### `gektusclashx-privacy-url`

Privacy policy URL. Adds a "Privacy policy" action.

The Links card is hidden when none of these headers are present.

Usage:

```http
gektusclashx-channel-url: https://t.me/example
gektusclashx-status-url: https://status.example.com
gektusclashx-terms-url: https://example.com/terms
gektusclashx-privacy-url: https://example.com/privacy
```

## YAML keys in the config

These keys are set directly in the subscription's YAML config (in the `proxy-groups` section), not in HTTP response headers.

### `gektusclashx-override` (inside the GLOBAL group)

Set inside the `GLOBAL` proxy-group. With `gektusclashx-override: true` the client uses this group's proxy list and order as a "curated GLOBAL": in Global mode the Proxies screen shows only the `GLOBAL` group with exactly these entries in this order, and the service groups (used by rule mode) are hidden. Without the flag the behavior is unchanged — `GLOBAL` is auto-built by the core from all groups.

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

### `description` (on any proxy-group)

A custom subtitle for the group on the Proxies screen. By default the group's type (Selector/URLTest/Fallback…) or the currently selected node is shown under its name; setting `description` displays the given text instead. Handy for clearer labels on nested groups.

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

## Configuration settings override

By default, the following configuration parameters received from the subscription are **not overridden** by the client:

- `allow-lan` - Allow LAN connections
- `ipv6` - Enable IPv6 support
- `find-process-mode` - Process search mode
- `tun-stack` - TUN mode network stack
- `mixed-port` - Mixed port for HTTP/SOCKS proxy

**Client-side override:** Users can enable "Override provider settings" or "Override network settings" in Application Settings to apply their local configuration instead of subscription settings. This is useful when you need custom network settings.

## Application usage

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
