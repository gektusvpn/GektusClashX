import 'dart:ui' show PointerDeviceKind, Tristate;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gektusclashx/models/common.dart';
import 'package:gektusclashx/widgets/icon.dart';
import 'package:gektusclashx/widgets/popup.dart';

Future<void> _mount(WidgetTester tester, List<PopupMenuItemData> items,
    {Brightness brightness = Brightness.light,
    double width = 800,
    double scale = 1,
    FocusNode? triggerFocus}) async {
  tester.view.physicalSize = Size(width, 640);
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = scale;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  await tester.pumpWidget(MaterialApp(
    theme: ThemeData(
      colorScheme:
          ColorScheme.fromSeed(seedColor: Colors.green, brightness: brightness),
      visualDensity: VisualDensity.adaptivePlatformDensity,
    ),
    home: Scaffold(
      appBar: AppBar(title: const Text('Home'), actions: [
        CommonPopupBox(
          focusNode: triggerFocus,
          targetBuilder: (open, focusNode, statesController) =>
              CommonHeaderIconButton(
            tooltip: 'Menu',
            onPressed: open,
            focusNode: focusNode,
            statesController: statesController,
            icon: const Icon(Icons.more_vert),
          ),
          popup: CommonPopupMenu(items: items),
        ),
      ]),
      body: const SizedBox.expand(),
    ),
  ));
  await tester.pumpAndSettle();
}

MenuItemButton _item(WidgetTester tester, String label) =>
    tester.widget<MenuItemButton>(find.ancestor(
        of: find.text(label), matching: find.byType(MenuItemButton)));

BorderSide _itemBorder(WidgetTester tester, String label) {
  final material = tester.widget<Material>(find
      .descendant(
          of: find.byWidget(_item(tester, label)),
          matching: find.byType(Material))
      .first);
  return (material.shape! as OutlinedBorder).side;
}

void main() {
  testWidgets('desktop focus outline follows keyboard rather than mouse input',
      (tester) async {
    await _mount(tester, [
      PopupMenuItemData(label: 'First', onPressed: () {}),
      PopupMenuItemData(label: 'Second', onPressed: () {}),
    ]);
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    final triggerCenter = tester.getCenter(find.byTooltip('Menu'));
    await mouse.addPointer(location: triggerCenter);
    await mouse.down(triggerCenter);
    await mouse.up();
    await tester.pumpAndSettle();
    expect(_item(tester, 'First').focusNode!.hasFocus, isTrue);
    expect(_itemBorder(tester, 'First'), BorderSide.none);
    expect(
        _item(tester, 'First')
            .style!
            .overlayColor!
            .resolve({WidgetState.focused}),
        Colors.transparent);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    expect(_item(tester, 'Second').focusNode!.hasFocus, isTrue);
    expect(_itemBorder(tester, 'Second').width, 2);

    await mouse.moveTo(tester.getCenter(find.text('First')));
    await tester.pumpAndSettle();
    expect(_item(tester, 'First').focusNode!.hasFocus, isTrue);
    expect(_itemBorder(tester, 'First'), BorderSide.none);
    expect(_itemBorder(tester, 'Second'), BorderSide.none);
    expect(
        _item(tester, 'First')
            .style!
            .overlayColor!
            .resolve({WidgetState.hovered, WidgetState.focused}),
        isNot(Colors.transparent));
    await mouse.removePointer();

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(_item(tester, 'First').focusNode!.hasFocus, isTrue);
    expect(_itemBorder(tester, 'First').width, 2);
    expect(tester.takeException(), isNull);
  }, variant: TargetPlatformVariant.only(TargetPlatform.linux));

  testWidgets(
      'keyboard opens menu, selects an item, and restores trigger focus',
      (tester) async {
    final selected = <String>[];
    await _mount(tester, [
      PopupMenuItemData(label: 'First', onPressed: () => selected.add('First')),
      PopupMenuItemData(
          label: 'Second', onPressed: () => selected.add('Second')),
    ]);
    final button = tester.widget<IconButton>(find.descendant(
        of: find.byType(CommonHeaderIconButton),
        matching: find.byType(IconButton)));
    button.focusNode!.requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    expect(_item(tester, 'First').focusNode!.hasFocus, isTrue);
    expect(button.statesController!.value, contains(WidgetState.pressed));
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    expect(_item(tester, 'Second').focusNode!.hasFocus, isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(selected, ['Second']);
    expect(find.byType(MenuItemButton), findsNothing);
    expect(button.focusNode!.hasFocus, isTrue);
    expect(
        button.statesController!.value, isNot(contains(WidgetState.pressed)));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'mouse open holds pressed state; Escape and outside tap close menu',
      (tester) async {
    await _mount(
        tester, [PopupMenuItemData(label: 'Action', onPressed: () {})]);
    final button = tester.widget<IconButton>(find.descendant(
        of: find.byType(CommonHeaderIconButton),
        matching: find.byType(IconButton)));
    await tester.tap(find.byTooltip('Menu'));
    await tester.pumpAndSettle();
    expect(_item(tester, 'Action').focusNode!.hasFocus, isTrue);
    expect(button.statesController!.value, contains(WidgetState.pressed));
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(button.focusNode!.hasFocus, isTrue);
    await tester.tap(find.byTooltip('Menu'));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(20, 400));
    await tester.pumpAndSettle();
    expect(find.byType(MenuItemButton), findsNothing);
    expect(
        button.statesController!.value, isNot(contains(WidgetState.pressed)));
    expect(tester.takeException(), isNull);
  });

  testWidgets('disabled actions are skipped and letters/Home/End move focus',
      (tester) async {
    await _mount(tester, [
      const PopupMenuItemData(label: 'Disabled', onPressed: null),
      PopupMenuItemData(label: 'Alpha', onPressed: () {}),
      PopupMenuItemData(label: 'Beta', onPressed: () {}),
      PopupMenuItemData(label: 'Bravo', onPressed: () {}),
    ]);
    await tester.tap(find.byTooltip('Menu'));
    await tester.pumpAndSettle();
    expect(_item(tester, 'Alpha').focusNode!.hasFocus, isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyB, character: 'b');
    await tester.pumpAndSettle();
    expect(_item(tester, 'Beta').focusNode!.hasFocus, isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyB, character: 'b');
    await tester.pumpAndSettle();
    expect(_item(tester, 'Bravo').focusNode!.hasFocus, isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.home);
    await tester.pumpAndSettle();
    expect(_item(tester, 'Alpha').focusNode!.hasFocus, isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.end);
    await tester.pumpAndSettle();
    expect(_item(tester, 'Bravo').focusNode!.hasFocus, isTrue);
    expect(_item(tester, 'Disabled').onPressed, isNull);
    expect(tester.takeException(), isNull);
  });

  for (final brightness in Brightness.values) {
    testWidgets('Expressive menu geometry, colors, and selection ($brightness)',
        (tester) async {
      final semantics = tester.ensureSemantics();
      await _mount(tester, brightness: brightness, [
        PopupMenuItemData(
            label: 'Rule',
            icon: Icons.alt_route,
            selected: false,
            onPressed: () {}),
        PopupMenuItemData(
            label: 'Global',
            icon: Icons.public,
            selected: true,
            onPressed: () {}),
      ]);
      await tester.tap(find.byTooltip('Menu'));
      await tester.pumpAndSettle();
      final colors =
          Theme.of(tester.element(find.byType(CommonPopupBox))).colorScheme;
      final rows = find.byType(MenuItemButton);
      final panel =
          find.ancestor(of: rows.first, matching: find.byType(Material)).first;
      final panelMaterial = tester.widget<Material>(panel);
      expect(panelMaterial.color, colors.surfaceContainerLow);
      expect((panelMaterial.shape! as RoundedRectangleBorder).borderRadius,
          BorderRadius.circular(16));
      final panelRect = tester.getRect(panel);
      final rowRect = tester.getRect(rows.first);
      expect(rowRect.left - panelRect.left, 4);
      expect(rowRect.top - panelRect.top, 2);
      expect(panelRect.bottom - tester.getRect(rows.last).bottom, 2);
      for (final row in tester.widgetList<MenuItemButton>(rows)) {
        final finder = find.byWidget(row);
        expect(tester.getSize(finder).height, 48);
        expect(row.style!.textStyle!.resolve({})!.fontSize, 16);
        expect(row.style!.textStyle!.resolve({})!.fontWeight, FontWeight.w400);
      }
      expect(tester.getSize(find.byIcon(Icons.public)), const Size(20, 20));
      expect(
          tester.getRect(find.byIcon(Icons.public)).left -
              tester.getRect(rows.last).left,
          12);
      expect(
          tester.getRect(find.text('Global')).left -
              tester.getRect(find.byIcon(Icons.public)).right,
          8);
      expect(find.byIcon(Icons.check_rounded), findsOneWidget);
      expect(
          tester.getSemantics(find.text('Global')).flagsCollection.isSelected,
          Tristate.isTrue);
      expect(_item(tester, 'Global').style!.backgroundColor!.resolve({}),
          colors.tertiaryContainer);
      expect(_item(tester, 'Global').style!.foregroundColor!.resolve({}),
          colors.onTertiaryContainer);
      expect(tester.takeException(), isNull);
      semantics.dispose();
    });
  }

  testWidgets('large text and long labels stay readable on a narrow screen',
      (tester) async {
    await _mount(tester, width: 320, scale: 2, [
      PopupMenuItemData(
          label: 'Длинное название доступного действия',
          icon: Icons.public,
          onPressed: () {}),
      PopupMenuItemData(label: 'Ещё одно действие', onPressed: () {}),
    ]);
    await tester.tap(find.byTooltip('Menu'));
    await tester.pumpAndSettle();
    for (final element in find.byType(MenuItemButton).evaluate()) {
      final rect = tester.getRect(find.byWidget(element.widget));
      expect(rect.left, greaterThanOrEqualTo(0));
      expect(rect.right, lessThanOrEqualTo(320));
      expect(rect.height, greaterThanOrEqualTo(48));
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('system Back dismisses only the menu', (tester) async {
    await _mount(
        tester, [PopupMenuItemData(label: 'Action', onPressed: () {})]);
    await tester.tap(find.byTooltip('Menu'));
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(MenuItemButton), findsNothing);
    expect(find.text('Home'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a fully disabled menu still closes with Escape', (tester) async {
    await _mount(
        tester, [const PopupMenuItemData(label: 'Disabled', onPressed: null)]);
    await tester.tap(find.byTooltip('Menu'));
    await tester.pumpAndSettle();
    expect(find.text('Disabled'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byType(MenuItemButton), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('open menu can be disposed without leaking focus or callbacks',
      (tester) async {
    await _mount(
        tester, [PopupMenuItemData(label: 'Action', onPressed: () {})]);
    await tester.tap(find.byTooltip('Menu'));
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
