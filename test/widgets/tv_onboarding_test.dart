import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gektusclashx/common/file_logger.dart';
import 'package:gektusclashx/l10n/l10n.dart';
import 'package:gektusclashx/models/models.dart';
import 'package:gektusclashx/pages/home.dart';
import 'package:gektusclashx/providers/providers.dart';
import 'package:gektusclashx/state.dart';
import 'package:gektusclashx/views/profiles/receive_profile_dialog.dart';
import 'package:gektusclashx/widgets/scaffold.dart';
import 'package:gektusclashx/widgets/sheet.dart';
import 'package:gektusclashx/widgets/tv_navigation_drawer.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

class _TestPaths extends PathProviderPlatform {
  _TestPaths(this.root);
  final String root;

  @override
  Future<String?> getApplicationSupportPath() async => root;
  @override
  Future<String?> getTemporaryPath() async => root;
  @override
  Future<String?> getDownloadsPath() async => root;
}

Future<void> _open(WidgetTester tester, {required bool tv}) async {
  tester.view.physicalSize = const Size(960, 540);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  globalState.config = const Config(themeProps: ThemeProps());
  await tester.pumpWidget(ProviderScope(
    overrides: [
      isAndroidTVProvider.overrideWith((ref) async => tv),
      startButtonSelectorStateProvider.overrideWith((ref) =>
          const StartButtonSelectorState(
              isInit: true, hasProfile: false, hasProxiesInit: false)),
    ],
    child: const MaterialApp(
      localizationsDelegates: [AppLocalizations.delegate],
      home: HomePage(),
    ),
  ));
  // Allow provider resolution and focus/route animation without waiting for
  // the network spinner, which may intentionally remain active on a test host.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}

void main() {
  final originalPaths = PathProviderPlatform.instance;
  late Directory logDirectory;
  setUpAll(() async {
    logDirectory = await Directory.systemTemp.createTemp('tv-onboarding-test-');
    PathProviderPlatform.instance = _TestPaths(logDirectory.path);
  });
  tearDownAll(() async {
    await fileLogger.dispose();
    PathProviderPlatform.instance = originalPaths;
    await logDirectory.delete(recursive: true);
  });
  setUp(() async => AppLocalizations.load(const Locale('en')));

  testWidgets(
      'empty TV dashboard starts receiver and offers URL/file alternatives',
      (tester) async {
    await _open(tester, tv: true);
    expect(find.byType(ReceiveProfileView), findsOneWidget);
    expect(find.byType(TVNavigationDrawer), findsNothing);
    final scaffold = tester.widget<CommonScaffold>(find.byType(CommonScaffold));
    expect(scaffold.sideNavigationBar, isNull);
    expect(scaffold.bottomNavigationBar, isNull);
    expect(find.byType(ReceiveProfileDialog), findsNothing);
    expect(find.text('Add from Phone'), findsOneWidget);
    expect(find.text('Start with a profile'), findsNothing);
    expect(Focus.of(tester.element(find.text('Another way'))).hasFocus, isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text(AppLocalizations.current.url), findsOneWidget);
    expect(find.text(AppLocalizations.current.file), findsOneWidget);
    expect(tester.getSize(find.byType(AdaptiveSheetScaffold)).height,
        lessThan(360));
    // Phone transfer is already visible; do not start a second receiver.
    expect(find.text('Add from Phone'), findsOneWidget);
    expect(find.text(AppLocalizations.current.qrcode), findsNothing);
    await tester.binding.handlePopRoute();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(Focus.of(tester.element(find.text('Another way'))).hasFocus, isTrue);
    await tester.pumpWidget(const SizedBox());
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    expect(ReceiveProfileView.isActive, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('ordinary empty dashboard keeps its existing add-profile screen',
      (tester) async {
    await _open(tester, tv: false);
    expect(find.byType(ReceiveProfileView), findsNothing);
    expect(find.text('Another way'), findsNothing);
    expect(find.text('Start with a profile'), findsOneWidget);
    expect(find.text('Add Profile'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
