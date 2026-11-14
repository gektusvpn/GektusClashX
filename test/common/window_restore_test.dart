import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gektusclashx/common/render.dart';
import 'package:gektusclashx/common/window.dart';
import 'package:gektusclashx/models/config.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const native = MethodChannel('window_ext');
  const manager = MethodChannel('window_manager');
  late Window window;
  late Map<String, Object?> snapshot;
  late List<String> calls;
  late List<String> logs;
  Completer<void>? pendingPlacement;
  bool failSnapshot = false;
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  setUp(() {
    calls = [];
    logs = [];
    pendingPlacement = null;
    failSnapshot = false;
    window = Window(isWindows: true, diagnosticLog: logs.add);
    snapshot = {
      'x': 10.0,
      'y': 10.0,
      'width': 450.0,
      'height': 900.0,
      'scale': 1.0,
      'visible': false,
      'minimized': false,
      'maximized': false,
      'fullscreen': false,
      'displays': [
        {
          'x': 0.0,
          'y': 0.0,
          'width': 1920.0,
          'height': 1040.0,
          'scale': 1.0,
          'primary': true
        }
      ]
    };
    messenger.setMockMethodCallHandler(native, (call) async {
      calls.add(call.method);
      if (failSnapshot) throw PlatformException(code: 'display-unavailable');
      if (call.method == 'setPhysicalBounds') {
        await pendingPlacement?.future;
        snapshot.addAll(Map<String, Object?>.from(call.arguments as Map));
      }
      return snapshot;
    });
    messenger.setMockMethodCallHandler(manager, (call) async {
      calls.add(call.method);
      if (call.method == 'show') snapshot['visible'] = true;
      if (call.method == 'hide') snapshot['visible'] = false;
      if (call.method == 'restore') snapshot['minimized'] = false;
      if (call.method == 'isMinimized') return snapshot['minimized'];
      return null;
    });
  });
  tearDown(() {
    render?.resume();
    messenger.setMockMethodCallHandler(native, null);
    messenger.setMockMethodCallHandler(manager, null);
  });

  test('physical placement precedes show; valid normal bounds are captured',
      () async {
    snapshot['x'] = 9000.0;
    await window.applyStartupVisibility(silentLaunch: false);
    expect(calls.indexOf('setPhysicalBounds'), lessThan(calls.indexOf('show')));
    final props = await window.captureNormalGeometry();
    expect(props!.left, 735);
    expect(props.positionScale, 1);
    expect(snapshot['visible'], isTrue);
  });

  test('silent startup never shows, focuses, or repositions', () async {
    await window.applyStartupVisibility(silentLaunch: true);
    expect(calls, ['hide', 'setSkipTaskbar']);
    expect(snapshot['visible'], isFalse);
  });

  test('display changes repair hidden windows without revealing them',
      () async {
    await window.ensureVisibleGeometry(
        saved: const WindowProps(left: 99999, top: 100));
    expect(snapshot['visible'], isFalse);
    expect(calls, isNot(contains('show')));
    expect((await window.captureNormalGeometry())!.left, 735);
  });

  test('transient restoration and non-normal states never get saved', () async {
    pendingPlacement = Completer<void>();
    final restoring = window.ensureVisibleGeometry(saved: const WindowProps());
    while (!calls.contains('setPhysicalBounds')) {
      await Future<void>.delayed(Duration.zero);
    }
    expect(await window.captureNormalGeometry(), isNull);
    pendingPlacement!.complete();
    await restoring;
    for (final state in ['minimized', 'maximized', 'fullscreen']) {
      snapshot[state] = true;
      expect(await window.captureNormalGeometry(), isNull);
      snapshot[state] = false;
    }
  });

  test('display enumeration failure does not prevent subsequent recovery',
      () async {
    failSnapshot = true;
    await window.ensureVisibleGeometry(saved: const WindowProps());
    expect(logs.any((line) => line.contains('geometry failed')), isTrue);
    expect(window.restoringGeometry, isFalse);
    await window.applyStartupVisibility(silentLaunch: false);
    expect(snapshot['visible'], isTrue);
    failSnapshot = false;
    await window.ensureVisibleGeometry(saved: const WindowProps());
    expect(calls, contains('setPhysicalBounds'));
  });

  test('no displays retains native position and never persists it', () async {
    snapshot['displays'] = [];
    await window.ensureVisibleGeometry(saved: const WindowProps());
    expect(calls, isNot(contains('setPhysicalBounds')));
    expect(await window.captureNormalGeometry(), isNull);
  });
}
