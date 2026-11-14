import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gektusclashx/common/common.dart';
import 'package:gektusclashx/l10n/l10n.dart';
import 'package:gektusclashx/models/models.dart';
import 'package:gektusclashx/providers/providers.dart';
import 'package:gektusclashx/state.dart';
import 'package:gektusclashx/widgets/widgets.dart';

enum _SupportMethod { website, email }

/// Keeps the dashboard actions together and follows the active subscription.
class DashboardHeaderActions extends ConsumerStatefulWidget {
  const DashboardHeaderActions({super.key, required this.onSettings});

  final VoidCallback onSettings;

  @override
  ConsumerState<DashboardHeaderActions> createState() =>
      _DashboardHeaderActionsState();
}

class _DashboardHeaderActionsState
    extends ConsumerState<DashboardHeaderActions> {
  final _supportFocus = FocusNode(debugLabel: 'Support');

  @override
  void dispose() {
    _supportFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final headers = ref.watch(currentProfileProvider)?.providerHeaders;
    final url = headers?['support-url']?.trim() ?? '';
    final email = headers?['support-email']?.trim() ?? '';
    final isTV = ref.watch(isAndroidTVProvider).valueOrNull ?? false;
    final strings = AppLocalizations.of(context);
    final colors = context.colorScheme;
    return LayoutBuilder(builder: (context, constraints) {
      final labelStyle = context.textTheme.labelLarge!;
      final label = TextPainter(
        text: TextSpan(text: strings.support, style: labelStyle),
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
        maxLines: 1,
      )..layout();
      // Reserve space for the leading control, page title, and toolbar insets.
      final available = constraints.maxWidth.isFinite
          ? constraints.maxWidth
          : MediaQuery.sizeOf(context).width;
      final showLabel =
          available >= label.width + 24 + 8 + 32 + 8 + 48 + 4 + 168;
      label.dispose();
      Widget supportButton(VoidCallback onPressed,
              {WidgetStatesController? statesController}) =>
          showLabel
              ? Padding(
                  // Match the 4dp horizontal insets around header icon containers.
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: FilledButton.tonalIcon(
                    onPressed: onPressed,
                    focusNode: _supportFocus,
                    statesController: statesController,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(40, 40),
                      fixedSize: const Size.fromHeight(40),
                      visualDensity: VisualDensity.standard,
                      tapTargetSize: MaterialTapTargetSize.padded,
                      backgroundColor: colors.surfaceContainerHigh,
                      foregroundColor: colors.onSurfaceVariant,
                      textStyle: labelStyle,
                    ),
                    icon: const Icon(Icons.support_agent_rounded, size: 24),
                    label: Text(strings.support, maxLines: 1),
                  ),
                )
              : CommonHeaderIconButton(
                  focusNode: _supportFocus,
                  statesController: statesController,
                  tooltip: strings.support,
                  onPressed: onPressed,
                  icon: const Icon(Icons.support_agent_rounded),
                );
      return Row(mainAxisSize: MainAxisSize.min, children: [
        if (url.isNotEmpty || email.isNotEmpty) ...[
          if (url.isNotEmpty && email.isNotEmpty && !isTV)
            Builder(builder: (context) {
              final popup = CommonPopupMenu(items: [
                PopupMenuItemData(
                  icon: _isTelegramUrl(url) ? null : Icons.language_rounded,
                  iconWidget: _isTelegramUrl(url) ? const TelegramIcon() : null,
                  label: _isTelegramUrl(url) ? 'Telegram' : strings.website,
                  onPressed: () => unawaited(globalState.openUrl(url)),
                ),
                PopupMenuItemData(
                  icon: Icons.mail_rounded,
                  label: strings.email,
                  onPressed: () =>
                      unawaited(globalState.openUrl(_emailUri(email))),
                ),
              ]);
              return CommonPopupBox(
                focusNode: _supportFocus,
                popup: popup,
                targetBuilder: (open, focusNode, statesController) =>
                    supportButton(open, statesController: statesController),
              );
            })
          else
            supportButton(() => unawaited(url.isNotEmpty && email.isNotEmpty
                ? _showMethods(context, url, email)
                : globalState
                    .openUrl(url.isNotEmpty ? url : _emailUri(email)))),
          const SizedBox(width: 4),
        ],
        CommonHeaderIconButton(
          tooltip: strings.settings,
          onPressed: widget.onSettings,
          icon: const Icon(Icons.settings_rounded),
        ),
      ]);
    });
  }

  Future<void> _showMethods(
      BuildContext context, String url, String email) async {
    final method = await showSheet<_SupportMethod>(
      context: context,
      props: const SheetProps(
        maxWidth: 420,
        maxHeight: 280,
        isScrollControlled: true,
      ),
      builder: (_, type) => AdaptiveSheetScaffold(
        type: type,
        title: AppLocalizations.of(context).support,
        body: _SupportMethodList(supportUrl: url),
      ),
    );
    switch (method) {
      case _SupportMethod.website:
        await globalState.openUrl(url);
      case _SupportMethod.email:
        await globalState.openUrl(_emailUri(email));
      case null:
        break;
    }
  }
}

class _SupportMethodList extends ConsumerWidget {
  const _SupportMethodList({required this.supportUrl});

  final String supportUrl;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isTelegram = _isTelegramUrl(supportUrl);
    final isAndroidTV = ref.watch(isAndroidTVProvider).valueOrNull ?? false;
    final methods = [
      (
        method: _SupportMethod.website,
        icon: isTelegram
            ? const TelegramIcon(size: 24)
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
          isAndroidTV: isAndroidTV,
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
    required this.isAndroidTV,
    required this.onPressed,
  });

  final Widget icon;
  final String title;
  final bool isFirst;
  final bool isLast;
  final bool isAndroidTV;
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

    return TVFocusEffect(
      enabled: isAndroidTV,
      borderRadius: borderRadius,
      child: Material(
        color: colorScheme.surfaceContainerHigh,
        shape: RoundedRectangleBorder(borderRadius: borderRadius),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          autofocus: isAndroidTV && isFirst,
          focusColor: colorScheme.primary.withValues(alpha: 0.24),
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
      ),
    );
  }
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
