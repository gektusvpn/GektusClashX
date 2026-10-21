import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gektusclashx/common/tray.dart';
import 'package:gektusclashx/enum/enum.dart';
import 'package:gektusclashx/l10n/l10n.dart';
import 'package:gektusclashx/models/models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('tray_manager');
  const state = TrayState(
    mode: Mode.rule,
    port: 7890,
    autoLaunch: false,
    systemProxy: false,
    tunEnable: false,
    isStart: false,
    locale: null,
    brightness: null,
    groups: [],
    selectedMap: {},
  );
  final calls = <String>[];

  setUp(() async {
    calls.clear();
    await AppLocalizations.load(const Locale('en'));
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call.method);
      return true;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('exit before the first tray update does not destroy an uncreated icon',
      () async {
    final tray = Tray();
    final updating = tray.update(trayState: state);
    await tray.destroy();
    await updating;
    expect(calls, isEmpty);
  });

  test('exit removes the icon once and prevents later updates', () async {
    final tray = Tray();
    await tray.update(trayState: state);
    expect(calls, containsAllInOrder(['setIcon', 'setContextMenu']));
    await tray.destroy();
    final afterExit = List.of(calls);
    await tray.destroy();
    await tray.update(trayState: state.copyWith(isStart: true));
    expect(calls, afterExit);
    expect(calls.where((method) => method == 'destroy'), hasLength(1));
    expect(calls.last, 'destroy');
  });

  test('exit waits for an in-flight icon update and skips queued updates',
      () async {
    final iconStarted = Completer<void>();
    final releaseIcon = Completer<void>();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call.method);
      if (call.method == 'setIcon') {
        iconStarted.complete();
        await releaseIcon.future;
      }
      return true;
    });
    final tray = Tray();
    final updating = tray.update(trayState: state);
    await iconStarted.future;
    final queued = tray.update(trayState: state.copyWith(isStart: true));
    final destroying = tray.destroy();
    expect(calls, ['setIcon']);
    releaseIcon.complete();
    await Future.wait([updating, queued, destroying]);
    expect(calls, ['setIcon', 'destroy']);
  });

  test('a failed native update does not prevent removal', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call.method);
      if (call.method == 'setIcon') throw PlatformException(code: 'test');
      return true;
    });
    final tray = Tray();
    await expectLater(
        tray.update(trayState: state), throwsA(isA<PlatformException>()));
    await tray.destroy();
    expect(calls, ['setIcon', 'destroy']);
  });
}
