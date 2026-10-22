import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gektusclashx/services/news/repository.dart';
import 'package:gektusclashx/state.dart';
import 'package:gektusclashx/views/news/news.dart';
import 'package:gektusclashx/views/proxies/setting.dart';
import 'package:gektusclashx/widgets/sheet.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:integration_test/integration_test.dart';
import 'package:window_manager/window_manager.dart';

import '../test/support/news_test_app.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('Linux Home news, article sheet and news list', (tester) async {
    final boundary = GlobalKey();
    const liveUrl = String.fromEnvironment('NEWS_FEED_URL');
    final cache = await Directory.systemTemp.createTemp('gektus-news-preview-');
    addTearDown(() => cache.delete(recursive: true));
    initializeNewsTestState();
    await windowManager.ensureInitialized();
    await windowManager.setSize(const Size(1000, 900));
    await windowManager.show();
    await tester.pumpWidget(RepaintBoundary(
        key: boundary,
        child: newsTestApp(
            newsUrl: liveUrl.isEmpty ? 'https://news.example/feed' : liveUrl,
            repository: liveUrl.isEmpty
                ? null
                : NewsFeedRepository(cacheDirectory: () async => cache))));
    await tester.pumpAndSettle();
    Future<void> waitForImage(Finder scope) async {
      final rawImages =
          find.descendant(of: scope, matching: find.byType(RawImage));
      bool loaded() => rawImages
          .evaluate()
          .any((element) => (element.widget as RawImage).image != null);
      for (var i = 0; i < 300 && !loaded(); i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(loaded(), isTrue, reason: 'The real article image must load');
    }

    if (liveUrl.isNotEmpty) {
      for (var i = 0; i < 300 && find.text('Читать').evaluate().isEmpty; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.text('Читать'), findsOneWidget);
      expect(find.byType(NewsCover), findsOneWidget);
      await waitForImage(find.byType(NewsCover));
    }
    Future<void> screenshot(String name) async {
      const output = String.fromEnvironment('NEWS_SCREENSHOTS');
      if (output.isEmpty) return;
      final image = await (boundary.currentContext!.findRenderObject()!
              as RenderRepaintBoundary)
          .toImage(pixelRatio: 1);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await File('$output/$name.png').writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    }

    await tester.ensureVisible(find.byType(NewsCard));
    await tester.pumpAndSettle();
    await screenshot('news-home-linux');
    final mouse = await tester.createGesture(kind: ui.PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    final card = tester.getRect(find.byType(NewsCard));
    await mouse.moveTo(card.bottomLeft + const Offset(24, -8));
    await tester.pumpAndSettle();
    await screenshot('news-hover-linux');
    await mouse.removePointer();
    await tester.tap(find.text('Читать'));
    await tester.pumpAndSettle();
    expect(find.byType(NewsArticleView), findsOneWidget);
    if (liveUrl.isNotEmpty) {
      await waitForImage(find.byType(NewsArticleView));
    }
    if (liveUrl.isEmpty) {
      expect(find.text('Что изменилось', findRichText: true), findsOneWidget);
    }
    await screenshot('news-article-linux');
    await tester.scrollUntilVisible(find.text('Открыть оригинал'), 300,
        scrollable: find.descendant(
            of: find.byType(NewsArticleView),
            matching: find.byType(Scrollable)));
    await tester.pumpAndSettle();
    await screenshot('news-article-footer-linux');
    expect(find.byType(CloseButton), findsOneWidget);
    await tester.tap(find.byType(CloseButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Все новости'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await screenshot('navigation-forward-linux');
    await tester.pumpAndSettle();
    if (liveUrl.isEmpty) {
      expect(find.text('Приложение для телевизора', findRichText: true),
          findsOneWidget);
    }
    expect(find.byType(NewsPage), findsOneWidget);
    expect(find.byType(BottomSheet), findsNothing);
    await screenshot('news-list-linux');
    await windowManager.setSize(const Size(460, 900));
    await tester.pumpAndSettle();
    await screenshot('news-list-compact-linux');
    await windowManager.setSize(const Size(1000, 900));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Читать').first);
    await tester.tap(find.text('Читать').first);
    await tester.pumpAndSettle();
    expect(find.byType(NewsArticleView), findsOneWidget);
    await tester.tap(find.byType(CloseButton));
    await tester.pumpAndSettle();
    expect(find.byType(NewsArticleView), findsNothing);
    await tester.tap(find.byType(BackButtonIcon));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await screenshot('navigation-back-linux');
    await tester.pumpAndSettle();
    expect(find.byType(NewsPage), findsNothing);
    await windowManager.setSize(const Size(460, 900));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byType(NewsCard));
    await tester.pumpAndSettle();
    if (liveUrl.isNotEmpty) {
      await waitForImage(find.byType(NewsCover));
    }
    await screenshot('news-compact-linux');
    if (liveUrl.isNotEmpty) {
      // Recreate the app/repository with an expired disk cache and a stalled
      // server. A saved post must appear without waiting for that response.
      await tester.pumpWidget(const SizedBox());
      final pending = Completer<http.Response>();
      await tester.pumpWidget(RepaintBoundary(
          key: boundary,
          child: newsTestApp(
              newsUrl: liveUrl,
              repository: NewsFeedRepository(
                  cacheDirectory: () async => cache,
                  now: () => DateTime.now().add(const Duration(hours: 1)),
                  client: () => MockClient((_) => pending.future)))));
      await tester.pumpAndSettle();
      for (var i = 0; i < 100 && find.text('Читать').evaluate().isEmpty; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(find.text('Читать'), findsOneWidget);
      expect(find.byType(NewsCardSkeleton), findsNothing);
      expect(pending.isCompleted, isFalse);
      await tester.ensureVisible(find.byType(NewsCard));
      await tester.pumpAndSettle();
      await waitForImage(find.byType(NewsCover));
      await screenshot('news-cached-linux');
      pending.complete(http.Response('Offline', 503));
      await tester.pumpAndSettle();
    }
    // Exercise the real locations settings through both adaptive presentations.
    for (final wide in [false, true]) {
      final size = wide ? const Size(1000, 900) : const Size(460, 900);
      await windowManager.setSize(size);
      globalState.appState = globalState.appState.copyWith(viewSize: size);
      await tester.pumpAndSettle();
      unawaited(showSheet<void>(
        context: tester.element(find.byType(NewsCard)),
        props: const SheetProps(maxWidth: 540, isScrollControlled: true),
        builder: (_, type) => AdaptiveSheetScaffold(
            type: type, title: 'Настройки', body: const ProxiesSetting()),
      ));
      await tester.pumpAndSettle();
      expect(find.byType(ProxiesSetting), findsOneWidget);
      await screenshot(wide
          ? 'locations-settings-side-linux'
          : 'locations-settings-bottom-linux');
      Navigator.of(tester.element(find.byType(AdaptiveSheetScaffold))).pop();
      await tester.pumpAndSettle();
    }
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
