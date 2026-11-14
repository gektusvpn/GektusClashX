import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gektusclashx/common/app_release.dart';
import 'package:gektusclashx/common/app_update.dart';
import 'package:gektusclashx/common/common.dart' show FixedList;
import 'package:gektusclashx/controller.dart';
import 'package:gektusclashx/l10n/l10n.dart';
import 'package:gektusclashx/models/models.dart';
import 'package:gektusclashx/providers/app.dart';
import 'package:gektusclashx/providers/config.dart';
import 'package:gektusclashx/state.dart';
import 'package:gektusclashx/views/about.dart';

class _PendingController extends AppController {
  _PendingController(super.context, super.ref);
  final result = Completer<Map<String, dynamic>?>();
  AppUpdateChannel? requestedChannel;

  @override
  Future<Map<String, dynamic>?> fetchAppUpdate(AppUpdateChannel channel) {
    requestedChannel = channel;
    return result.future;
  }
}

void main() {
  late _PendingController controller;
  late WidgetRef settingsRef;

  Future<void> mount(WidgetTester tester) async {
    globalState.config = const Config(themeProps: ThemeProps());
    globalState.appState = AppState(
      version: 1,
      viewSize: const Size(800, 600),
      requests: FixedList(1),
      logs: FixedList(1),
      traffics: FixedList(1),
      totalTraffic: Traffic(),
    );
    await tester.pumpWidget(ProviderScope(
      overrides: [isAndroidTVProvider.overrideWith((ref) async => false)],
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        home: Consumer(builder: (context, ref, _) {
          settingsRef = ref;
          ref.watch(appSettingProvider);
          controller = _PendingController(context, ref);
          globalState.appController = controller;
          return const Scaffold(body: UpdateChannelItem());
        }),
      ),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('channel can be changed with provider overrides disabled',
      (tester) async {
    await mount(tester);
    expect(
        settingsRef.read(appSettingProvider).overrideProviderSettings, isFalse);
    await tester.tap(find.text('Update channel'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Testing'));
    await tester.pumpAndSettle();
    expect(settingsRef.read(appSettingProvider).updateChannel,
        AppUpdateChannel.testing);
    expect(
        globalState.config.appSetting.updateChannel, AppUpdateChannel.testing);
  });

  testWidgets('switch clears offered update and ignores pending response',
      (tester) async {
    await mount(tester);
    final pendingController = controller;
    final checking = pendingController.checkAppUpdate();
    expect(pendingController.requestedChannel, AppUpdateChannel.stable);
    pendingController.appUpdateState.value =
        AppUpdateState.available(const {'tag_name': 'v0.6.0'});
    settingsRef.read(appSettingProvider.notifier).updateState(
        (state) => state.copyWith(updateChannel: AppUpdateChannel.testing));
    expect(pendingController.appUpdateState.value, isNull);
    pendingController.result.complete({'tag_name': 'v0.6.0'});
    await checking;
    expect(pendingController.appUpdateState.value, isNull);
  });

  testWidgets(
      'switching back does not revive a result from the original channel',
      (tester) async {
    await mount(tester);
    final pendingController = controller;
    final checking = pendingController.checkAppUpdate();
    for (final channel in [AppUpdateChannel.testing, AppUpdateChannel.stable]) {
      settingsRef
          .read(appSettingProvider.notifier)
          .updateState((state) => state.copyWith(updateChannel: channel));
    }
    pendingController.result.complete({'tag_name': 'v0.6.0'});
    await checking;
    expect(pendingController.appUpdateState.value, isNull);
  });

  testWidgets('switch ignores errors from an obsolete check', (tester) async {
    await mount(tester);
    final pendingController = controller;
    final checking = pendingController.checkAppUpdate(handleError: true);
    settingsRef.read(appSettingProvider.notifier).updateState(
        (state) => state.copyWith(updateChannel: AppUpdateChannel.testing));
    pendingController.result.completeError(StateError('old request failed'));
    await checking;
    expect(pendingController.appUpdateState.value, isNull);
    expect(tester.takeException(), isNull);
  });
}
