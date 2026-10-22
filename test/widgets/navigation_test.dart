import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gektusclashx/common/fixed.dart';
import 'package:gektusclashx/common/navigator.dart';
import 'package:gektusclashx/models/models.dart';
import 'package:gektusclashx/state.dart';
import 'package:gektusclashx/widgets/pop_scope.dart';

void setViewSize(Size size) {
  globalState.appState = AppState(
    version: 1,
    viewSize: size,
    requests: FixedList(1),
    logs: FixedList(1),
    traffics: FixedList(1),
    totalTraffic: Traffic(),
  );
}

Future<Object?> backGesture(WidgetTester tester, String method,
    {double? progress, bool button = false}) async {
  const codec = StandardMethodCodec();
  final data =
      await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
    'flutter/backgesture',
    codec.encodeMethodCall(MethodCall(
        method,
        progress == null
            ? null
            : {
                'touchOffset':
                    button ? null : <double>[5 + progress * 300, 300],
                'progress': progress,
                'swipeEdge': 0,
              })),
    null,
  );
  return data == null ? null : codec.decodeEnvelope(data);
}

Widget navigationApp(
        GlobalKey<NavigatorState> navigator, TargetPlatform platform) =>
    MaterialApp(
      navigatorKey: navigator,
      theme: ThemeData(
          platform: platform, pageTransitionsTheme: appPageTransitionsTheme),
      home: const Scaffold(body: Text('Home')),
    );

Widget details({Key? key}) => Scaffold(
      key: key,
      appBar: AppBar(title: const Text('Details')),
      body: const TextField(),
    );

void main() {
  for (final wide in [false, true]) {
    testWidgets(
        'Android predictive back cancels without losing state and commits (wide: $wide)',
        (tester) async {
      setViewSize(Size(wide ? 1000 : 400, 900));
      final navigator = GlobalKey<NavigatorState>();
      final page = GlobalKey();
      await tester.pumpWidget(navigationApp(navigator, TargetPlatform.android));
      var completed = false;
      final result = BaseNavigator.push<void>(
          tester.element(find.text('Home')), details(key: page));
      unawaited(result.then((_) => completed = true));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Retain this text');
      final original = tester.getRect(find.byKey(page));
      expect(
          await backGesture(tester, 'startBackGesture', progress: 0), isTrue);
      await tester.pump();
      await backGesture(tester, 'updateBackGestureProgress', progress: 0.25);
      await tester.pumpAndSettle();
      expect(navigator.currentState!.userGestureInProgress, isTrue);
      expect(tester.getRect(find.byKey(page)).width, lessThan(original.width));
      await backGesture(tester, 'cancelBackGesture');
      await tester.pumpAndSettle();
      expect(find.text('Details'), findsOneWidget);
      expect(find.text('Retain this text'), findsOneWidget);
      expect(tester.getRect(find.byKey(page)), original);
      expect(completed, isFalse);
      expect(navigator.currentState!.userGestureInProgress, isFalse);

      expect(
          await backGesture(tester, 'startBackGesture', progress: 0), isTrue);
      await tester.pump();
      await backGesture(tester, 'updateBackGestureProgress', progress: 0.7);
      await tester.pump();
      await backGesture(tester, 'commitBackGesture');
      await tester.pumpAndSettle();
      await result;
      expect(completed, isTrue);
      expect(find.text('Details'), findsNothing);
      expect(find.text('Home'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));
  }

  testWidgets('A guarded editor blocks the gesture until it can pop safely',
      (tester) async {
    setViewSize(const Size(400, 900));
    final navigator = GlobalKey<NavigatorState>();
    var canPop = true;
    var confirmationAttempts = 0;
    late StateSetter update;
    await tester.pumpWidget(navigationApp(navigator, TargetPlatform.android));
    final result = BaseNavigator.push<void>(tester.element(find.text('Home')),
        StatefulBuilder(builder: (context, setState) {
      update = setState;
      return CommonPopScope(
        canPop: canPop,
        onPop: () {
          confirmationAttempts++;
          return false;
        },
        child: details(),
      );
    }));
    await tester.pumpAndSettle();
    expect(await backGesture(tester, 'startBackGesture', progress: 0), isTrue);
    await tester.pump();
    await backGesture(tester, 'cancelBackGesture');
    await tester.pumpAndSettle();
    update(() => canPop = false);
    await tester.pumpAndSettle();
    expect(await backGesture(tester, 'startBackGesture', progress: 0), isFalse);
    await backGesture(tester, 'commitBackGesture');
    await tester.pumpAndSettle();
    expect(confirmationAttempts, 1);
    expect(find.text('Details'), findsOneWidget);
    update(() => canPop = true);
    await tester.pumpAndSettle();
    expect(await backGesture(tester, 'startBackGesture', progress: 0), isTrue);
    await tester.pump();
    await backGesture(tester, 'updateBackGestureProgress', progress: 0.7);
    await tester.pump();
    await backGesture(tester, 'commitBackGesture');
    await tester.pumpAndSettle();
    await result;
    expect(find.text('Home'), findsOneWidget);
    expect(confirmationAttempts, 1);
    expect(tester.takeException(), isNull);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets(
      'Hardware Back still returns without starting a predictive gesture',
      (tester) async {
    setViewSize(const Size(1000, 900));
    final navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(navigationApp(navigator, TargetPlatform.android));
    final result =
        BaseNavigator.push<void>(tester.element(find.text('Home')), details());
    await tester.pumpAndSettle();
    expect(
        await backGesture(tester, 'startBackGesture',
            progress: 0, button: true),
        isFalse);
    expect(navigator.currentState!.userGestureInProgress, isFalse);
    await backGesture(tester, 'commitBackGesture');
    await tester.pumpAndSettle();
    await result;
    expect(find.text('Home'), findsOneWidget);
    expect(tester.takeException(), isNull);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  for (final platform in [
    TargetPlatform.linux,
    TargetPlatform.windows,
    TargetPlatform.macOS
  ]) {
    testWidgets('App-bar Back still pops the desktop route on $platform',
        (tester) async {
      setViewSize(const Size(1000, 900));
      final navigator = GlobalKey<NavigatorState>();
      await tester.pumpWidget(navigationApp(navigator, platform));
      final result = BaseNavigator.push<void>(
          tester.element(find.text('Home')), details());
      await tester.pumpAndSettle();
      expect(find.byType(BackButton), findsOneWidget);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      await result;
      expect(find.text('Home'), findsOneWidget);
      expect(navigator.currentState!.canPop(), isFalse);
      expect(tester.takeException(), isNull);
    }, variant: TargetPlatformVariant.only(platform));
  }
}
