import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gektusclashx/controller.dart';
import 'package:gektusclashx/enum/enum.dart';
import 'package:gektusclashx/l10n/l10n.dart';
import 'package:gektusclashx/models/models.dart';
import 'package:gektusclashx/providers/providers.dart';
import 'package:gektusclashx/state.dart';
import 'package:gektusclashx/views/proxies/list.dart';

import '../support/news_test_app.dart';

void main() {
  for (final initiallyExpanded in [false, true]) {
    testWidgets(
        'delay test expands group and preserves other groups '
        '(already expanded: $initiallyExpanded)', (tester) async {
      initializeNewsTestState();
      await AppLocalizations.load(const Locale('en'));
      globalState.config = Config(
        themeProps: const ThemeProps(),
        currentProfileId: 'test',
        profiles: [
          Profile(
            id: 'test',
            autoUpdateDuration: const Duration(hours: 1),
            unfoldSet: {'Other', if (initiallyExpanded) 'Servers'},
          ),
        ],
      );
      late WidgetRef widgetRef;
      await tester.pumpWidget(ProviderScope(
        overrides: [isAndroidTVProvider.overrideWith((ref) async => false)],
        child: MaterialApp(
          localizationsDelegates: const [AppLocalizations.delegate],
          home: Consumer(builder: (context, ref, _) {
            widgetRef = ref;
            globalState.appController = AppController(context, ref);
            return const Scaffold(
              body: SingleChildScrollView(
                child: ProxyGroupCard(
                  group: Group(name: 'Servers', type: GroupType.Selector),
                  proxies: [SizedBox(height: 80, child: Text('Test proxy'))],
                  isFirst: true,
                  isLast: true,
                ),
              ),
            );
          }),
        ),
      ));
      await tester.pumpAndSettle();
      if (!initiallyExpanded) {
        expect(find.text('Test proxy').hitTestable(), findsNothing);
      }
      // Empty group members avoid invoking the native core; the action still
      // completes the normal delay test and updates its sorting counter.
      for (var press = 0; press < 2; press++) {
        final sortNum = widgetRef.read(sortNumProvider);
        await tester.tap(find.byIcon(Icons.speed_rounded));
        await tester.pumpAndSettle();
        expect(find.text('Test proxy').hitTestable(), findsOneWidget);
        expect(widgetRef.read(unfoldSetProvider), {'Other', 'Servers'});
        expect(widgetRef.read(sortNumProvider), sortNum + 1);
      }
      expect(tester.takeException(), isNull);
    });
  }
}
