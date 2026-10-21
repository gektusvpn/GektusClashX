import 'dart:async';
import 'dart:io';

import 'package:gektusclashx/common/utils.dart';
import 'package:gektusclashx/models/models.dart';
import 'package:gektusclashx/state.dart';
import 'package:tray_manager/tray_manager.dart';

import 'app_localizations.dart';
import 'constant.dart';
import 'window.dart';

class Tray {
  String? _iconPath;
  bool _iconRequested = false;
  Future<void> _pendingUpdate = Future.value();
  Future<void>? _destroyFuture;

  /// Serialize teardown after pending updates so they cannot recreate the icon.
  Future<void> destroy() => _destroyFuture ??= _destroy();

  Future<void> _destroy() async {
    await _pendingUpdate;
    if (!_iconRequested || Platform.isAndroid || Platform.isMacOS) return;
    await trayManager.destroy();
    _iconPath = null;
  }

  Future<void> _updateSystemTray({
    required bool isRunning,
  }) async {
    if (Platform.isAndroid || Platform.isMacOS) {
      // Skip tray on Android and macOS (macOS uses native status bar)
      return;
    }

    final iconPath = utils.getTrayIconPath(isRunning: isRunning);
    if (_iconPath == iconPath) return;

    _iconRequested = true;
    await trayManager.setIcon(iconPath);
    _iconPath = iconPath;
    if (_destroyFuture == null && !Platform.isLinux) {
      await trayManager.setToolTip(
        appName,
      );
    }
  }

  Future<void> update({required TrayState trayState}) {
    if (_destroyFuture != null) return Future.value();
    final update = _pendingUpdate.then((_) async {
      if (_destroyFuture != null) return;
      await _update(trayState: trayState);
    });
    // Keep teardown and later updates working even if a native call fails.
    _pendingUpdate = update.catchError((Object _) {});
    return update;
  }

  Future<void> _update({required TrayState trayState}) async {
    if (Platform.isAndroid || Platform.isMacOS) {
      // Skip tray on Android and macOS (macOS uses native status bar)
      return;
    }
    await _updateSystemTray(
      isRunning: trayState.isStart,
    );
    if (_destroyFuture != null) return;
    final menuItems = <MenuItem>[];
    final showMenuItem = MenuItem(
      label: appLocalizations.show,
      onClick: (_) {
        unawaited(window?.show());
      },
    );
    menuItems.add(showMenuItem);
    final startMenuItem = MenuItem(
      label: trayState.isStart
          ? appLocalizations.disableVpn
          : appLocalizations.enableVpn,
      onClick: (_) async {
        await globalState.appController.updateStart();
      },
    );
    menuItems
      ..add(startMenuItem)
      ..add(MenuItem.separator());
    final restartMenuItem = MenuItem(
      label: appLocalizations.restart,
      onClick: (_) async {
        await globalState.appController.handleRestart();
      },
    );
    menuItems.add(restartMenuItem);
    final exitMenuItem = MenuItem(
      label: appLocalizations.exit,
      onClick: (_) async {
        await globalState.appController.handleExit();
      },
    );
    menuItems.add(exitMenuItem);
    final menu = Menu(items: menuItems);
    await trayManager.setContextMenu(menu);
  }

  Future<void> updateTrayTitle([Traffic? traffic]) async {}
}

final tray = Tray();
