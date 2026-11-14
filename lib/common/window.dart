import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:gektusclashx/common/common.dart';
import 'package:gektusclashx/models/config.dart';
import 'package:gektusclashx/state.dart';
import 'package:screen_retriever/screen_retriever.dart';
import 'package:window_ext/window_ext.dart';
import 'package:window_manager/window_manager.dart';

import 'startup_diagnostics.dart';
import 'window_geometry.dart';

class Window {
  Window({bool? isWindows, void Function(String)? diagnosticLog})
      : _isWindows = isWindows ?? Platform.isWindows,
        _log = diagnosticLog ?? startupLog;
  final bool _isWindows;
  final void Function(String) _log;
  WindowProps? _restoredProps;
  Future<void> _geometryQueue = Future.value();
  bool restoringGeometry = false;

  Future<void> _serializeGeometry(Future<void> Function() action) {
    final result = _geometryQueue.then((_) => action());
    _geometryQueue = result.catchError((Object error, StackTrace stack) {
      _log('geometry failed: $error\n$stack');
    });
    return _geometryQueue;
  }

  List<WindowDisplay> _displays(NativeGeometry snapshot) => snapshot.displays
      .map((d) => WindowDisplay(d.workArea, d.scale, primary: d.primary))
      .toList();

  WindowProps _props(NativeGeometry snapshot) => WindowProps(
      left: snapshot.bounds.left / snapshot.scale,
      top: snapshot.bounds.top / snapshot.scale,
      width: snapshot.bounds.width / snapshot.scale,
      height: snapshot.bounds.height / snapshot.scale,
      positionScale: snapshot.scale);

  Future<WindowProps?> captureNormalGeometry() async {
    if (!_isWindows || restoringGeometry) return null;
    WindowProps? props;
    await _serializeGeometry(() async {
      final snapshot = await windowExtManager.getGeometrySnapshot();
      if (!snapshot.normal ||
          !validWindowRect(snapshot.bounds) ||
          !snapshot.scale.isFinite ||
          snapshot.scale <= 0 ||
          !coveredByDisplays(snapshot.bounds, _displays(snapshot))) {
        return;
      }
      props = _props(snapshot);
    });
    return props;
  }

  Future<void> ensureVisibleGeometry({WindowProps? saved}) =>
      _serializeGeometry(() async {
        if (!_isWindows) return;
        restoringGeometry = true;
        try {
          var snapshot = await windowExtManager.getGeometrySnapshot();
          _log('geometry before: $snapshot saved=$saved');
          if (saved == null && !snapshot.normal) return;
          var props = saved ?? _props(snapshot);
          for (var attempt = 0; attempt < 3; attempt++) {
            final placement = restoreWindowGeometry(
              displays: _displays(snapshot),
              logicalSize: Size(props.width, props.height),
              savedPosition: props.left == null || props.top == null
                  ? null
                  : Offset(props.left!, props.top!),
              savedScale: props.positionScale ?? snapshot.scale,
            );
            if (placement == null) {
              _log('geometry: no usable displays; retaining native position');
              return;
            }
            _log('geometry ${placement.reason}: ${placement.bounds}');
            // Clear the previous monitor's minimum before a move to a smaller screen.
            if (snapshot.bounds != placement.bounds) {
              await windowManager.setMinimumSize(Size.zero);
              snapshot =
                  await windowExtManager.setPhysicalBounds(placement.bounds);
            }
            // Window manager multiplies the minimum by Flutter DPR. Convert from
            // target physical minimum using its current DPR (which may still lag).
            final flutterScale = WidgetsBinding.instance.platformDispatcher
                    .implicitView?.devicePixelRatio ??
                1;
            await windowManager.setMinimumSize(
                placement.minimumSize * (snapshot.scale / flutterScale));
            _log('geometry after: $snapshot');
            if (coveredByDisplays(snapshot.bounds, _displays(snapshot))) {
              _restoredProps = _props(snapshot);
              return;
            }
            props = attempt == 0
                ? _props(snapshot)
                : _props(snapshot).copyWith(left: null, top: null);
          }
          _log('geometry verification failed after bounded recovery');
        } finally {
          restoringGeometry = false;
        }
      });

  Future<void> showInitFailure({required bool reveal}) async {
    await windowManager.ensureInitialized();
    await windowManager.setPreventClose(false);
    await windowManager.waitUntilReadyToShow();
    await ensureVisibleGeometry(
        saved: const WindowProps(width: 680, height: 580));
    if (reveal) await show(source: 'startup failure');
  }

  Future<void> init(int version) async {
    final props = globalState.config.windowProps;
    final acquire = await singleInstanceLock.acquire();
    if (!acquire) {
      exit(0);
    }
    if (_isWindows) {
      protocol
        ..register("clashx")
        ..register("flclash")
        ..register("gektusclashx");
    }

    // On macOS, the app runs in status bar with popover - no window manager needed
    if (Platform.isMacOS) {
      return;
    }

    await windowManager.ensureInitialized();
    final windowOptions = WindowOptions(
      size: _isWindows ? null : Size(props.width, props.height),
      // Lock the minimum window size to 380×600 so it can't be shrunk below that
      // in either dimension — only grown.
      minimumSize: _isWindows ? null : const Size(380, 600),
    );
    await windowManager.setTitleBarStyle(TitleBarStyle.hidden);
    if (!_isWindows) {
      final left = props.left ?? 0;
      final top = props.top ?? 0;
      final right = left + props.width;
      final bottom = top + props.height;
      if (left == 0 && top == 0) {
        await windowManager.setAlignment(Alignment.center);
      } else {
        final displays = await screenRetriever.getAllDisplays();
        final isPositionValid = displays.any(
          (display) {
            final displayBounds = Rect.fromLTWH(
              display.visiblePosition!.dx,
              display.visiblePosition!.dy,
              display.size.width,
              display.size.height,
            );
            return displayBounds.contains(Offset(left, top)) ||
                displayBounds.contains(Offset(right, bottom));
          },
        );
        if (isPositionValid) {
          await windowManager.setPosition(
            Offset(
              left,
              top,
            ),
          );
        }
      }
    }
    await windowManager.waitUntilReadyToShow(windowOptions);
    await windowManager.setPreventClose(true);
    if (_isWindows) {
      await ensureVisibleGeometry(saved: props);
      if (_restoredProps != null) {
        globalState.config =
            globalState.config.copyWith(windowProps: _restoredProps!);
      }
    }
  }

  Future<void> applyStartupVisibility({required bool silentLaunch}) async {
    if (silentLaunch) {
      await hide();
    } else {
      await show(source: 'startup first frame');
    }
  }

  Future<void> show({String source = 'explicit'}) async {
    if (Platform.isMacOS) return;

    _log('show requested source=$source');
    render?.resume();
    if (_isWindows) {
      if (await windowManager.isMinimized()) await windowManager.restore();
      await ensureVisibleGeometry();
    }
    await windowManager.show();
    await windowManager.focus();
    await windowManager.setSkipTaskbar(false);
    if (_isWindows) {
      try {
        _log('show complete: ${await windowExtManager.getGeometrySnapshot()}');
      } catch (error) {
        _log('show complete; snapshot unavailable: $error');
      }
    }
  }

  Future<bool> get isVisible async {
    if (Platform.isMacOS) return false;

    final value = await windowManager.isVisible();
    commonPrint.log("window visible check: $value");
    return value;
  }

  Future<void> close() async {
    try {
      // exit(0) bypasses the native window destruction callback that normally
      // removes the tray icon, leaving a stale icon in the Windows taskbar.
      await tray.destroy().timeout(const Duration(seconds: 2));
    } catch (error) {
      commonPrint.log('Failed to remove tray icon before exit: $error');
    } finally {
      exit(0);
    }
  }

  Future<void> hide() async {
    if (Platform.isMacOS) return;

    _log('hide requested');
    render?.pause();
    await windowManager.hide();
    await windowManager.setSkipTaskbar(true);
  }
}

final window = system.isDesktop ? Window() : null;
