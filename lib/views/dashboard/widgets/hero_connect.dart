import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:gektusclashx/common/common.dart';
import 'package:gektusclashx/enum/enum.dart';
import 'package:gektusclashx/models/models.dart';
import 'package:gektusclashx/providers/providers.dart';
import 'package:gektusclashx/state.dart';
import 'package:gektusclashx/views/profiles/add_profile.dart';
import 'package:gektusclashx/widgets/widgets.dart';
import 'package:intl/intl.dart';

String _formatBytes(int bytes) {
  final units = [
    appLocalizations.byteUnit,
    appLocalizations.kilobyteUnit,
    appLocalizations.megabyteUnit,
    appLocalizations.gigabyteUnit,
    appLocalizations.terabyteUnit,
  ];
  if (bytes <= 0) return '0 ${units.first}';
  var value = bytes.toDouble();
  var i = 0;
  while (value >= 1024 && i < units.length - 1) {
    value /= 1024;
    i++;
  }
  return '${value.toStringAsFixed(i == 0 ? 0 : 2)} ${units[i]}';
}

String? _decodeAnnounce(String? value) {
  if (value == null) return null;
  final trimmed = value.trim();
  if (trimmed.isEmpty) return null;
  final decoded = _decodeBase64(trimmed);
  if (decoded == null || decoded.trim().isEmpty) return null;
  return decoded.trim();
}

String? _decodeBase64(String? value) {
  if (value == null || value.trim().isEmpty) return null;
  var text = value.trim();
  if (text.startsWith('base64:')) text = text.substring(7).trim();
  if (text.isEmpty) return null;
  try {
    final normalized = base64.normalize(text);
    final decoded = utf8.decode(base64.decode(normalized)).trim();
    return decoded.isEmpty ? null : decoded;
  } catch (_) {
    return value.trim().isEmpty ? null : value.trim();
  }
}

class HeroConnect extends ConsumerWidget {
  const HeroConnect({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(startButtonSelectorStateProvider);
    if (!state.hasProfile) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: _EmptyHero(),
      );
    }

    final isReady = state.isInit;
    final profile = ref.watch(currentProfileProvider);
    final headers = profile?.providerHeaders ?? {};
    final serviceName =
        _decodeBase64(headers['gektusclashx-servicename']) ?? appName;
    final logoUrl = _decodeBase64(headers['gektusclashx-servicelogo']);
    final showAnnounce =
        headers['gektusclashx-announce-show']?.trim().toLowerCase() != 'false';
    final announce = showAnnounce ? _decodeAnnounce(headers['announce']) : null;
    final sub = profile?.subscriptionInfo;
    final hasSub = sub != null && (sub.total > 0 || sub.expire > 0);

    final buyPlanUrl = headers['gektusclashx-buyplan'];
    final buyTrafficUrl = headers['gektusclashx-buytraffic'];
    var showBuyTraffic = false;
    if (sub != null) {
      if (buyTrafficUrl != null && buyTrafficUrl.isNotEmpty && sub.total > 0) {
        final used = sub.upload + sub.download;
        showBuyTraffic = (sub.total - used) < sub.total * 0.1;
      }
    }
    final supportUrl = headers['support-url']?.trim();
    final supportEmail = headers['support-email']?.trim();
    final supportImageUrl = headers['gektusclashx-support-image']?.trim();
    final hasSupport = (supportUrl?.isNotEmpty ?? false) ||
        (supportEmail?.isNotEmpty ?? false);

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Column(
              children: [
                _Logo(logoUrl: logoUrl),
                const SizedBox(height: 16),
                Text(
                  serviceName,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (announce != null && announce.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _AnnounceBanner(text: announce),
                ],
                if (hasSub) ...[
                  const SizedBox(height: 18),
                  _SubscriptionCard(
                    sub: sub,
                    isUpdating: profile?.isUpdating ?? false,
                    onUpdate: profile == null
                        ? null
                        : () =>
                            globalState.appController.updateProfile(profile),
                    buyPlanUrl: buyPlanUrl,
                  ),
                ],
                if (hasSupport) ...[
                  const SizedBox(height: 12),
                  _SupportCard(
                    supportUrl: supportUrl,
                    supportEmail: supportEmail,
                    imageUrl: supportImageUrl,
                  ),
                ],
                if (showBuyTraffic) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: OutlinedButton.icon(
                      onPressed: () =>
                          unawaited(globalState.openUrl(buyTrafficUrl!)),
                      icon: const Icon(Icons.add_rounded),
                      label: Text(appLocalizations.buyMoreTraffic),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _ConnectButton(isReady: isReady),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

class _Logo extends StatelessWidget {
  const _Logo({this.logoUrl});

  final String? logoUrl;

  @override
  Widget build(BuildContext context) {
    const size = 104.0;
    final fallback = ClipRRect(
      borderRadius: BorderRadius.circular(26),
      child: Image.asset('assets/images/icon.png',
          width: size, height: size, fit: BoxFit.cover),
    );
    if (logoUrl == null || logoUrl!.isEmpty) return fallback;
    return ClipRRect(
      borderRadius: BorderRadius.circular(26),
      child: logoUrl!.toLowerCase().endsWith('.svg')
          ? SvgPicture.network(logoUrl!,
              width: size, height: size, placeholderBuilder: (_) => fallback)
          : CachedNetworkImage(
              imageUrl: logoUrl!,
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorWidget: (_, __, ___) => fallback,
            ),
    );
  }
}

class _SubscriptionCard extends StatelessWidget {
  const _SubscriptionCard({
    required this.sub,
    required this.isUpdating,
    required this.onUpdate,
    required this.buyPlanUrl,
  });

  final SubscriptionInfo sub;
  final bool isUpdating;
  final VoidCallback? onUpdate;
  final String? buyPlanUrl;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final used = (sub.upload + sub.download).toInt();
    final total = sub.total;
    final amount = total > 0
        ? '${_formatBytes(used)} / ${_formatBytes(total)}'
        : appLocalizations.trafficUnlimited;
    final expiration = sub.expire > 0
        ? DateTime.fromMillisecondsSinceEpoch(sub.expire * 1000)
        : null;
    final isActive = expiration == null || expiration.isAfter(DateTime.now());
    final expirationText = expiration == null
        ? appLocalizations.subscriptionEternal
        : DateFormat('dd.MM.yyyy').format(expiration);
    final canRenew = buyPlanUrl != null && buyPlanUrl!.isNotEmpty;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: colorScheme.surfaceContainer,
        border: Border.all(
          color: colorScheme.outlineVariant,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  appLocalizations.subscription,
                  style: context.textTheme.titleLarge?.copyWith(
                    fontSize: 20,
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: isActive
                      ? colorScheme.primary.withValues(alpha: 0.2)
                      : colorScheme.error.withValues(alpha: 0.2),
                ),
                child: Text(
                  isActive
                      ? appLocalizations.subscriptionActive
                      : appLocalizations.subscriptionExpiredStatus,
                  style: context.textTheme.labelSmall?.copyWith(
                    color: isActive ? colorScheme.primary : colorScheme.error,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _SubscriptionMetric(
            icon: Icons.calendar_today_outlined,
            label: appLocalizations.expiresOn,
            value: expirationText,
          ),
          const SizedBox(height: 12),
          _SubscriptionMetric(
            icon: Icons.sync_alt_rounded,
            label: appLocalizations.traffic,
            value: amount,
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: colorScheme.onSurfaceVariant,
                side: BorderSide(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.8),
                ),
                shape: const StadiumBorder(),
                textStyle: context.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              onPressed: isUpdating ? null : onUpdate,
              icon: SizedBox(
                width: 18,
                height: 18,
                child: isUpdating
                    ? CircularProgressIndicator(
                        strokeWidth: 2,
                        color: colorScheme.onSurfaceVariant,
                      )
                    : const Icon(Icons.refresh_rounded, size: 18),
              ),
              label: Text(appLocalizations.update),
            ),
          ),
          if (canRenew) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton.tonalIcon(
                style: FilledButton.styleFrom(
                  shape: const StadiumBorder(),
                  textStyle: context.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                onPressed: () => unawaited(globalState.openUrl(buyPlanUrl!)),
                icon: const Icon(Icons.autorenew_rounded),
                label: Text(appLocalizations.renew),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SubscriptionMetric extends StatelessWidget {
  const _SubscriptionMetric({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: colorScheme.surfaceContainerHigh.withValues(alpha: 0.82),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                size: 16,
                color: colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 10),
              Text(
                label.toUpperCase(),
                style: context.textTheme.labelMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w400,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _ConnectButton extends ConsumerStatefulWidget {
  const _ConnectButton({required this.isReady});

  final bool isReady;

  @override
  ConsumerState<_ConnectButton> createState() => _ConnectButtonState();
}

class _ConnectButtonState extends ConsumerState<_ConnectButton> {
  bool _isChanging = false;

  Future<void> _toggle(bool isStart) async {
    if (_isChanging) return;
    setState(() => _isChanging = true);
    try {
      if (Platform.isAndroid) {
        await HapticFeedback.mediumImpact();
      }
      await globalState.appController.updateStatus(!isStart);
    } catch (error) {
      commonPrint.log('VPN status change failed: $error');
    } finally {
      if (mounted) {
        setState(() => _isChanging = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final runTime = ref.watch(runTimeProvider);
    final isStart = runTime != null;

    final Color bg;
    final Color fg;
    if (!widget.isReady || _isChanging) {
      bg = colorScheme.surfaceContainerHighest.withValues(alpha: 0.5);
      fg = colorScheme.onSurface.withValues(alpha: 0.38);
    } else if (isStart) {
      bg = colorScheme.surfaceContainerHigh.withValues(alpha: 0.8);
      fg = colorScheme.primary;
    } else {
      bg = colorScheme.primary;
      fg = colorScheme.onPrimary;
    }

    return SizedBox(
      width: double.infinity,
      height: 54,
      child: FilledButton(
        autofocus: true,
        style: FilledButton.styleFrom(
          backgroundColor: bg,
          foregroundColor: fg,
          disabledBackgroundColor: bg,
          disabledForegroundColor: fg,
          shape: const StadiumBorder(),
          side: isStart
              ? BorderSide(
                  color: colorScheme.primary.withValues(alpha: 0.4),
                )
              : null,
        ),
        onPressed: widget.isReady && !_isChanging
            ? () => unawaited(_toggle(isStart))
            : null,
        child: isStart
            ? Row(
                children: [
                  const Icon(Icons.pause_rounded, size: 24),
                  const SizedBox(width: 8),
                  Text(
                    appLocalizations.disableVpn,
                    style: context.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    utils.getTimeText(runTime),
                    style: context.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                      fontFamily: FontFamily.jetBrainsMono.value,
                    ),
                  ),
                ],
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.play_arrow_rounded, size: 24),
                  const SizedBox(width: 8),
                  Text(
                    appLocalizations.enableVpn,
                    style: context.textTheme.titleSmall?.copyWith(
                      color: fg,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _EmptyHero extends ConsumerWidget {
  const _EmptyHero();

  @override
  Widget build(BuildContext context, WidgetRef ref) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const _Logo(),
          const SizedBox(height: 16),
          Text(
            appName,
            style: context.textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton.icon(
              autofocus: true,
              onPressed: () async {
                final url = await globalState.showCommonDialog<String>(
                  child: const URLFormDialog(),
                );
                if (url != null) {
                  unawaited(globalState.appController.addProfileFormURL(url));
                }
              },
              icon: const Icon(Icons.add_rounded),
              label: Text(appLocalizations.addProfile),
            ),
          ),
        ],
      );
}

class _AnnounceBanner extends StatelessWidget {
  const _AnnounceBanner({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: colorScheme.secondaryContainer,
      ),
      // EmojiText (not Text): renders flag/emoji runs with the Twemoji font so
      // they show up — plain Text drops country flags entirely on Windows.
      child: EmojiText(
        text,
        style: context.textTheme.bodyMedium?.copyWith(
          color: colorScheme.onSecondaryContainer,
          height: 1.4,
        ),
      ),
    );
  }
}

class _SupportCard extends StatelessWidget {
  const _SupportCard({
    required this.supportUrl,
    required this.supportEmail,
    required this.imageUrl,
  });

  final String? supportUrl;
  final String? supportEmail;
  final String? imageUrl;

  bool get _hasUrl => supportUrl?.isNotEmpty ?? false;
  bool get _hasEmail => supportEmail?.isNotEmpty ?? false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: _SupportAvatar(imageUrl: imageUrl),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      appLocalizations.support,
                      style: context.textTheme.bodyLarge?.copyWith(
                        color: const Color(0xFF92CEF5),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      appLocalizations.supportMessage,
                      style: context.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontSize: 14,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildAction(context),
        ],
      ),
    );
  }

  Widget _buildAction(BuildContext context) {
    if (_hasUrl && _hasEmail) {
      return LayoutBuilder(
        builder: (context, constraints) => CommonPopupBox(
          targetBuilder: (open) => _SupportButton(
            icon: const Icon(Icons.edit_rounded, size: 20),
            onPressed: () => open(
              offset: Offset(constraints.maxWidth - 48, 20),
            ),
          ),
          popup: CommonPopupMenu(
            items: [
              PopupMenuItemData(
                icon:
                    _isTelegramUrl(supportUrl!) ? null : Icons.language_rounded,
                iconWidget:
                    _isTelegramUrl(supportUrl!) ? const _TelegramIcon() : null,
                label: _isTelegramUrl(supportUrl!)
                    ? 'Telegram'
                    : appLocalizations.website,
                onPressed: () => unawaited(
                  globalState.openUrl(supportUrl!),
                ),
              ),
              PopupMenuItemData(
                icon: Icons.mail_rounded,
                label: appLocalizations.email,
                onPressed: () => unawaited(
                  globalState.openUrl(_emailUri(supportEmail!)),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_hasUrl) {
      return _SupportButton(
        icon: _isTelegramUrl(supportUrl!)
            ? const _TelegramIcon()
            : const Icon(Icons.edit_rounded, size: 20),
        onPressed: () => unawaited(globalState.openUrl(supportUrl!)),
      );
    }

    return _SupportButton(
      icon: const Icon(Icons.mail_rounded, size: 20),
      onPressed: () => unawaited(
        globalState.openUrl(_emailUri(supportEmail!)),
      ),
    );
  }
}

class _SupportButton extends StatelessWidget {
  const _SupportButton({
    required this.icon,
    required this.onPressed,
  });

  final Widget icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: double.infinity,
        height: 40,
        child: FilledButton.tonalIcon(
          onPressed: onPressed,
          icon: icon,
          label: Text(appLocalizations.writeToSupport),
        ),
      );
}

class _SupportAvatar extends StatelessWidget {
  const _SupportAvatar({required this.imageUrl});

  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    const size = 48.0;
    final colorScheme = context.colorScheme;
    final fallback = ColoredBox(
      color: colorScheme.secondaryContainer,
      child: SizedBox.square(
        dimension: size,
        child: Icon(
          Icons.support_agent_rounded,
          color: colorScheme.onSecondaryContainer,
          size: 26,
        ),
      ),
    );
    final url = imageUrl;
    final isSvg = url != null &&
        (Uri.tryParse(url)?.path.toLowerCase().endsWith('.svg') ?? false);
    final image = url == null || url.isEmpty
        ? fallback
        : isSvg
            ? SvgPicture.network(
                url,
                width: size,
                height: size,
                fit: BoxFit.cover,
                placeholderBuilder: (_) => fallback,
              )
            : CachedNetworkImage(
                imageUrl: url,
                width: size,
                height: size,
                fit: BoxFit.cover,
                placeholder: (_, __) => fallback,
                errorWidget: (_, __, ___) => fallback,
              );

    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.2),
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: ClipOval(child: image),
    );
  }
}

class _TelegramIcon extends StatelessWidget {
  const _TelegramIcon();

  static const _svg = '''
<svg viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">
  <path fill="currentColor" d="M9.78 18.65l.28-4.23 7.68-6.92c.34-.31-.07-.46-.52-.19L7.74 13.3 3.64 12c-.88-.25-.89-.86.2-1.3l15.97-6.16c.73-.33 1.43.18 1.15 1.3l-2.72 12.81c-.19.91-.74 1.13-1.5.71L12.6 16.3l-1.99 1.93c-.23.23-.42.42-.83.42z"/>
</svg>
''';

  @override
  Widget build(BuildContext context) => SvgPicture.string(
        _svg,
        width: 20,
        height: 20,
        colorFilter: ColorFilter.mode(
          IconTheme.of(context).color ?? context.colorScheme.onSurface,
          BlendMode.srcIn,
        ),
      );
}

bool _isTelegramUrl(String value) {
  final uri = Uri.tryParse(value.trim());
  if (uri == null) return false;
  if (uri.scheme.toLowerCase() == 'tg') return true;
  final host = uri.host.toLowerCase();
  return host == 't.me' ||
      host.endsWith('.t.me') ||
      host == 'telegram.me' ||
      host.endsWith('.telegram.me') ||
      host == 'telegram.org' ||
      host.endsWith('.telegram.org') ||
      host == 'telegram.dog' ||
      host.endsWith('.telegram.dog');
}

String _emailUri(String email) {
  final value = email.trim();
  if (value.toLowerCase().startsWith('mailto:')) return value;
  return Uri(scheme: 'mailto', path: value).toString();
}
