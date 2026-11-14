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

  for (final tv in [false, true]) {
    testWidgets('dashboard card content has consistent padding (TV: $tv)',
        (tester) async {
      tester.view.physicalSize = const Size(1200, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(newsTestApp(tv: tv, extraHeaders: {
        'gektusclashx-channel-url': 'https://example.com/channel',
      }));
      await tester.pumpAndSettle();
      final inset = tv ? 20.0 : 16.0;
      for (final title in ['Подписка', 'Ссылки']) {
        final container = tester.widget<Container>(find
            .ancestor(
                of: find.text(title),
                matching: find.byWidgetPredicate((widget) =>
                    widget is Container && widget.decoration is BoxDecoration))
            .first);
        expect(container.padding, EdgeInsets.all(inset));
      }
      final newsTitle = find.byWidgetPredicate((widget) =>
          widget is EmojiText &&
          widget.text == 'Обновление сервиса: больше удобства каждый день');
      final titlePadding = tester.widgetList<Padding>(
          find.ancestor(of: newsTitle, matching: find.byType(Padding)));
      expect(
          titlePadding.any((padding) =>
              padding.padding == EdgeInsets.fromLTRB(inset, inset, inset, 0)),
          isTrue);
      final actionsPadding = tester.widgetList<Padding>(find.ancestor(
          of: find.text('Все новости'), matching: find.byType(Padding)));
      expect(
          actionsPadding
              .any((padding) => padding.padding == EdgeInsets.all(inset)),
          isTrue);
      expect(tester.takeException(), isNull);
    });
  }

  for (final brightness in Brightness.values) {
    testWidgets(
        'cards and action buttons use expressive outlines ($brightness)',
        (tester) async {
      tester.view.physicalSize = const Size(1000, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(newsTestApp(
          brightness: brightness,
          subscriptionUrl: 'https://example.com/subscription',
          extraHeaders: {
            'gektusclashx-channel-url': 'https://example.com/channel'
          }));
      await tester.pumpAndSettle();
      final colors =
          Theme.of(tester.element(find.byType(NewsCard))).colorScheme;
      final card = tester.widget<Card>(find
          .descendant(of: find.byType(NewsCard), matching: find.byType(Card))
          .first);
      expect((card.shape! as OutlinedBorder).side,
          BorderSide(color: colors.outlineVariant));
      expect(card.color, colors.surfaceContainer);
      for (final label in ['Поделиться', 'Обновить', 'Все новости']) {
        final button = label == 'Поделиться'
            ? find.descendant(
                of: find.byTooltip(label),
                matching: find.byType(OutlinedButton))
            : find.ancestor(
                of: find.text(label), matching: find.byType(OutlinedButton));
        final material = tester.widget<Material>(
            find.descendant(of: button, matching: find.byType(Material)));
        expect((material.shape! as OutlinedBorder).side,
            BorderSide(color: colors.outlineVariant));
        expect(material.textStyle!.color, colors.onSurfaceVariant);
      }
      final links = tester.widget<Container>(find
          .ancestor(
              of: find.text('Ссылки'),
              matching: find.byWidgetPredicate((widget) =>
                  widget is Container && widget.decoration is BoxDecoration))
          .first);
      expect((links.decoration! as BoxDecoration).borderRadius,
          BorderRadius.circular(16));
      await tester.ensureVisible(find.text('Все новости'));
      await tester.tap(find.text('Все новости'));
      await tester.pumpAndSettle();
      final articleCards = tester
          .widgetList<Card>(find.descendant(
              of: find.byType(NewsPage), matching: find.byType(Card)))
          .where((card) => card.color == colors.surfaceContainer);
      expect(articleCards, isNotEmpty);
      for (final articleCard in articleCards) {
        expect((articleCard.shape! as OutlinedBorder).side,
            BorderSide(color: colors.outlineVariant));
      }
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('news outlined action preserves the TV focus border',
      (tester) async {
    final colors = ColorScheme.fromSeed(seedColor: Colors.green);
    await tester.pumpWidget(newsTestApp(
        child: Theme(
      data: ThemeData(
          colorScheme: colors,
          outlinedButtonTheme: OutlinedButtonThemeData(
            style: ButtonStyle(
                side: WidgetStateProperty.resolveWith((states) =>
                    states.contains(WidgetState.focused)
                        ? BorderSide(color: colors.primary, width: 2)
                        : null)),
          )),
      child: const SingleChildScrollView(
          child: NewsCard(url: 'https://news.example/feed')),
    )));
    await tester.pumpAndSettle();
    Focus.of(tester.element(find.text('Все новости'))).requestFocus();
    await tester.pumpAndSettle();
    final button = find.ancestor(
        of: find.text('Все новости'), matching: find.byType(OutlinedButton));
    final material = tester.widget<Material>(
        find.descendant(of: button, matching: find.byType(Material)));
    expect((material.shape! as OutlinedBorder).side,
        BorderSide(color: colors.primary, width: 2));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'Home shows news after subscription only with header and removes support card',
      (tester) async {
    tester.view.physicalSize = const Size(900, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(newsTestApp());
    await tester.pumpAndSettle();
    expect(find.byType(NewsCard), findsOneWidget);
    final newsStyle = tester
        .widget<EmojiText>(find.byWidgetPredicate((widget) =>
            widget is EmojiText &&
            widget.text == 'Обновление сервиса: больше удобства каждый день'))
        .style!;
    final theme = Theme.of(tester.element(find.byType(NewsCard)));
    expect(newsStyle.fontSize, theme.textTheme.bodyLarge!.fontSize);
    expect(newsStyle.fontWeight, FontWeight.w500);
    expect(newsStyle.fontFamily, theme.textTheme.bodyLarge!.fontFamily);
    final card = tester.widget<Card>(find
        .descendant(of: find.byType(NewsCard), matching: find.byType(Card))
        .first);
    expect((card.shape! as RoundedRectangleBorder).borderRadius,
        BorderRadius.circular(16));
    expect(tester.getTopLeft(find.text('Подписка')).dy,
        lessThan(tester.getTopLeft(find.byType(NewsCard)).dy));
    expect(find.text('Поддержка'), findsNothing);
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
    final heading = tester.widget<EmojiText>(find.descendant(
        of: find.byType(NewsArticleView),
        matching: find.byWidgetPredicate(
            (widget) => widget is EmojiText && widget.text == article.title)));
    expect(
        heading.style!.fontSize,
        Theme.of(tester.element(find.byType(NewsArticleView)))
            .textTheme
            .bodyLarge!
            .fontSize);
    expect(heading.maxLines, isNull);
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
