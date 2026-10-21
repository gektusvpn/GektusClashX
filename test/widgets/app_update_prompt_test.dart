import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gektusclashx/common/app_update.dart';
import 'package:gektusclashx/common/app_update_reminder.dart';
import 'package:gektusclashx/l10n/l10n.dart';
import 'package:gektusclashx/widgets/app_update_prompt.dart';
import 'package:shared_preferences/shared_preferences.dart';

AppUpdateState available() =>
    AppUpdateState.available(const {'tag_name': 'v0.6.0'});

Future<void> openHost(
  WidgetTester tester,
  ValueNotifier<AppUpdateState?> updates, {
  bool tv = false,
  Future<void> Function()? onUpdate,
  Widget child = const Scaffold(body: Text('Home')),
}) async {
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  await tester.pumpWidget(MaterialApp(
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
    ],
    home: AppUpdatePromptHost(
      updates: updates,
      reminder: AppUpdateReminder(),
      isAndroid: true,
      isTV: tv,
      onUpdate: onUpdate ?? () async {},
      child: child,
    ),
  ));
  await tester.pumpAndSettle();
}

Future<void> waitForPrompt(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 5));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('TV dismissal restores focus and does not repeat this session',
      (tester) async {
    final updates = ValueNotifier<AppUpdateState?>(available());
    final launcher = FocusNode();
    await openHost(tester, updates,
        tv: true,
        child: Scaffold(
            body: TextButton(
          autofocus: true,
          focusNode: launcher,
          onPressed: () {},
          child: const Text('Home'),
        )));
    expect(find.byType(AppUpdatePrompt), findsNothing);
    await waitForPrompt(tester);
    expect(find.byType(Dialog), findsOneWidget);
    expect(find.text('v0.6.0'), findsOneWidget);
    expect(Focus.of(tester.element(find.text('Later'))).hasFocus, isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pumpAndSettle();
    expect(find.byType(AppUpdatePrompt), findsNothing);
    expect(launcher.hasPrimaryFocus, isTrue);
    updates.value = available();
    await waitForPrompt(tester);
    expect(find.byType(AppUpdatePrompt), findsNothing);
    await tester.pumpWidget(const SizedBox());
    launcher.dispose();
    updates.dispose();
  });

  testWidgets(
      'Update closes the prompt and starts the existing update flow once',
      (tester) async {
    final updates = ValueNotifier<AppUpdateState?>(available());
    var starts = 0;
    await openHost(tester, updates, tv: true, onUpdate: () async {
      starts++;
      updates.value = AppUpdateState(
          release: updates.value!.release, phase: AppUpdatePhase.downloading);
    });
    await waitForPrompt(tester);
    // A repeated check of the same release must not invalidate the action.
    updates.value = available();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    expect(Focus.of(tester.element(find.text('Update'))).hasFocus, isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pumpAndSettle();
    expect(starts, 1);
    expect(find.byType(AppUpdatePrompt), findsNothing);
    expect(updates.value!.phase, AppUpdatePhase.downloading);
    await waitForPrompt(tester);
    expect(starts, 1);
    await tester.pumpWidget(const SizedBox());
    updates.dispose();
  });

  testWidgets('phone uses a dismissible sheet that fits large text',
      (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.5;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final updates = ValueNotifier<AppUpdateState?>(available());
    await openHost(tester, updates);
    await waitForPrompt(tester);
    expect(find.byType(BottomSheet), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(AppUpdatePrompt), findsNothing);
    await tester.pumpWidget(const SizedBox());
    updates.dispose();
  });

  testWidgets('waits until another modal has closed', (tester) async {
    final updates = ValueNotifier<AppUpdateState?>(available());
    await openHost(tester, updates,
        child: Scaffold(
            body: Builder(
          builder: (context) => TextButton(
            onPressed: () => showDialog<void>(
              context: context,
              builder: (context) => AlertDialog(actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Dismiss other')),
              ]),
            ),
            child: const Text('Other dialog'),
          ),
        )));
    await tester.tap(find.text('Other dialog'));
    await tester.pumpAndSettle();
    await waitForPrompt(tester);
    expect(find.byType(AppUpdatePrompt), findsNothing);
    await tester.tap(find.text('Dismiss other'));
    await tester.pumpAndSettle();
    await waitForPrompt(tester);
    expect(find.byType(AppUpdatePrompt), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    updates.dispose();
  });

  testWidgets('waits for foreground and cancels if a download starts',
      (tester) async {
    final updates = ValueNotifier<AppUpdateState?>(available());
    await openHost(tester, updates);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump(const Duration(seconds: 5));
    expect(find.byType(AppUpdatePrompt), findsNothing);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    updates.value = AppUpdateState(
        release: updates.value!.release, phase: AppUpdatePhase.downloading);
    await waitForPrompt(tester);
    expect(find.byType(AppUpdatePrompt), findsNothing);
    await tester.pumpWidget(const SizedBox());
    updates.dispose();
  });
}
