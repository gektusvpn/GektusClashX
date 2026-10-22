import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gektusclashx/common/navigator.dart';
import 'package:gektusclashx/l10n/l10n.dart';
import 'package:gektusclashx/providers/app.dart';
import 'package:gektusclashx/services/news/feed.dart';
import 'package:gektusclashx/services/news/repository.dart';
import 'package:gektusclashx/state.dart';
import 'package:gektusclashx/widgets/effect.dart';
import 'package:gektusclashx/widgets/icon.dart';
import 'package:gektusclashx/widgets/scaffold.dart';
import 'package:gektusclashx/widgets/text.dart';

import 'article.dart';
import 'common.dart';

export 'article.dart';

/// The latest post pairs its cover with text and explicit actions.
class NewsCard extends ConsumerWidget {
  const NewsCard({super.key, required this.url, this.tag});
  final String url;
  final String? tag;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final feed = ref.watch(newsFeedProvider(url));
    final tv = ref.watch(isAndroidTVProvider).valueOrNull ?? false;
    return Card.filled(
      margin: EdgeInsets.zero,
      color: theme.colorScheme.surfaceContainer,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(24))),
      clipBehavior: Clip.antiAlias,
      semanticContainer: false,
      child: feed.when(
        skipLoadingOnReload: true,
        data: (result) {
          final articles = result.feed.forTag(tag).articles;
          if (articles.isEmpty) {
            return Padding(
                padding: const EdgeInsets.all(24),
                child: Text(strings.newsEmpty));
          }
          final article = articles.first;
          void openArticle() => unawaited(showNewsArticle(context, article));
          return InkWell(
            canRequestFocus: false,
            onTap: openArticle,
            child: _ArticleCardBody(
              article: article,
              footer: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                        padding: const EdgeInsets.all(16),
                        child: Wrap(
                            alignment: WrapAlignment.end,
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              OutlinedButton(
                                  onPressed: () => unawaited(
                                      showNewsFeed(context, url, tag: tag)),
                                  child: Text(strings.allNews)),
                              TVFocusEffect(
                                  enabled: tv,
                                  borderRadius: BorderRadius.circular(28),
                                  scrollAlignment: 0.5,
                                  child: FilledButton(
                                      onPressed: openArticle,
                                      child: Text(strings.readNews))),
                            ])),
                    if (result.isStale)
                      Padding(
                          padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
                          child: Text(strings.newsCached,
                              style: theme.textTheme.bodySmall)),
                  ]),
            ),
          );
        },
        loading: () => const NewsCardSkeleton(),
        error: (_, __) => Padding(
            padding: const EdgeInsets.all(24),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(strings.news, style: theme.textTheme.titleLarge),
              const SizedBox(height: 12),
              Text(strings.newsLoadFailed, style: theme.textTheme.bodyMedium),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                  onPressed: () => refreshNews(ref, url),
                  icon: const Icon(Icons.refresh_rounded),
                  label: Text(strings.retry)),
            ])),
      ),
    );
  }
}

/// A quiet placeholder only for an empty cache. Existing posts stay visible
/// while their feed refreshes; no looping animation is needed for reduced motion.
class NewsCardSkeleton extends StatelessWidget {
  const NewsCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    Widget bar(double width, double height) => FractionallySizedBox(
        alignment: AlignmentDirectional.centerStart,
        widthFactor: width,
        child: Container(
            height: height,
            decoration: BoxDecoration(
                color: colors.onSurface.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12))));
    final text = Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            bar(0.72, 24),
            const SizedBox(height: 20),
            bar(1, 14),
            const SizedBox(height: 10),
            bar(0.85, 14),
            const SizedBox(height: 28),
            Align(
                alignment: AlignmentDirectional.centerEnd,
                child: SizedBox(width: 200, child: bar(1, 40))),
          ],
        ));
    final media = DecoratedBox(
        decoration: BoxDecoration(
            color: colors.onSurface.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(12)));
    return Semantics(
        label: AppLocalizations.of(context).newsLoading,
        child: ExcludeSemantics(
            child: LayoutBuilder(builder: (context, constraints) {
          final textScale = MediaQuery.textScalerOf(context).scale(16) / 16;
          if (constraints.maxWidth / textScale < 600) {
            return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                      height:
                          (constraints.maxWidth * 9 / 16).clamp(120.0, 320.0),
                      child: media),
                  text,
                ]);
          }
          return Row(children: [
            SizedBox(
                width: (constraints.maxWidth * 0.36).clamp(220.0, 340.0),
                height: 240,
                child: media),
            Expanded(child: text),
          ]);
        })));
  }
}

class _ArticleCardBody extends StatelessWidget {
  const _ArticleCardBody({required this.article, this.footer});
  final NewsArticle article;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, footer == null ? 16 : 0),
            child: _ArticlePreview(article: article)),
        if (footer != null) footer!,
      ],
    );
    if (article.image == null) return content;
    return LayoutBuilder(builder: (context, constraints) {
      final textScale = MediaQuery.textScalerOf(context).scale(16) / 16;
      if (constraints.maxWidth / textScale < 600) {
        return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              NewsCover(url: article.image!),
              content,
            ]);
      }
      final imageWidth = (constraints.maxWidth * 0.36).clamp(220.0, 340.0);
      return Stack(children: [
        ConstrainedBox(
            constraints: BoxConstraints(minHeight: footer == null ? 200 : 240),
            child: Padding(
                padding: EdgeInsetsDirectional.only(start: imageWidth),
                child: content)),
        PositionedDirectional(
            start: 0,
            top: 0,
            bottom: 0,
            width: imageWidth,
            child: NewsCover(
                url: article.image!, borderRadius: BorderRadius.circular(12))),
      ]);
    });
  }
}

/// A bounded cover keeps the dashboard usable on desktop and TV. The full image
/// is also available in the article, without cropping.
class NewsCover extends StatelessWidget {
  const NewsCover(
      {super.key,
      required this.url,
      this.borderRadius =
          const BorderRadius.vertical(bottom: Radius.circular(12))});
  final Uri url;
  final BorderRadius borderRadius;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return LayoutBuilder(builder: (context, constraints) {
      final height = (constraints.maxWidth * 9 / 16).clamp(120.0, 320.0);
      return ClipRRect(
          borderRadius: borderRadius,
          child: SizedBox(
              height: height,
              width: double.infinity,
              child: ColoredBox(
                  color: colors.surfaceContainerLowest,
                  child: CachedNetworkImage(
                    imageUrl: url.toString(),
                    fit: BoxFit.cover,
                    memCacheWidth: (constraints.maxWidth *
                            MediaQuery.devicePixelRatioOf(context))
                        .ceil(),
                    placeholder: (_, __) => const SizedBox.expand(),
                    errorWidget: (_, __, ___) => Center(
                        child: Icon(Icons.image_not_supported_outlined,
                            color: colors.onSurfaceVariant, size: 32)),
                  ))));
    });
  }
}

class _ArticlePreview extends StatelessWidget {
  const _ArticlePreview({required this.article});
  final NewsArticle article;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Semantics(
          header: true,
          child: EmojiText(newsTitle(context, article),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: dashboardCardTitleStyle(context))),
      if (article.excerpt.isNotEmpty) ...[
        const SizedBox(height: 16),
        EmojiText(article.excerpt,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
      ],
    ]);
  }
}

Future<void> showNewsFeed(BuildContext context, String url,
    {String? tag}) async {
  await BaseNavigator.push<void>(context, NewsPage(url: url, tag: tag));
}

class NewsPage extends ConsumerWidget {
  const NewsPage({super.key, required this.url, this.tag});
  final String url;
  final String? tag;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = AppLocalizations.of(context);
    final result = ref.watch(newsFeedProvider(url));
    final theme = Theme.of(context);
    final tv = ref.watch(isAndroidTVProvider).valueOrNull ?? false;
    return CommonScaffold(
      title: strings.news,
      enableAppBarScrolledUnderEffect: true,
      actions: [
        CommonHeaderIconButton(
            tooltip: strings.update,
            onPressed:
                result.isLoading || (result.valueOrNull?.isRefreshing ?? false)
                    ? null
                    : () => refreshNews(ref, url),
            icon: const Icon(Icons.refresh_rounded))
      ],
      body: SafeArea(
          top: false,
          child: Center(
              child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1120),
                  child: Column(children: [
                    if (result.isLoading)
                      LinearProgressIndicator(
                          semanticsLabel: strings.newsLoading),
                    Expanded(
                        child: result.when(
                      skipLoadingOnReload: true,
                      loading: () => const SizedBox.shrink(),
                      error: (_, __) => Center(
                          child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(strings.newsLoadFailed),
                                    const SizedBox(height: 16),
                                    OutlinedButton(
                                        onPressed: () => refreshNews(ref, url),
                                        child: Text(strings.retry)),
                                  ]))),
                      data: (data) {
                        final articles = data.feed.forTag(tag).articles;
                        final sourceVisible = data.feed.title.isNotEmpty ||
                            data.feed.link != null;
                        final prefixCount =
                            (sourceVisible ? 1 : 0) + (data.isStale ? 1 : 0);
                        return ListView.separated(
                            padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
                            itemCount: prefixCount +
                                (articles.isEmpty ? 1 : articles.length),
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 16),
                            itemBuilder: (context, index) {
                              if (sourceVisible && index == 0) {
                                return _FeedSource(
                                    feed: data.feed, isAndroidTV: tv);
                              }
                              if (data.isStale &&
                                  index == (sourceVisible ? 1 : 0)) {
                                return Text(strings.newsCached);
                              }
                              if (articles.isEmpty) {
                                return Text(strings.newsEmpty);
                              }
                              final article = articles[index - prefixCount];
                              return TVFocusEffect(
                                enabled: tv,
                                borderRadius: BorderRadius.circular(24),
                                child: Card.filled(
                                  margin: EdgeInsets.zero,
                                  color: theme.colorScheme.surfaceContainer,
                                  clipBehavior: Clip.antiAlias,
                                  shape: const RoundedRectangleBorder(
                                      borderRadius: BorderRadius.all(
                                          Radius.circular(24))),
                                  child: InkWell(
                                      canRequestFocus: false,
                                      onTap: () => unawaited(
                                          showNewsArticle(context, article)),
                                      child: _ArticleCardBody(
                                        article: article,
                                        footer: Padding(
                                          padding: const EdgeInsets.all(16),
                                          child: Row(children: [
                                            Expanded(
                                                child: article.publishedAt ==
                                                        null
                                                    ? const SizedBox.shrink()
                                                    : Text(
                                                        newsDate(
                                                            context,
                                                            article
                                                                .publishedAt),
                                                        style: theme
                                                            .textTheme.bodySmall
                                                            ?.copyWith(
                                                                color: theme
                                                                    .colorScheme
                                                                    .onSurfaceVariant))),
                                            const SizedBox(width: 12),
                                            FilledButton(
                                                onPressed: () => unawaited(
                                                    showNewsArticle(
                                                        context, article)),
                                                child: Text(strings.readNews)),
                                          ]),
                                        ),
                                      )),
                                ),
                              );
                            });
                      },
                    )),
                  ])))),
    );
  }
}

class _FeedSource extends StatelessWidget {
  const _FeedSource({required this.feed, required this.isAndroidTV});
  final NewsFeed feed;
  final bool isAndroidTV;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final strings = AppLocalizations.of(context);
    final link = feed.link;
    final username = feed.telegramUsername;
    final telegram = link != null &&
        const {'t.me', 'telegram.me', 'www.t.me', 'www.telegram.me'}
            .contains(link.host.toLowerCase());
    final target = username == null ? link : link!.replace(path: '/$username');
    final identity = Row(children: [
      ClipOval(
          child: SizedBox.square(
              dimension: 48,
              child: feed.icon == null
                  ? ColoredBox(
                      color: theme.colorScheme.secondaryContainer,
                      child: const Icon(Icons.rss_feed_rounded))
                  : CachedNetworkImage(
                      imageUrl: feed.icon.toString(),
                      fit: BoxFit.cover,
                      memCacheWidth:
                          (48 * MediaQuery.devicePixelRatioOf(context)).ceil(),
                      errorWidget: (_, __, ___) => ColoredBox(
                          color: theme.colorScheme.secondaryContainer,
                          child: const Icon(Icons.rss_feed_rounded))))),
      const SizedBox(width: 16),
      Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        EmojiText(feed.title.isNotEmpty ? feed.title : link!.host,
            style: theme.textTheme.titleMedium),
        if (username != null) ...[
          const SizedBox(height: 4),
          Text('@$username',
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        ],
      ])),
    ]);
    final action = target == null
        ? null
        : TVFocusEffect(
            enabled: isAndroidTV,
            borderRadius: BorderRadius.circular(isAndroidTV ? 24 : 20),
            scrollAlignment: 0.55,
            child: SizedBox(
              height: isAndroidTV ? 48 : 40,
              child: FilledButton.tonalIcon(
                  onPressed: () =>
                      unawaited(globalState.openUrl(target.toString())),
                  icon: telegram
                      ? const TelegramIcon(size: 20)
                      : const Icon(Icons.open_in_new_rounded, size: 20),
                  label: Text(
                      telegram ? strings.newsSubscribe : strings.newsOpenFeed)),
            ),
          );
    return Card.filled(
      margin: EdgeInsets.zero,
      color: theme.colorScheme.surfaceContainerHigh,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(24))),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: LayoutBuilder(builder: (context, constraints) {
          if (constraints.maxWidth /
                  (MediaQuery.textScalerOf(context).scale(16) / 16) <
              420) {
            return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  identity,
                  if (action != null) ...[
                    const SizedBox(height: 12),
                    action,
                  ],
                ]);
          }
          return Row(children: [
            Expanded(child: identity),
            if (action != null) ...[const SizedBox(width: 16), action]
          ]);
        }),
      ),
    );
  }
}
