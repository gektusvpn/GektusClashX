import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gektusclashx/common/common.dart';
import 'package:gektusclashx/enum/enum.dart';
import 'package:gektusclashx/models/common.dart';
import 'package:gektusclashx/providers/config.dart';
import 'package:gektusclashx/state.dart';
import 'package:hotkey_manager/hotkey_manager.dart';

class HotKeyManager extends ConsumerStatefulWidget {
  const HotKeyManager({
    super.key,
    required this.child,
  });
  final Widget child;

  @override
  ConsumerState<HotKeyManager> createState() => _HotKeyManagerState();
}

class _HotKeyManagerState extends ConsumerState<HotKeyManager> {
  @override
  void initState() {
    super.initState();
    ref.listenManual(
      hotKeyActionsProvider,
      (prev, next) {
        if (!hotKeyActionListEquality.equals(prev, next)) {
          unawaited(_updateHotKeys(hotKeyActions: next));
        }
      },
      fireImmediately: true,
    );
  }

  Future<void> _handleHotKeyAction(HotAction action) async {
    switch (action) {
      case HotAction.mode:
        globalState.appController.updateMode();
      case HotAction.start:
        await globalState.appController.updateStart();
      case HotAction.view:
        await globalState.appController.updateVisible();
      case HotAction.proxy:
        globalState.appController.updateSystemProxy();
      case HotAction.tun:
        globalState.appController.updateTun();
    }
  }

  Future<void> _updateHotKeys({
    required List<HotKeyAction> hotKeyActions,
  }) async {
    await hotKeyManager.unregisterAll();
    final hotkeyActionHandles = hotKeyActions
        .where(
      (hotKeyAction) =>
          hotKeyAction.key != null && hotKeyAction.modifiers.isNotEmpty,
    )
        .map<Future>(
      (hotKeyAction) async {
        final modifiers = hotKeyAction.modifiers
            .map((item) => item.toHotKeyModifier())
            .toList();
        final hotKey = HotKey(
          key: PhysicalKeyboardKey(hotKeyAction.key!),
          modifiers: modifiers,
        );
        return hotKeyManager.register(
          hotKey,
          keyDownHandler: (_) {
            unawaited(_handleHotKeyAction(hotKeyAction.action));
          },
        );
      },
    );
    await Future.wait(hotkeyActionHandles);
  }

  Shortcuts _buildShortcuts(Widget child) => Shortcuts(
        shortcuts: {
          utils.controlSingleActivator(LogicalKeyboardKey.keyW):
              const CloseWindowIntent(),
        },
        child: Actions(
          actions: {
            CloseWindowIntent: CallbackAction<CloseWindowIntent>(
              onInvoke: (_) => globalState.appController.handleBackOrExit(),
            ),
            DoNothingIntent: CallbackAction<DoNothingIntent>(
              onInvoke: (_) => null,
            ),
          },
          child: child,
        ),
      );

  @override
  Widget build(BuildContext context) => _buildShortcuts(
        widget.child,
      );
}
