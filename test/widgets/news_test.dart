import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';
import 'package:gektusclashx/services/news/feed.dart';
import 'package:gektusclashx/services/news/repository.dart';
import 'package:gektusclashx/views/news/news.dart';
import 'package:gektusclashx/widgets/text.dart';

import '../fixtures/news_feed.dart';
import '../support/news_test_app.dart';

void main() {
  setUp(initializeNewsTestState);

  testWidgets(
      'Home inserts news between subscription and support only with header',
      (tester) async {
    tester.view.physicalSize = const Size(900, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(newsTestApp());
    await tester.pumpAndSettle();
    expect(find.byType(NewsCard), findsOneWidget);
    final subscriptionStyle = tester.widget<Text>(find.text('Подписка')).style!;
    final newsStyle = tester
        .widget<EmojiText>(find.byWidgetPredicate((widget) =>
            widget is EmojiText &&
            widget.text == 'Обновление сервиса: больше удобства каждый день'))
        .style!;
    expect(newsStyle.fontSize, subscriptionStyle.fontSize);
    expect(newsStyle.fontWeight, subscriptionStyle.fontWeight);
    expect(newsStyle.fontFamily, subscriptionStyle.fontFamily);
    expect(tester.getTopLeft(find.text('Подписка')).dy,
        lessThan(tester.getTopLeft(find.byType(NewsCard)).dy));
    expect(tester.getTopLeft(find.byType(NewsCard)).dy,
        lessThan(tester.getTopLeft(find.text('Поддержка')).dy));
    expect(find.text('Приложение для телевизора', findRichText: true),
        findsNothing);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(newsTestApp(withNews: false));
    await tester.pumpAndSettle();
    expect(find.byType(NewsCard), findsNothing);
  });

  testWidgets(
      'latest opens the article; all news is a separate page with working back navigation',
      (tester) async {
    await tester.pumpWidget(newsTestApp());
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Читать'));
    await tester.tap(find.text('Читать'));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsOneWidget);
    expect(find.byType(NewsArticleView), findsOneWidget);
    final article =
        tester.widget<NewsArticleView>(find.byType(NewsArticleView)).article;
    expect(
        find.descendant(
            of: find.byType(NewsArticleView),
            matching: find.text(article.title, findRichText: true)),
        findsOneWidget);
    expect(find.text('Новости'), findsNothing);
    final html = tester.widget<HtmlWidget>(find.byType(HtmlWidget));
    final bodyStyle =
        Theme.of(tester.element(find.byType(HtmlWidget))).textTheme.bodyLarge!;
    expect(html.textStyle?.fontFamily, bodyStyle.fontFamily);
    expect(html.textStyle?.fontSize, bodyStyle.fontSize);
    expect(find.text('Что изменилось', findRichText: true), findsOneWidget);
    expect(tester.takeException(), isNull);
    expect(find.byType(CloseButton), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Все новости'));
    await tester.tap(find.text('Все новости'));
    await tester.pumpAndSettle();
    expect(find.text('Приложение для телевизора', findRichText: true),
        findsOneWidget);
    expect(find.byType(NewsPage), findsOneWidget);
    expect(find.byType(BottomSheet), findsNothing);
    expect(find.text('Новости сервиса', findRichText: true), findsOneWidget);
    expect(find.text('Подписаться'), findsOneWidget);
    expect(find.text('@example'), findsOneWidget);
    expect(find.byType(BackButton), findsOneWidget);
    await tester.ensureVisible(find.text('Читать').first);
    await tester.tap(find.text('Читать').first);
    await tester.pumpAndSettle();
    expect(
        tester.widget<NewsArticleView>(find.byType(NewsArticleView)).article.id,
        'post-2');
    await tester.tap(find.byType(CloseButton));
    await tester.pumpAndSettle();
    expect(find.byType(NewsArticleView), findsNothing);
    expect(find.byType(NewsPage), findsOneWidget);
    await tester.tap(find.byType(BackButtonIcon));
    await tester.pumpAndSettle();
    expect(find.byType(NewsPage), findsNothing);
    expect(find.byType(NewsCard), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('compact light news card supports large text and keyboard focus',
      (tester) async {
    tester.view.physicalSize = const Size(360, 700);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.6;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(newsTestApp(
        brightness: Brightness.light,
        child: const SingleChildScrollView(
            child: Padding(
                padding: EdgeInsets.all(16),
                child: NewsCard(url: 'https://news.example/feed')))));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final title = tester.widget<EmojiText>(find.byWidgetPredicate((widget) =>
        widget is EmojiText &&
        widget.text == 'Обновление сервиса: больше удобства каждый день'));
    expect(title.maxLines, 2);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();
    expect(Focus.of(tester.element(find.text('Читать'))).hasFocus, isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.byType(NewsArticleView), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'article footer keeps date left and original right, and fits large text',
      (tester) async {
    final article =
        NewsFeed.parse(sampleNewsFeed, Uri.parse('https://news.example/feed'))
            .articles
            .first;
    await tester
        .pumpWidget(newsTestApp(child: NewsArticleView(article: article)));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Открыть оригинал'));
    await tester.pumpAndSettle();
    final date = find.text('22 окт. 2026 г.');
    expect(date, findsOneWidget);
    expect(tester.getTopLeft(date).dx,
        lessThan(tester.getTopLeft(find.text('Открыть оригинал')).dx));
    expect(tester.getTopLeft(date).dy,
        greaterThan(tester.getTopLeft(find.byType(HtmlWidget)).dy));
    expect(find.byType(CloseButton), findsOneWidget);
    tester.view.physicalSize = const Size(360, 700);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.6;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Открыть оригинал'), 200,
        scrollable: find.descendant(
            of: find.byType(NewsArticleView),
            matching: find.byType(Scrollable)));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(
        newsTestApp(child: const NewsPage(url: 'https://news.example/feed')));
    await tester.pumpAndSettle();
    expect(find.text('Подписаться'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('news uses bundled emoji in headings, HTML emphasis and links',
      (tester) async {
    await tester.pumpWidget(newsTestApp(
        child: const NewsArticleView(
            article: NewsArticle(
      id: 'emoji',
      title: 'Заголовок ⚡️',
      summary: 'Body',
      body:
          '<p><b>⚡️ Жирный текст</b> и <a href="https://example.com">✨ Ссылка</a></p>',
    ))));
    await tester.pumpAndSettle();
    final emojiSpans = <TextSpan>[];
    void visit(InlineSpan span) {
      if (span is! TextSpan) return;
      if (span.text == '⚡️' || span.text == '✨') emojiSpans.add(span);
      span.children?.forEach(visit);
    }

    for (final rich in tester.widgetList<RichText>(find.byType(RichText))) {
      visit(rich.text);
    }
    expect(emojiSpans, hasLength(3));
    expect(emojiSpans.every((span) => span.style?.fontFamily == 'Twemoji'),
        isTrue);
    expect(emojiSpans.singleWhere((span) => span.text == '✨').recognizer,
        isNotNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('first load uses a skeleton and replaces it with the post',
      (tester) async {
    final pending = _PendingNewsRepository();
    await tester.pumpWidget(newsTestApp(
        repository: pending,
        child: const SingleChildScrollView(
            child: NewsCard(url: 'https://news.example/feed'))));
    await tester.pumpAndSettle();
    expect(find.byType(NewsCardSkeleton), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsNothing);
    pending.result.complete(NewsFeedResult(NewsFeed.parse(
        sampleNewsFeed, Uri.parse('https://news.example/feed'))));
    await tester.pumpAndSettle();
    expect(find.byType(NewsCardSkeleton), findsNothing);
    expect(find.text('Читать'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _PendingNewsRepository extends NewsFeedRepository {
  final result = Completer<NewsFeedResult>();
  @override
  Stream<NewsFeedResult> watch(String url, {bool refresh = false}) =>
      Stream.fromFuture(result.future);
}
