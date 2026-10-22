import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';
import 'package:gektusclashx/l10n/l10n.dart';
import 'package:gektusclashx/providers/app.dart';
import 'package:gektusclashx/services/news/feed.dart';
import 'package:gektusclashx/state.dart';
import 'package:gektusclashx/widgets/text.dart';

import 'common.dart';

Future<void> showNewsArticle(BuildContext context, NewsArticle article) =>
    _showNewsSheet(context, NewsArticleView(article: article));

Future<void> _showNewsSheet(BuildContext context, Widget child) async {
  final tv = await ProviderScope.containerOf(context, listen: false)
      .read(isAndroidTVProvider.future);
  if (!context.mounted) return;
  final height = MediaQuery.sizeOf(context).height * 0.88;
  final colors = Theme.of(context).colorScheme;
  if (tv) {
    await showDialog<void>(
        context: context,
        builder: (_) => Dialog(
              backgroundColor: colors.surfaceContainerHigh,
              clipBehavior: Clip.antiAlias,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28)),
              child: SizedBox(width: 720, height: height, child: child),
            ));
  } else {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      constraints: const BoxConstraints(maxWidth: 720),
      shape: const RoundedSuperellipseBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      clipBehavior: Clip.antiAlias,
      builder: (_) => SafeArea(
          top: false, child: SizedBox(height: height - 48, child: child)),
    );
  }
}

class _SheetHeading extends StatelessWidget {
  const _SheetHeading({required this.title});
  final String title;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 12, 16),
        child: Row(children: [
          Expanded(
              child: Semantics(
                  header: true,
                  child: EmojiText(title,
                      style: dashboardCardTitleStyle(context)))),
          const SizedBox(width: 8),
          const CloseButton(),
        ]),
      );
}

class NewsArticleView extends ConsumerStatefulWidget {
  const NewsArticleView({super.key, required this.article});
  final NewsArticle article;
  @override
  ConsumerState<NewsArticleView> createState() => _NewsArticleViewState();
}

class _NewsArticleViewState extends ConsumerState<NewsArticleView> {
  final _scroll = ScrollController();
  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final article = widget.article;
    final tv = ref.watch(isAndroidTVProvider).valueOrNull ?? false;
    return Column(children: [
      _SheetHeading(title: newsTitle(context, article)),
      Expanded(
          child: Focus(
        autofocus: tv,
        onKeyEvent: (node, event) {
          if (!node.hasPrimaryFocus ||
              event is KeyUpEvent ||
              !_scroll.hasClients) {
            return KeyEventResult.ignored;
          }
          final direction = event.logicalKey == LogicalKeyboardKey.arrowDown
              ? 1
              : event.logicalKey == LogicalKeyboardKey.arrowUp
                  ? -1
                  : 0;
          if (direction == 0) return KeyEventResult.ignored;
          final target = (_scroll.offset + direction * 160)
              .clamp(0.0, _scroll.position.maxScrollExtent);
          if (target == _scroll.offset) return KeyEventResult.ignored;
          unawaited(_scroll.animateTo(target,
              duration: const Duration(milliseconds: 160),
              curve: Curves.easeOut));
          return KeyEventResult.handled;
        },
        child: Scrollbar(
            controller: _scroll,
            child: ListView(
              controller: _scroll,
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
              children: [
                HtmlWidget(
                  article.readingBody,
                  factoryBuilder: _NewsWidgetFactory.new,
                  textStyle: DefaultTextStyle.of(context)
                      .style
                      .merge(theme.textTheme.bodyLarge)
                      .copyWith(height: 1.5),
                  onLoadingBuilder: (_, element, progress) =>
                      element.localName == 'img'
                          ? AspectRatio(
                              aspectRatio: 16 / 9,
                              child: Center(
                                  child: CircularProgressIndicator(
                                      value: progress)))
                          : null,
                  onTapUrl: (url) async {
                    final uri = newsHttpUri(url);
                    if (uri != null) await globalState.openUrl(uri.toString());
                    return true;
                  },
                  onErrorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
                if (article.publishedAt != null || article.link != null) ...[
                  const SizedBox(height: 24),
                  LayoutBuilder(builder: (context, constraints) {
                    final date = Text(newsDate(context, article.publishedAt),
                        style: theme.textTheme.labelMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant));
                    final source = article.link == null
                        ? null
                        : OutlinedButton.icon(
                            onPressed: () => unawaited(
                                globalState.openUrl(article.link.toString())),
                            icon: const Icon(Icons.open_in_new_rounded),
                            label: Text(strings.newsSource));
                    if (constraints.maxWidth /
                            (MediaQuery.textScalerOf(context).scale(16) / 16) <
                        360) {
                      return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (article.publishedAt != null) date,
                            if (source != null) ...[
                              const SizedBox(height: 12),
                              Align(
                                  alignment: AlignmentDirectional.centerEnd,
                                  child: source)
                            ],
                          ]);
                    }
                    return Row(children: [
                      Expanded(child: date),
                      if (source != null) ...[const SizedBox(width: 16), source]
                    ]);
                  }),
                ],
              ],
            )),
      )),
    ]);
  }
}

class _NewsWidgetFactory extends WidgetFactory {
  @override
  Widget? buildImage(BuildTree tree, ImageMetadata data) {
    final image = super.buildImage(tree, data);
    return image == null
        ? null
        : Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: ClipRRect(
                borderRadius: BorderRadius.circular(32), child: image));
  }

  @override
  ImageProvider? imageProviderFromNetwork(String url) =>
      newsHttpUri(url) == null ? null : CachedNetworkImageProvider(url);

  @override
  InlineSpan? buildTextSpan(
          {List<InlineSpan>? children,
          GestureRecognizer? recognizer,
          TextStyle? style,
          String? text}) =>
      super.buildTextSpan(style: style, recognizer: recognizer, children: [
        if (text != null) ...emojiTextSpans(text, recognizer: recognizer),
        ...?children,
      ]);
}
