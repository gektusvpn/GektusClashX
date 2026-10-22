import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gektusclashx/l10n/l10n.dart';
import 'package:gektusclashx/models/models.dart';
import 'package:gektusclashx/widgets/progress_theme.dart';
import 'package:gektusclashx/widgets/subscription_info_view.dart';

void main() {
  testWidgets('over-quota traffic has bounded, numeric accessible progress',
      (tester) async {
    await AppLocalizations.load(const Locale('en'));
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData(
          useMaterial3: true, progressIndicatorTheme: materialProgressTheme),
      home: const Scaffold(
          body: SubscriptionInfoView(
              subscriptionInfo: SubscriptionInfo(download: 200, total: 100))),
    ));
    await tester.pumpAndSettle();
    final indicator = find.byType(LinearProgressIndicator);
    expect(tester.widget<LinearProgressIndicator>(indicator).value, 1);
    final node = tester.getSemantics(indicator);
    expect(node.label, contains('Traffic'));
    expect(node.value, '100');
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });
}
