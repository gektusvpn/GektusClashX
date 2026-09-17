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

    return ValueListenableBuilder<AppUpdateState?>(
      valueListenable: globalState.appController.appUpdateState,
      builder: (context, updateState, _) {
        final visibleUpdateState = updateState;
        return Stack(
          children: [
            SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                16,
                16,
                16,
                visibleUpdateState == null ? 82 : 218,
              ),
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
                      isUpdating: profile?.isUpdating ?? false,
                      onUpdate: profile == null
                          ? null
                          : () =>
                              globalState.appController.updateProfile(profile),
                      buyPlanUrl: buyPlanUrl,
                      shareUrl: profile?.url,
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
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            context.colorScheme.surfaceContainer
                                .withValues(alpha: 0),
                            context.colorScheme.surfaceContainer
                                .withValues(alpha: 0.78),
                            context.colorScheme.surfaceContainer,
                          ],
                          stops: const [0, 0.58, 1],
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 28, 16, 16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _ConnectButton(isReady: isReady),
                        if (visibleUpdateState != null) ...[
                          const SizedBox(height: 12),
                          _AppUpdateBanner(state: visibleUpdateState),
                        ],
                      ],
                    ),
                  ),
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
          final logoSize = (constraints.maxWidth * 0.34).clamp(112.0, 148.0);
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

class _ExpressiveLogo extends StatelessWidget {
  const _ExpressiveLogo({required this.logoUrl});

  final String? logoUrl;

  @override
  Widget build(BuildContext context) {
    final fallback = Image.asset(
      'assets/images/icon.png',
      fit: BoxFit.cover,
    );
    final logo = switch (logoUrl) {
      final url when url != null && url.toLowerCase().endsWith('.svg') =>
        SvgPicture.network(
          url,
          fit: BoxFit.cover,
          placeholderBuilder: (_) => fallback,
        ),
      final url when url != null && url.isNotEmpty => CachedNetworkImage(
          imageUrl: url,
          fit: BoxFit.cover,
          placeholder: (_, __) => fallback,
          errorWidget: (_, __, ___) => fallback,
        ),
      _ => fallback,
    };

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
                      label: Text(appLocalizations.renew),
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
      bg = colorScheme.surfaceContainerHighest;
      fg = colorScheme.onSurface.withValues(alpha: 0.38);
    } else if (isStart) {
      bg = colorScheme.surfaceContainerHigh;
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

class _AppUpdateBanner extends StatelessWidget {
  const _AppUpdateBanner({required this.state});

  final AppUpdateState state;

  String _message() => switch (state.phase) {
        AppUpdatePhase.available =>
          '${appLocalizations.appUpdateAvailable} ${state.version}',
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
    final isDownloading = state.phase == AppUpdatePhase.downloading;
    final isInstalling = state.phase == AppUpdatePhase.installing;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
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
                child: Text(
                  _message(),
                  style: context.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onTertiaryContainer,
                    fontWeight: FontWeight.w500,
                    height: 1.4,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: colorScheme.onTertiaryContainer,
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
          if (isDownloading) ...[
            const SizedBox(height: 10),
            LinearProgressIndicator(
              value: state.progress,
              minHeight: 4,
              borderRadius: BorderRadius.circular(2),
              color: colorScheme.tertiary,
              backgroundColor:
                  colorScheme.onTertiaryContainer.withValues(alpha: 0.16),
            ),
          ],
        ],
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
          const _ServiceIdentity(
            name: appName,
            logoUrl: null,
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton.icon(
              autofocus: true,
              onPressed: () => unawaited(showAddProfileSheet(context)),
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
      return CommonPopupBox(
        targetBuilder: (open) => _SupportButton(
          icon: const Icon(
            Icons.edit_rounded,
            size: _smallButtonIconSize,
          ),
          onPressed: open,
        ),
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
        height: _smallButtonHeight,
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
        width: _smallButtonIconSize,
        height: _smallButtonIconSize,
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
