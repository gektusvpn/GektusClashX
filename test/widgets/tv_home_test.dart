import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gektusclashx/common/common.dart';
import 'package:gektusclashx/enum/enum.dart';
import 'package:gektusclashx/l10n/l10n.dart';
import 'package:gektusclashx/models/models.dart';
import 'package:gektusclashx/pages/home.dart';
import 'package:gektusclashx/providers/providers.dart';
import 'package:gektusclashx/state.dart';
import 'package:gektusclashx/widgets/tv_navigation_drawer.dart';

void main() {
  setUp(() async {
    await AppLocalizations.load(const Locale('en'));
    globalState.config = const Config(
      themeProps: ThemeProps(),
      appSetting: AppSettingProps(showLabel: true),
    );
    globalState.appState = AppState(
      version: 1,
      viewSize: const Size(500, 540),
      pageLabel: PageLabel.profiles,
      requests: FixedList(1),
      logs: FixedList(1),
      traffics: FixedList(1),
      totalTraffic: Traffic(),
    );
  });

  testWidgets('TV falls back from unavailable section, even at mobile width',
      (tester) async {
    tester.view.physicalSize = const Size(500, 540);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    const items = [
      NavigationItem(
        icon: Icon(Icons.home),
        label: PageLabel.dashboard,
        view: Center(child: Text('Home content')),
      ),
      NavigationItem(
        icon: Icon(Icons.settings),
        label: PageLabel.tools,
        view: Text('Settings content'),
      ),
    ];
    final container = ProviderContainer(overrides: [
      isAndroidTVProvider.overrideWith((ref) async => true),
      startButtonSelectorStateProvider.overrideWith((ref) =>
          const StartButtonSelectorState(
              isInit: true, hasProfile: true, hasProxiesInit: false)),
      currentNavigationsStateProvider
          .overrideWith((ref) => const NavigationItemsState(value: items)),
      currentProfileProvider.overrideWith((ref) => null),
    ]);
    await container.read(isAndroidTVProvider.future);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(
        localizationsDelegates: [AppLocalizations.delegate],
        home: HomePage(),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Home content'), findsOneWidget);
    expect(container.read(currentPageLabelProvider), PageLabel.dashboard);
    expect(find.byType(TVNavigationDrawer), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    expect(find.byType(NavigationRail), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    container.dispose();
  });

  testWidgets('desktop rail preserves its logo caption when labels are enabled',
      (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [isAndroidTVProvider.overrideWith((ref) async => false)],
      child: const MaterialApp(
        localizationsDelegates: [AppLocalizations.delegate],
        home: Scaffold(
          body: Row(children: [
            CommonNavigationBar(
              viewMode: ViewMode.desktop,
              currentIndex: 0,
              navigationItems: [
                NavigationItem(
                    icon: Icon(Icons.home),
                    label: PageLabel.dashboard,
                    view: SizedBox()),
              ],
            ),
          ]),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text(appName), findsOneWidget);
    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(TVNavigationDrawer), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
