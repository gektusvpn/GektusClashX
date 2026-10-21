import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gektusclashx/enum/enum.dart';
import 'package:gektusclashx/l10n/l10n.dart';
import 'package:gektusclashx/models/models.dart';
import 'package:gektusclashx/providers/providers.dart';
import 'package:gektusclashx/widgets/tv_controls.dart';
import 'package:gektusclashx/widgets/tv_navigation_drawer.dart';

void main() {
  setUp(() async {
    await AppLocalizations.load(const Locale('en'));
  });

  testWidgets(
      'drawer focus does not select a destination and right restores content',
      (tester) async {
    final contentFocus = FocusNode();
    final colors = ColorScheme.fromSeed(
        seedColor: Colors.green, brightness: Brightness.dark);
    await tester.pumpWidget(ProviderScope(
      overrides: [currentProfileProvider.overrideWith((ref) => null)],
      child: MaterialApp(
          theme: ThemeData(colorScheme: colors),
          home: Scaffold(
            body: Stack(children: [
              Positioned.fill(
                  left: 80,
                  child: TVPageFocus(
                      active: true,
                      child: Center(
                          child: TVDrawerEdge(
                              child: TextButton(
                                  focusNode: contentFocus,
                                  onPressed: () {},
                                  child: const Text('Content')))))),
              Positioned(
                  top: 0,
                  bottom: 0,
                  left: 0,
                  child: TVNavigationDrawer(
                    currentIndex: 0,
                    labelBuilder: (label) => label.name,
                    navigationItems: const [
                      NavigationItem(
                          icon: Icon(Icons.home_rounded),
                          label: PageLabel.dashboard,
                          view: SizedBox()),
                      NavigationItem(
                          icon: Icon(Icons.public),
                          label: PageLabel.proxies,
                          view: SizedBox()),
                      NavigationItem(
                          icon: Icon(Icons.settings),
                          label: PageLabel.tools,
                          view: SizedBox()),
                    ],
                  )),
            ]),
          )),
    ));
    contentFocus.requestFocus();
    await tester.pumpAndSettle();
    final before = tester.getRect(find.text('Content'));
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pumpAndSettle();
    expect(
        FocusManager.instance.primaryFocus?.debugLabel, 'TV drawer: dashboard');
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    expect(
        FocusManager.instance.primaryFocus?.debugLabel, 'TV drawer: proxies');
    // An accidental route selection would access the uninitialized controller.
    expect(tester.takeException(), isNull);
    expect(tester.getRect(find.text('Content')), before);
    final iconContext = tester.element(find.byIcon(Icons.public));
    expect(IconTheme.of(iconContext).color, colors.onPrimary);
    final homeIcon = tester.element(find.byIcon(Icons.home_rounded));
    expect(IconTheme.of(homeIcon).color, colors.onSecondaryContainer);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    expect(contentFocus.hasPrimaryFocus, isTrue);
    expect(isTVNavigationDrawerFocused, isFalse);
    await tester.pumpWidget(const SizedBox());
    contentFocus.dispose();
  });

  testWidgets('revealing a TV tab only scrolls its own row', (tester) async {
    final pages = PageController(initialPage: 1);
    final row = ScrollController();
    late BuildContext lastTab;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: PageView(
      controller: pages,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        const Text('Dashboard'),
        Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 400,
              height: 60,
              child: SingleChildScrollView(
                controller: row,
                scrollDirection: Axis.horizontal,
                child: Row(
                    children: List.generate(
                        10,
                        (index) => Builder(builder: (context) {
                              if (index == 9) lastTab = context;
                              return SizedBox(
                                  width: 120, child: Text('Tab $index'));
                            }))),
              ),
            )),
      ],
    ))));
    await tester.pumpAndSettle();
    revealTVFocus(lastTab);
    await tester.pumpAndSettle();
    expect(row.offset, greaterThan(0));
    expect(pages.page, 1);
    await tester.pumpWidget(const SizedBox());
    row.dispose();
    pages.dispose();
  });
}
