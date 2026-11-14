import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gektusclashx/common/startup_diagnostics.dart';
import 'package:gektusclashx/widgets/windows_startup_gate.dart';

void main() {
  setUp(() {
    windowsStartupReady.value = false;
    windowsStartupError.value = null;
  });
  testWidgets(
      'UI renders during initialization but controls wait for readiness',
      (tester) async {
    var taps = 0;
    await tester.pumpWidget(MaterialApp(
        home: WindowsStartupGate(
            child: Scaffold(
      body: Center(
          child: TextButton(
              onPressed: () {
                taps++;
              },
              child: const Text('Connect'))),
    ))));
    expect(find.text('Starting GektusClashX…'), findsOneWidget);
    expect(find.text('Connect'), findsOneWidget);
    await tester.tap(find.text('Connect'), warnIfMissed: false);
    expect(taps, 0);
    windowsStartupReady.value = true;
    await tester.pump();
    await tester.tap(find.text('Connect'));
    expect(taps, 1);
    expect(find.text('Starting GektusClashX…'), findsNothing);
  });
  testWidgets('startup failure replaces progress with a visible error and exit',
      (tester) async {
    await tester.pumpWidget(
        const MaterialApp(home: WindowsStartupGate(child: Scaffold())));
    windowsStartupError.value = 'Startup failed';
    await tester.pump();
    expect(find.text('Startup failed'), findsOneWidget);
    expect(find.text('Exit'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });
}
