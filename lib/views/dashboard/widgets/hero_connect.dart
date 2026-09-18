import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:gektusclashx/common/common.dart';
import 'package:gektusclashx/enum/enum.dart';
import 'package:gektusclashx/l10n/l10n.dart';
import 'package:gektusclashx/models/models.dart';
import 'package:gektusclashx/providers/providers.dart';
import 'package:gektusclashx/state.dart';
import 'package:gektusclashx/views/profiles/add_profile.dart';
import 'package:gektusclashx/widgets/widgets.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:share_plus/share_plus.dart';

const _smallButtonHeight = 40.0;
const _smallButtonIconSize = 20.0;
const _smallProgressIndicatorSize = 16.0;
const _slantedSkew = 0.1;
const _normalizedSlantedSkew = _slantedSkew / (1 + _slantedSkew);

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
    final localizations = AppLocalizations.of(context);
    final state = ref.watch(startButtonSelectorStateProvider);
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    if (!state.hasProfile) {
      final bottomPadding = bottomInset + 16;
      return LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          key: const PageStorageKey('dashboard-empty-scroll'),
          padding: EdgeInsets.fromLTRB(16, 16, 16, bottomPadding),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: math.max(
                0,
                constraints.maxHeight - 16 - bottomPadding,
              ),
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: const _EmptyHero(),
              ),
            ),
          ),
        ),
      );
    }

    final profile = ref.watch(currentProfileProvider);
    if (profile == null) {
      return const SizedBox.expand();
    }

    final headers = profile.providerHeaders;
    final serviceName =
        _decodeBase64(headers['gektusclashx-servicename']) ?? appName;
    final logoUrl = decodeServiceLogoUrl(headers['gektusclashx-servicelogo']);
    final showAnnounce =
        headers['gektusclashx-announce-show']?.trim().toLowerCase() != 'false';
    final announce = showAnnounce ? _decodeAnnounce(headers['announce']) : null;
    final sub = profile.subscriptionInfo;
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
    final serviceLinks = <_ServiceLink>[
      if (headers['gektusclashx-channel-url']?.trim().isNotEmpty ?? false)
        _ServiceLink(
          label: localizations.serviceChannel,
          icon: Icons.campaign_rounded,
          url: headers['gektusclashx-channel-url']!.trim(),
        ),
      if (headers['gektusclashx-status-url']?.trim().isNotEmpty ?? false)
        _ServiceLink(
          label: localizations.serverStatus,
          icon: Icons.dns_rounded,
          url: headers['gektusclashx-status-url']!.trim(),
        ),
      if (headers['gektusclashx-terms-url']?.trim().isNotEmpty ?? false)
        _ServiceLink(
          label: localizations.termsOfService,
          icon: Icons.description_rounded,
          url: headers['gektusclashx-terms-url']!.trim(),
        ),
      if (headers['gektusclashx-privacy-url']?.trim().isNotEmpty ?? false)
        _ServiceLink(
          label: localizations.privacyPolicy,
          icon: Icons.privacy_tip_rounded,
          url: headers['gektusclashx-privacy-url']!.trim(),
        ),
    ];

    return SingleChildScrollView(
      key: const PageStorageKey('dashboard-scroll'),
      padding: EdgeInsets.fromLTRB(16, 16, 16, bottomInset + 12),
      child: Column(
        children: [
          _ServiceIdentity(
            name: serviceName,
            logoUrl: logoUrl,
          ),
          if (announce != null && announce.isNotEmpty) ...[
            const SizedBox(height: 16),
            _AnnounceBanner(text: announce),
          ],
          if (hasSub) ...[
            const SizedBox(height: 18),
            _SubscriptionCard(
              sub: sub,
              isUpdating: profile.isUpdating,
              onUpdate: () => globalState.appController.updateProfile(profile),
              buyPlanUrl: buyPlanUrl,
              shareUrl: profile.url,
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
          if (serviceLinks.isNotEmpty) ...[
            const SizedBox(height: 12),
            _ServiceLinksCard(links: serviceLinks),
          ],
          if (showBuyTraffic) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton.icon(
                onPressed: () => unawaited(globalState.openUrl(buyTrafficUrl!)),
                icon: const Icon(Icons.add_rounded),
                label: Text(appLocalizations.buyMoreTraffic),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class HomeActionArea extends ConsumerWidget {
  const HomeActionArea({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(startButtonSelectorStateProvider);
    return ValueListenableBuilder<AppUpdateState?>(
      valueListenable: globalState.appController.appUpdateState,
      builder: (context, updateState, _) {
        if (!state.hasProfile && updateState == null) {
          return const SizedBox.shrink();
        }
        final opaqueBackgroundTop = state.hasProfile ? 28.0 : 36.0;
        return Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              top: -48,
              left: 0,
              right: 0,
              height: opaqueBackgroundTop + 48,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        context.colorScheme.surfaceContainer
                            .withValues(alpha: 0),
                        context.colorScheme.surfaceContainer,
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: opaqueBackgroundTop,
              left: 0,
              right: 0,
              bottom: 0,
              child: IgnorePointer(
                child: ColoredBox(
                  color: context.colorScheme.surfaceContainer,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (state.hasProfile) _ConnectButton(isReady: state.isInit),
                  if (state.hasProfile && updateState != null)
                    const SizedBox(height: 12),
                  if (updateState != null) _AppUpdateBanner(state: updateState),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ServiceIdentity extends StatelessWidget {
  const _ServiceIdentity({
    required this.name,
    required this.logoUrl,
  });

  final String name;
  final String? logoUrl;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          final logoSize = (constraints.maxWidth * 0.34).clamp(112.0, 136.0);
          return SizedBox(
            height: logoSize,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox.square(
                  dimension: logoSize,
                  child: _ExpressiveLogo(logoUrl: logoUrl),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _ExpressiveServiceName(name: name),
                ),
              ],
            ),
          );
        },
      );
}

class _ExpressiveLogo extends StatefulWidget {
  const _ExpressiveLogo({required this.logoUrl});

  final String? logoUrl;

  @override
  State<_ExpressiveLogo> createState() => _ExpressiveLogoState();
}

class _ExpressiveLogoState extends State<_ExpressiveLogo> {
  Future<Uint8List?>? _loadFuture;
  Uint8List? _initialBytes;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant _ExpressiveLogo oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.logoUrl != widget.logoUrl) _load();
  }

  void _load() {
    final url = widget.logoUrl;
    _initialBytes = url == null ? null : serviceLogoCache.get(url);
    _loadFuture = url == null ? null : serviceLogoCache.load(url);
  }

  @override
  Widget build(BuildContext context) {
    final fallback = Image.asset(
      'assets/images/icon.png',
      fit: BoxFit.cover,
    );
    final url = widget.logoUrl;
    final logo = url == null || url.isEmpty
        ? fallback
        : FutureBuilder<Uint8List?>(
            future: _loadFuture,
            initialData: _initialBytes,
            builder: (_, snapshot) {
              final bytes = snapshot.data ?? _initialBytes;
              if (bytes == null) {
                return snapshot.connectionState == ConnectionState.done
                    ? fallback
                    : const SizedBox.expand();
              }
              final isSvg =
                  Uri.tryParse(url)?.path.toLowerCase().endsWith('.svg') ??
                      false;
              if (isSvg) {
                return SvgPicture.memory(
                  bytes,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => fallback,
                );
              }
              return Image.memory(
                bytes,
                fit: BoxFit.cover,
                gaplessPlayback: true,
                errorBuilder: (_, __, ___) => fallback,
              );
            },
          );

    return ExcludeSemantics(
      child: ClipPath(
        clipper: const _SlantedClipper(),
        clipBehavior: Clip.antiAlias,
        child: ColoredBox(
          color: context.colorScheme.primaryContainer,
          child: logo,
        ),
      ),
    );
  }
}

class _SlantedClipper extends CustomClipper<Path> {
  const _SlantedClipper();

  @override
  Path getClip(Size size) {
    final rect = Offset.zero & size;
    final base = ContinuousRectangleBorder(
      borderRadius: BorderRadius.circular(size.shortestSide * 0.3),
    ).getOuterPath(rect);
    const horizontalScale = 1 / (1 + _slantedSkew);
    const horizontalSkew = -_slantedSkew * horizontalScale;
    final translation = rect.center.dx -
        horizontalScale * rect.center.dx -
        horizontalSkew * rect.center.dy;
    return base.transform(
      Float64List.fromList([
        horizontalScale,
        0,
        0,
        0,
        horizontalSkew,
        1,
        0,
        0,
        0,
        0,
        1,
        0,
        translation,
        0,
        0,
        1,
      ]),
    );
  }

  @override
  bool shouldReclip(_SlantedClipper oldClipper) => false;
}

class _ExpressiveServiceName extends StatelessWidget {
  const _ExpressiveServiceName({required this.name});

  static const _fontSize = 100.0;
  static const _minWidth = 25.0;
  static const _maxWidth = 151.0;

  final String name;

  TextStyle _style(BuildContext context, double width) => TextStyle(
        color: context.colorScheme.primary,
        fontFamily: 'GoogleSansFlex',
        fontSize: _fontSize,
        fontWeight: FontWeight.w600,
        height: 0.78,
        letterSpacing: -1.5,
        fontVariations: [
          const FontVariation('wght', 600),
          FontVariation('wdth', width),
          const FontVariation('opsz', 100),
          const FontVariation('GRAD', 0),
          const FontVariation('ROND', 0),
          const FontVariation('slnt', 0),
        ],
      );

  double _textAspectRatio(
    BuildContext context,
    TextDirection textDirection,
    double width,
  ) {
    final painter = TextPainter(
      text: TextSpan(text: name, style: _style(context, width)),
      maxLines: 1,
      textDirection: textDirection,
      textScaler: TextScaler.noScaling,
    )..layout();
    return painter.width / painter.height;
  }

  double _bestWidth(
    BuildContext context,
    TextDirection textDirection,
    double targetAspectRatio,
  ) {
    var lower = _minWidth;
    var upper = _maxWidth;
    for (var i = 0; i < 10; i++) {
      final midpoint = (lower + upper) / 2;
      if (_textAspectRatio(context, textDirection, midpoint) <
          targetAspectRatio) {
        lower = midpoint;
      } else {
        upper = midpoint;
      }
    }
    return (lower + upper) / 2;
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          final textDirection = Directionality.of(context);
          final slantInset = constraints.maxHeight * _normalizedSlantedSkew / 2;
          final targetAspectRatio =
              (constraints.maxWidth - slantInset * 2) / constraints.maxHeight;
          final width = _bestWidth(
            context,
            textDirection,
            targetAspectRatio,
          );
          return ClipRect(
            child: Transform.translate(
              offset: const Offset(0, 2.5),
              child: Transform(
                alignment: Alignment.center,
                transform: Matrix4.skewX(-math.atan(_normalizedSlantedSkew)),
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: slantInset),
                  child: FittedBox(
                    fit: BoxFit.fill,
                    alignment: AlignmentDirectional.centerStart,
                    child: Text(
                      name,
                      maxLines: 1,
                      softWrap: false,
                      textScaler: TextScaler.noScaling,
                      style: _style(context, width),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      );
}

class _SubscriptionCard extends StatelessWidget {
  const _SubscriptionCard({
    required this.sub,
    required this.isUpdating,
    required this.onUpdate,
    required this.buyPlanUrl,
    required this.shareUrl,
  });

  final SubscriptionInfo sub;
  final bool isUpdating;
  final VoidCallback? onUpdate;
  final String? buyPlanUrl;
  final String? shareUrl;

  Future<void> _share(BuildContext context) async {
    final url = shareUrl?.trim();
    if (url == null || url.isEmpty) return;
    final box = context.findRenderObject() as RenderBox?;
    await SharePlus.instance.share(
      ShareParams(
        text: url,
        sharePositionOrigin:
            box == null ? null : box.localToGlobal(Offset.zero) & box.size,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final used = (sub.upload + sub.download).toInt();
    final total = sub.total;
    final isLifetime = sub.expire <= 0;
    final trafficProgress = total > 0 ? (used / total).clamp(0.0, 1.0) : null;
    final amount = total > 0
        ? '${_formatBytes(used)} / ${_formatBytes(total)}'
        : appLocalizations.trafficUnlimited;
    final expiration = sub.expire > 0
        ? DateTime.fromMillisecondsSinceEpoch(sub.expire * 1000)
        : null;
    final isActive = expiration == null || expiration.isAfter(DateTime.now());
    final expirationText = expiration == null
        ? appLocalizations.subscriptionLifetime
        : DateFormat('dd.MM.yyyy').format(expiration);
    final canRenew = buyPlanUrl != null && buyPlanUrl!.isNotEmpty;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: colorScheme.surfaceContainer,
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
            label: isLifetime
                ? appLocalizations.subscriptionValidity
                : appLocalizations.expiresOn,
            value: expirationText,
          ),
          const SizedBox(height: 12),
          _SubscriptionMetric(
            icon: Icons.sync_alt_rounded,
            label: appLocalizations.traffic,
            value: amount,
            progress: trafficProgress,
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: _smallButtonHeight,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Builder(
                  builder: (buttonContext) => Tooltip(
                    message: appLocalizations.share,
                    child: SizedBox(
                      width: _smallButtonHeight,
                      child: OutlinedButton(
                        style: _outlinedGroupButtonStyle(
                          context,
                          const BorderRadius.horizontal(
                            left: Radius.circular(_smallButtonHeight / 2),
                            right: Radius.circular(8),
                          ),
                        ).copyWith(
                          padding:
                              const WidgetStatePropertyAll(EdgeInsets.zero),
                        ),
                        onPressed: (shareUrl?.trim().isNotEmpty ?? false)
                            ? () => unawaited(_share(buttonContext))
                            : null,
                        child: const Icon(
                          Icons.share_rounded,
                          size: _smallButtonIconSize,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 2),
                Expanded(
                  child: OutlinedButton.icon(
                    style: _outlinedGroupButtonStyle(
                      context,
                      canRenew
                          ? BorderRadius.circular(8)
                          : const BorderRadius.horizontal(
                              left: Radius.circular(8),
                              right: Radius.circular(_smallButtonHeight / 2),
                            ),
                    ),
                    onPressed: isUpdating ? null : onUpdate,
                    icon: SizedBox.square(
                      dimension: _smallButtonIconSize,
                      child: isUpdating
                          ? Center(
                              child: SizedBox.square(
                                dimension: _smallProgressIndicatorSize,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                            )
                          : const Icon(
                              Icons.refresh_rounded,
                              size: _smallButtonIconSize,
                            ),
                    ),
                    label: Text(appLocalizations.update),
                  ),
                ),
                if (canRenew) ...[
                  const SizedBox(width: 2),
                  Expanded(
                    child: FilledButton.tonalIcon(
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        shape: const StadiumBorder(),
                        textStyle: context.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      onPressed: () =>
                          unawaited(globalState.openUrl(buyPlanUrl!)),
                      icon: const Icon(
                        Icons.credit_card_rounded,
                        size: _smallButtonIconSize,
                      ),
                      label: Text(
                        isLifetime
                            ? appLocalizations.plans
                            : appLocalizations.renew,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  ButtonStyle _outlinedGroupButtonStyle(
    BuildContext context,
    BorderRadius borderRadius,
  ) =>
      OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        foregroundColor: context.colorScheme.onSurfaceVariant,
        side: BorderSide(
          color: context.colorScheme.outlineVariant.withValues(alpha: 0.8),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: borderRadius,
        ),
        textStyle: context.textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      );
}

class _SubscriptionMetric extends StatelessWidget {
  const _SubscriptionMetric({
    required this.icon,
    required this.label,
    required this.value,
    this.progress,
  });

  final IconData icon;
  final String label;
  final String value;
  final double? progress;

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
          if (progress != null) ...[
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              borderRadius: BorderRadius.circular(3),
              color: colorScheme.primary,
              backgroundColor:
                  colorScheme.onSurfaceVariant.withValues(alpha: 0.14),
            ),
          ],
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
      bg = colorScheme.surfaceContainerHighest;
      fg = colorScheme.onSurface.withValues(alpha: 0.38);
    } else if (isStart) {
      bg = colorScheme.primaryContainer;
      fg = colorScheme.onPrimaryContainer;
    } else {
      bg = colorScheme.primary;
      fg = colorScheme.onPrimary;
    }

    return SizedBox(
      width: double.infinity,
      height: 56,
      child: FilledButton(
        autofocus: true,
        style: FilledButton.styleFrom(
          backgroundColor: bg,
          foregroundColor: fg,
          disabledBackgroundColor: bg,
          disabledForegroundColor: fg,
          shape: const StadiumBorder(),
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
                    style: context.textTheme.titleMedium?.copyWith(
                      color: fg,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    utils.getTimeText(runTime),
                    style: context.textTheme.titleSmall?.copyWith(
                      color: fg,
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
                    style: context.textTheme.titleMedium?.copyWith(
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

class _AppUpdateBanner extends StatelessWidget {
  const _AppUpdateBanner({required this.state});

  final AppUpdateState state;

  String _message() => switch (state.phase) {
        AppUpdatePhase.available => appLocalizations.appUpdateAvailable,
        AppUpdatePhase.downloading => appLocalizations.downloadingAppUpdate,
        AppUpdatePhase.readyToInstall ||
        AppUpdatePhase.installing =>
          appLocalizations.appUpdateReady,
        AppUpdatePhase.failed => switch (state.failure) {
            AppUpdateFailure.assetNotFound =>
              appLocalizations.appUpdateAssetNotFound,
            AppUpdateFailure.verificationFailed =>
              appLocalizations.appUpdateVerificationFailed,
            AppUpdateFailure.downloadFailed =>
              appLocalizations.appUpdateDownloadFailed,
            AppUpdateFailure.invalidPackage =>
              appLocalizations.appUpdateInvalidPackage,
            AppUpdateFailure.permissionDenied =>
              appLocalizations.appUpdateInstallPermissionDenied,
            AppUpdateFailure.installerUnavailable ||
            null =>
              appLocalizations.appUpdateInstallFailed,
          },
      };

  String _actionLabel() => switch (state.phase) {
        AppUpdatePhase.available => appLocalizations.downloadUpdate,
        AppUpdatePhase.downloading => appLocalizations.cancel,
        AppUpdatePhase.readyToInstall ||
        AppUpdatePhase.installing =>
          appLocalizations.install,
        AppUpdatePhase.failed =>
          state.apk == null ? appLocalizations.retry : appLocalizations.install,
      };

  VoidCallback? _action() => switch (state.phase) {
        AppUpdatePhase.available => Platform.isAndroid
            ? () => unawaited(
                  globalState.appController.downloadAndroidAppUpdate(),
                )
            : () => unawaited(
                  globalState.appController.openAppUpdateDownload(),
                ),
        AppUpdatePhase.downloading =>
          globalState.appController.cancelAndroidAppUpdateDownload,
        AppUpdatePhase.readyToInstall => () => unawaited(
              globalState.appController.installAndroidAppUpdate(),
            ),
        AppUpdatePhase.installing => null,
        AppUpdatePhase.failed => state.apk == null
            ? () => unawaited(
                  globalState.appController.downloadAndroidAppUpdate(),
                )
            : () => unawaited(
                  globalState.appController.installAndroidAppUpdate(),
                ),
      };

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final isAvailable = state.phase == AppUpdatePhase.available;
    final isDownloading = state.phase == AppUpdatePhase.downloading;
    final isInstalling = state.phase == AppUpdatePhase.installing;
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 72),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: colorScheme.tertiaryContainer,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isAvailable) ...[
                      Text(
                        _message(),
                        style: context.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onTertiaryContainer,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        state.version,
                        style: context.textTheme.titleMedium?.copyWith(
                          color: colorScheme.onTertiaryContainer,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ] else
                      Text(
                        _message(),
                        style: context.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onTertiaryContainer,
                          fontWeight: FontWeight.w500,
                          height: 1.3,
                        ),
                      ),
                    if (isDownloading) ...[
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: state.progress,
                        minHeight: 4,
                        borderRadius: BorderRadius.circular(2),
                        color: colorScheme.tertiary,
                        backgroundColor: colorScheme.onTertiaryContainer
                            .withValues(alpha: 0.16),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: colorScheme.onTertiaryContainer,
                  minimumSize: const Size(0, 40),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  side: BorderSide(
                    color:
                        colorScheme.onTertiaryContainer.withValues(alpha: 0.48),
                  ),
                  shape: const StadiumBorder(),
                  textStyle: context.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                onPressed: _action(),
                child: isInstalling
                    ? SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: colorScheme.onTertiaryContainer,
                        ),
                      )
                    : Text(_actionLabel()),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EmptyHero extends StatelessWidget {
  const _EmptyHero();

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: ShapeDecoration(
        color: colorScheme.surfaceContainerHigh.withValues(alpha: 0.9),
        shape: const RoundedSuperellipseBorder(
          borderRadius: BorderRadius.all(Radius.circular(32)),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox.square(
            dimension: 96,
            child: _OnboardingLogo(),
          ),
          const SizedBox(height: 24),
          Text(
            appLocalizations.profileOnboardingTitle,
            textAlign: TextAlign.center,
            style: context.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            appLocalizations.profileOnboardingMessage,
            textAlign: TextAlign.center,
            style: context.textTheme.bodyLarge?.copyWith(
              color: colorScheme.onSurfaceVariant,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: FilledButton.icon(
              autofocus: true,
              onPressed: () => unawaited(showAddProfileSheet(context)),
              icon: const Icon(Icons.add_rounded),
              label: Text(appLocalizations.addProfile),
            ),
          ),
        ],
      ),
    );
  }
}

class _OnboardingLogo extends StatelessWidget {
  const _OnboardingLogo();

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
        child: SvgPicture.asset(
          'assets/images/icon_tile.svg',
          fit: BoxFit.contain,
          colorFilter: ColorFilter.mode(
            context.colorScheme.primary,
            BlendMode.srcIn,
          ),
        ),
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

enum _SupportMethod {
  website,
  email,
}

class _ServiceLink {
  const _ServiceLink({
    required this.label,
    required this.icon,
    required this.url,
  });

  final String label;
  final IconData icon;
  final String url;
}

class _ServiceLinksCard extends StatelessWidget {
  const _ServiceLinksCard({required this.links});

  final List<_ServiceLink> links;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 14),
            child: Text(
              appLocalizations.serviceLinks,
              style: context.textTheme.titleLarge?.copyWith(
                color: colorScheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          for (var index = 0; index < links.length; index++) ...[
            _ServiceLinkButton(
              link: links[index],
              isFirst: index == 0,
              isLast: index == links.length - 1,
            ),
            if (index != links.length - 1) const SizedBox(height: 2),
          ],
        ],
      ),
    );
  }
}

class _ServiceLinkButton extends StatefulWidget {
  const _ServiceLinkButton({
    required this.link,
    required this.isFirst,
    required this.isLast,
  });

  final _ServiceLink link;
  final bool isFirst;
  final bool isLast;

  @override
  State<_ServiceLinkButton> createState() => _ServiceLinkButtonState();
}

class _ServiceLinkButtonState extends State<_ServiceLinkButton> {
  var _isPressed = false;

  @override
  Widget build(BuildContext context) {
    const outerRadius = Radius.circular(22);
    const innerRadius = Radius.circular(6);
    final colorScheme = context.colorScheme;
    final borderRadius = BorderRadius.only(
      topLeft: widget.isFirst ? outerRadius : innerRadius,
      topRight: widget.isFirst ? outerRadius : innerRadius,
      bottomLeft: widget.isLast ? outerRadius : innerRadius,
      bottomRight: widget.isLast ? outerRadius : innerRadius,
    );

    return AnimatedScale(
      scale: _isPressed ? 0.985 : 1,
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOutCubic,
      child: Material(
        color: colorScheme.surfaceContainerHighest,
        shape: RoundedRectangleBorder(borderRadius: borderRadius),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => unawaited(globalState.openUrl(widget.link.url)),
          onHighlightChanged: (value) {
            if (_isPressed != value) setState(() => _isPressed = value);
          },
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 60),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: colorScheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Icon(
                      widget.link.icon,
                      size: 22,
                      color: colorScheme.onSecondaryContainer,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      widget.link.label,
                      style: context.textTheme.bodyLarge?.copyWith(
                        color: colorScheme.onSurface,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Icon(
                    Icons.open_in_new_rounded,
                    size: 20,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SupportCard extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = context.colorScheme;
    final isMobileView = ref.watch(isMobileViewProvider);
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
                        color: colorScheme.tertiary,
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
          _buildAction(context, isMobileView),
        ],
      ),
    );
  }

  Widget _buildAction(BuildContext context, bool isMobileView) {
    if (_hasUrl && _hasEmail) {
      if (isMobileView) {
        return _SupportButton(
          icon: const Icon(
            Icons.edit_rounded,
            size: _smallButtonIconSize,
          ),
          showMenuIndicator: true,
          onPressed: () => unawaited(_showMethods(context)),
        );
      }

      return CommonPopupBox(
        targetBuilder: (open) => _SupportButton(
          icon: const Icon(
            Icons.edit_rounded,
            size: _smallButtonIconSize,
          ),
          showMenuIndicator: true,
          onPressed: open,
        ),
        // Two 48 dp items, 16 dp menu padding, the 40 dp trigger and an
        // 8 dp gap. MenuAnchor will keep the menu inside the viewport.
        alignmentOffset: const Offset(0, -160),
        popup: CommonPopupMenu(
          items: [
            PopupMenuItemData(
              icon: _isTelegramUrl(supportUrl!) ? null : Icons.language_rounded,
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
      );
    }

    if (_hasUrl) {
      return _SupportButton(
        icon: _isTelegramUrl(supportUrl!)
            ? const _TelegramIcon()
            : const Icon(
                Icons.edit_rounded,
                size: _smallButtonIconSize,
              ),
        onPressed: () => unawaited(globalState.openUrl(supportUrl!)),
      );
    }

    return _SupportButton(
      icon: const Icon(
        Icons.mail_rounded,
        size: _smallButtonIconSize,
      ),
      onPressed: () => unawaited(
        globalState.openUrl(_emailUri(supportEmail!)),
      ),
    );
  }

  Future<void> _showMethods(BuildContext context) async {
    final method = await showSheet<_SupportMethod>(
      context: context,
      props: const SheetProps(
        maxWidth: 420,
        isScrollControlled: true,
      ),
      builder: (_, type) => AdaptiveSheetScaffold(
        type: type,
        title: appLocalizations.support,
        body: _SupportMethodList(
          supportUrl: supportUrl!,
        ),
      ),
    );
    if (method == null) return;

    switch (method) {
      case _SupportMethod.website:
        await globalState.openUrl(supportUrl!);
      case _SupportMethod.email:
        await globalState.openUrl(_emailUri(supportEmail!));
    }
  }
}

class _SupportButton extends StatelessWidget {
  const _SupportButton({
    required this.icon,
    required this.onPressed,
    this.showMenuIndicator = false,
  });

  final Widget icon;
  final VoidCallback onPressed;
  final bool showMenuIndicator;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: double.infinity,
        height: _smallButtonHeight,
        child: FilledButton.tonal(
          onPressed: onPressed,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              icon,
              const SizedBox(width: 8),
              Text(appLocalizations.writeToSupport),
              if (showMenuIndicator) ...[
                const SizedBox(width: 4),
                const Icon(Icons.expand_more_rounded, size: 20),
              ],
            ],
          ),
        ),
      );
}

class _SupportMethodList extends StatelessWidget {
  const _SupportMethodList({required this.supportUrl});

  final String supportUrl;

  @override
  Widget build(BuildContext context) {
    final isTelegram = _isTelegramUrl(supportUrl);
    final methods = [
      (
        method: _SupportMethod.website,
        icon: isTelegram
            ? const _TelegramIcon(size: 24)
            : const Icon(Icons.language_rounded, size: 24),
        title: isTelegram ? 'Telegram' : appLocalizations.website,
      ),
      (
        method: _SupportMethod.email,
        icon: const Icon(Icons.mail_rounded, size: 24),
        title: appLocalizations.email,
      ),
    ];

    return ListView.separated(
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: methods.length,
      separatorBuilder: (_, __) => const SizedBox(height: 2),
      itemBuilder: (context, index) {
        final method = methods[index];
        return _SupportMethodOption(
          icon: method.icon,
          title: method.title,
          isFirst: index == 0,
          isLast: index == methods.length - 1,
          onPressed: () => Navigator.of(context).pop(method.method),
        );
      },
    );
  }
}

class _SupportMethodOption extends StatelessWidget {
  const _SupportMethodOption({
    required this.icon,
    required this.title,
    required this.isFirst,
    required this.isLast,
    required this.onPressed,
  });

  final Widget icon;
  final String title;
  final bool isFirst;
  final bool isLast;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    const outerRadius = Radius.circular(24);
    const innerRadius = Radius.circular(4);
    final colorScheme = context.colorScheme;
    final borderRadius = BorderRadius.only(
      topLeft: isFirst ? outerRadius : innerRadius,
      topRight: isFirst ? outerRadius : innerRadius,
      bottomLeft: isLast ? outerRadius : innerRadius,
      bottomRight: isLast ? outerRadius : innerRadius,
    );

    return Material(
      color: colorScheme.surfaceContainerHigh,
      shape: RoundedRectangleBorder(borderRadius: borderRadius),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 72),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: colorScheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: IconTheme(
                    data: IconThemeData(
                      color: colorScheme.onSecondaryContainer,
                    ),
                    child: icon,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    title,
                    style: context.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Icon(
                  Icons.chevron_right_rounded,
                  color: colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
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
  const _TelegramIcon({this.size = _smallButtonIconSize});

  final double size;

  static const _svg = '''
<svg viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">
  <path fill="currentColor" d="M9.78 18.65l.28-4.23 7.68-6.92c.34-.31-.07-.46-.52-.19L7.74 13.3 3.64 12c-.88-.25-.89-.86.2-1.3l15.97-6.16c.73-.33 1.43.18 1.15 1.3l-2.72 12.81c-.19.91-.74 1.13-1.5.71L12.6 16.3l-1.99 1.93c-.23.23-.42.42-.83.42z"/>
</svg>
''';

  @override
  Widget build(BuildContext context) => SvgPicture.string(
        _svg,
        width: size,
        height: size,
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
