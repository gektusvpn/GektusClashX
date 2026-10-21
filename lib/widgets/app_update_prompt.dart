import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:gektusclashx/common/app_update.dart';
import 'package:gektusclashx/common/app_update_reminder.dart';
import 'package:gektusclashx/common/constant.dart';
import 'package:gektusclashx/common/print.dart';
import 'package:gektusclashx/l10n/l10n.dart';

import 'effect.dart';

/// Presents the reminder only while the home route is visible and active.
/// The existing update banner remains responsible for progress and installation.
class AppUpdatePromptHost extends StatefulWidget {
  const AppUpdatePromptHost({
    super.key,
    required this.updates,
    required this.reminder,
    required this.onUpdate,
    required this.isAndroid,
    required this.isTV,
    required this.child,
  });

  final ValueListenable<AppUpdateState?>? updates;
  final AppUpdateReminder reminder;
  final Future<void> Function() onUpdate;
  final bool isAndroid;
  final bool isTV;
  final Widget child;

  @override
  State<AppUpdatePromptHost> createState() => _AppUpdatePromptHostState();
}

class _AppUpdatePromptHostState extends State<AppUpdatePromptHost> {
  Timer? _timer;
  bool _presenting = false;
  static const _delay = Duration(seconds: 5);

  @override
  void initState() {
    super.initState();
    widget.updates?.addListener(_schedule);
    _schedule();
  }

  @override
  void didUpdateWidget(covariant AppUpdatePromptHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.updates != widget.updates) {
      oldWidget.updates?.removeListener(_schedule);
      widget.updates?.addListener(_schedule);
      _schedule();
    }
  }

  void _schedule() {
    _timer?.cancel();
    if (!mounted ||
        _presenting ||
        widget.updates?.value?.phase != AppUpdatePhase.available) {
      return;
    }
    _timer = Timer(_delay, () => unawaited(_present()));
  }

  bool get _canPresent =>
      mounted &&
      (ModalRoute.of(context)?.isCurrent ?? false) &&
      (WidgetsBinding.instance.lifecycleState == null ||
          WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed);

  bool _isAvailableVersion(String version) =>
      widget.updates?.value?.phase == AppUpdatePhase.available &&
      widget.updates?.value?.version == version;

  Future<void> _present() async {
    final update = widget.updates?.value;
    if (!mounted || _presenting || update?.phase != AppUpdatePhase.available) {
      return;
    }
    if (!_canPresent) {
      _schedule();
      return;
    }
    _presenting = true;
    try {
      if (!await widget.reminder.shouldShow(update!.version)) return;
      if (!mounted) return;
      if (!_canPresent || !_isAvailableVersion(update.version)) {
        _scheduleAfterCheck();
        return;
      }
      final content = AppUpdatePrompt(
        version: update.version,
        isAndroid: widget.isAndroid,
        isTV: widget.isTV,
      );
      final Future<bool?> result;
      if (!widget.isTV && MediaQuery.sizeOf(context).width < 600) {
        result = showModalBottomSheet<bool>(
          context: context,
          isScrollControlled: true,
          useSafeArea: true,
          backgroundColor: Theme.of(context).colorScheme.surfaceContainerHigh,
          shape: const RoundedSuperellipseBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          ),
          clipBehavior: Clip.antiAlias,
          builder: (_) => SafeArea(top: false, child: content),
        );
      } else {
        result = showDialog<bool>(
          context: context,
          builder: (context) => Dialog(
            backgroundColor: Theme.of(context).colorScheme.surfaceContainerHigh,
            shape: const RoundedSuperellipseBorder(
              borderRadius: BorderRadius.all(Radius.circular(32)),
            ),
            clipBehavior: Clip.antiAlias,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: content,
            ),
          ),
        );
      }
      // Persist only after the route has actually been presented.
      unawaited(
          widget.reminder.markShown(update.version).catchError((Object error) {
        commonPrint.log('Could not save app update reminder: $error');
      }));
      final accepted = await result;
      if ((accepted ?? false) &&
          mounted &&
          _isAvailableVersion(update.version)) {
        await widget.onUpdate();
      }
    } catch (error) {
      commonPrint.log('App update reminder failed: $error');
    } finally {
      _presenting = false;
      if (mounted && widget.updates?.value?.version != update?.version) {
        _schedule();
      }
    }
  }

  void _scheduleAfterCheck() {
    // Recheck after a route or update changed while loading preferences.
    if (!mounted) return;
    _timer?.cancel();
    _timer = Timer(_delay, () => unawaited(_present()));
  }

  @override
  void dispose() {
    _timer?.cancel();
    widget.updates?.removeListener(_schedule);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class AppUpdatePrompt extends StatelessWidget {
  const AppUpdatePrompt({
    super.key,
    required this.version,
    required this.isAndroid,
    required this.isTV,
  });

  final String version;
  final bool isAndroid;
  final bool isTV;

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: ShapeDecoration(
                color: colors.primaryContainer,
                shape: const RoundedSuperellipseBorder(
                  borderRadius: BorderRadius.all(Radius.circular(20)),
                ),
              ),
              child: Icon(Icons.system_update_rounded,
                  color: colors.onPrimaryContainer, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(child: Text(appName, style: theme.textTheme.titleMedium)),
            IconButton(
              tooltip: MaterialLocalizations.of(context).closeButtonLabel,
              onPressed: () => Navigator.of(context).pop(false),
              icon: const Icon(Icons.close_rounded),
            ),
          ]),
          const SizedBox(height: 24),
          Text(strings.appUpdatePromptTitle,
              style: theme.textTheme.headlineSmall),
          const SizedBox(height: 12),
          Text(version,
              style:
                  theme.textTheme.titleMedium?.copyWith(color: colors.primary)),
          const SizedBox(height: 16),
          Text(
            isAndroid
                ? strings.appUpdatePromptDescription
                : strings.appUpdatePromptDesktopDescription,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          OverflowBar(
            alignment: MainAxisAlignment.end,
            spacing: 12,
            overflowSpacing: 12,
            children: [
              TVFocusEffect(
                enabled: isTV,
                borderRadius: BorderRadius.circular(28),
                child: TextButton(
                  autofocus: isTV,
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text(strings.appUpdateLater),
                ),
              ),
              TVFocusEffect(
                enabled: isTV,
                borderRadius: BorderRadius.circular(28),
                child: FilledButton.icon(
                  onPressed: () => Navigator.of(context).pop(true),
                  icon: const Icon(Icons.download_rounded),
                  label: Text(strings.update),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
