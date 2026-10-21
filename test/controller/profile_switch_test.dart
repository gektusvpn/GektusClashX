import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gektusclashx/common/common.dart';
import 'package:gektusclashx/controller.dart';
import 'package:gektusclashx/models/models.dart';
import 'package:gektusclashx/providers/providers.dart';
import 'package:gektusclashx/state.dart';

class _RecordingController extends AppController {
  _RecordingController(super.context, super.ref);
  final applied = <String?>[];

  @override
  Future<void> applyProfile({bool silence = false}) async {
    applied.add(globalState.config.currentProfileId);
  }
}

Future<(_RecordingController, WidgetRef)> _mount(
    WidgetTester tester, Completer<bool> detection) async {
  globalState.config = const Config(
    themeProps: ThemeProps(),
    currentProfileId: 'a',
    profiles: [
      Profile(
        id: 'a',
        autoUpdateDuration: Duration(hours: 1),
        providerHeaders: {
          'gektusclashx-custom': 'update',
          'gektusclashx-settings': 'minimize',
        },
      ),
      Profile(id: 'b', autoUpdateDuration: Duration(hours: 1)),
    ],
  );
  globalState.appState = AppState(
    version: 1,
    viewSize: const Size(960, 540),
    requests: FixedList(1),
    logs: FixedList(1),
    traffics: FixedList(1),
    totalTraffic: Traffic(),
  );
  late _RecordingController controller;
  late WidgetRef widgetRef;
  await tester.pumpWidget(ProviderScope(
    overrides: [isAndroidTVProvider.overrideWith((ref) => detection.future)],
    child: Consumer(builder: (context, ref, _) {
      widgetRef = ref;
      controller = _RecordingController(context, ref);
      return const SizedBox();
    }),
  ));
  return (controller, widgetRef);
}

void main() {
  testWidgets(
      'stale header detection cannot overwrite a newly selected profile',
      (tester) async {
    final detection = Completer<bool>();
    final (controller, ref) = await _mount(tester, detection);
    final firstSwitch = controller.handleChangeProfile();
    ref.read(currentProfileIdProvider.notifier).value = 'b';
    await controller.handleChangeProfile();
    detection.complete(true);
    await firstSwitch;
    expect(ref.read(appSettingProvider).minimizeOnExit, isFalse);
    expect(controller.applied, ['b']);
    expect(tester.takeException(), isNull);
  });

  testWidgets('headers still apply when the selected profile is unchanged',
      (tester) async {
    final detection = Completer<bool>();
    final (controller, ref) = await _mount(tester, detection);
    final switching = controller.handleChangeProfile();
    detection.complete(true);
    await switching;
    expect(ref.read(appSettingProvider).minimizeOnExit, isTrue);
    expect(controller.applied, ['a']);
    expect(tester.takeException(), isNull);
  });

  testWidgets('removing the last profile does not read from an empty list',
      (tester) async {
    final (controller, ref) = await _mount(tester, Completer<bool>());
    ref.read(profilesProvider.notifier).deleteProfileById('a');
    ref.read(profilesProvider.notifier).deleteProfileById('b');
    await controller.handleChangeProfile();
    expect(controller.applied, ['a']);
    expect(tester.takeException(), isNull);
  });
}
