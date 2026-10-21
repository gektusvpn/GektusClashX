import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gektusclashx/l10n/l10n.dart';
import 'package:gektusclashx/providers/providers.dart';
import 'package:gektusclashx/widgets/list.dart';
import 'package:gektusclashx/widgets/sheet.dart';

void main() {
  setUp(() async => AppLocalizations.load(const Locale('en')));

  testWidgets('TV setting uses one focus stop and OK toggles once',
      (tester) async {
    final first = FocusNode();
    final next = FocusNode();
    var changes = 0;
    await tester.pumpWidget(ProviderScope(
      overrides: [isAndroidTVProvider.overrideWith((ref) async => true)],
      child: MaterialApp(
          home: Scaffold(
              body: Column(children: [
        ListItem.switchItem(
          focusNode: first,
          title: const Text('Setting'),
          delegate: SwitchDelegate(value: false, onChanged: (_) => changes++),
        ),
        TextButton(
            focusNode: next, onPressed: () {}, child: const Text('Next')),
      ]))),
    ));
    await tester.pumpAndSettle();
    first.requestFocus();
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pumpAndSettle();
    expect(changes, 1);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();
    expect(next.hasPrimaryFocus, isTrue);
    await tester.pumpWidget(const SizedBox());
    first.dispose();
    next.dispose();
  });

  testWidgets('TV settings open in a centered dialog with content focus',
      (tester) async {
    tester.view.physicalSize = const Size(960, 540);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final option = FocusNode();
    await tester.pumpWidget(ProviderScope(
      overrides: [isAndroidTVProvider.overrideWith((ref) async => true)],
      child: MaterialApp(
          home: Scaffold(
              body: Builder(
                  builder: (context) => TextButton(
                      autofocus: true,
                      onPressed: () => showExtend<void>(context,
                          builder: (_, type) => AdaptiveSheetScaffold(
                              type: type,
                              title: 'Settings',
                              body: SingleChildScrollView(
                                  child: Column(children: [
                                SizedBox(
                                    height: 64,
                                    child: ListView(
                                      scrollDirection: Axis.horizontal,
                                      children: [
                                        TextButton(
                                            focusNode: option,
                                            onPressed: () {},
                                            child: const Text('Option'))
                                      ],
                                    )),
                                // Lazy list children attach after this button.
                                TextButton(
                                    onPressed: () {},
                                    child: const Text('Lower option')),
                              ])))),
                      child: const Text('Open'))))),
    ));
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pumpAndSettle();
    final rect = tester.getRect(find.byType(AdaptiveSheetScaffold));
    expect(rect.center.dx, 480);
    expect(rect.width, 640);
    expect(option.hasPrimaryFocus, isTrue);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    option.dispose();
  });
}
