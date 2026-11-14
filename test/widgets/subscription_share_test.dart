import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/news_test_app.dart';

void main() {
  setUp(initializeNewsTestState);

  testWidgets('desktop share copies subscription URL and shows a Snackbar',
      (tester) async {
    String? copied;
    tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        copied = (call.arguments as Map)['text'] as String;
      }
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null));
    await tester.pumpWidget(newsTestApp(
        withNews: false,
        subscriptionUrl: ' https://example.com/subscription '));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byTooltip('Поделиться'));
    await tester.tap(find.byTooltip('Поделиться'));
    await tester.pumpAndSettle();
    expect(copied, 'https://example.com/subscription');
    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.text('Ссылка подписки скопирована в буфер обмена'),
        findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('share is disabled without a subscription URL', (tester) async {
    await tester.pumpWidget(newsTestApp(withNews: false));
    await tester.pumpAndSettle();
    final button = find.descendant(
        of: find.byTooltip('Поделиться'),
        matching: find.byType(OutlinedButton));
    expect(tester.widget<OutlinedButton>(button).onPressed, isNull);
    expect(find.byType(SnackBar), findsNothing);
  });
}
