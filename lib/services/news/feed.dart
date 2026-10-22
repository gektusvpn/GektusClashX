import 'dart:convert';
import 'dart:io';

import 'package:html/dom.dart' as html;
import 'package:html/parser.dart' as html_parser;
import 'package:xml/xml.dart';

Uri? newsHttpUri(String? value, [Uri? base]) {
  if (value == null || value.trim().isEmpty) return null;
  final parsed = Uri.tryParse(value.trim());
  if (parsed == null) return null;
  final uri = base?.resolveUri(parsed) ?? parsed;
  if (!const ['https', 'http'].contains(uri.scheme) ||
      uri.host.isEmpty ||
      uri.userInfo.isNotEmpty) {
    return null;
  }
  return uri;
}

class NewsArticle {
  const NewsArticle(
      {required this.id,
      required this.title,
      required this.body,
      required this.summary,
      this.publishedAt,
      this.image,
      this.tags = const [],
      this.link});

  final String id;
  final String title;

  /// Sanitized HTML rendered as native widgets, never a web view.
  final String body;
  final String summary;
  final DateTime? publishedAt;
  final Uri? link;
  final Uri? image;
  final List<String> tags;

  /// The sheet already displays the heading; retain the rest of the HTML and
  /// all gallery images, including feeds that supply a separate enclosure.
  String get readingBody {
    final fragment = html_parser.parseFragment(body);
    if (title.isNotEmpty && _plainText(body).split('\n').first == title) {
      final heading = <html.Node>[];
      for (final node in fragment.nodes.toList()) {
        if (node is html.Element &&
            (node.localName == 'img' || node.querySelector('img') != null)) {
          continue;
        }
        heading.add(node);
        final prefix = _plainText(heading
            .map((n) => n is html.Element
                ? n.outerHtml
                : const HtmlEscape().convert(n.text ?? ''))
            .join());
        if (!title.startsWith(prefix)) break;
        if (prefix == title) {
          for (final part in heading) {
            part.remove();
          }
          break;
        }
      }
      while (fragment.nodes.isNotEmpty) {
        final node = fragment.nodes.first;
        if ((node is html.Text && node.text.trim().isEmpty) ||
            (node is html.Element && node.localName == 'br')) {
          node.remove();
        } else {
          break;
        }
      }
    }
    if (image != null) {
      final original = fragment
          .querySelectorAll('img')
          .where((e) => newsHttpUri(e.attributes['src']) == image)
          .firstOrNull;
      final cover = original ??
          (html.Element.tag('img')..attributes['src'] = image.toString());
      // Telegram feeds often append the gallery after the text. Promote the
      // cover to the beginning without showing the same image twice.
      fragment.nodes.insertAll(0, [cover..remove(), html.Element.tag('br')]);
    }
    _removeTrailingHashtags(fragment);
    return fragment.outerHtml;
  }

  /// A short, readable sentence after the heading, without repeating it.
  String get excerpt {
    var text = summary;
    if (title.isNotEmpty && text.startsWith(title)) {
      text = text.substring(title.length).trim();
    }
    final paragraph = text
            .split('\n')
            .where((line) =>
                line.trim().isNotEmpty &&
                !RegExp(r'^#[\p{L}\p{N}_]+$', unicode: true)
                    .hasMatch(line.trim()))
            .firstOrNull ??
        '';
    final sentenceEnd = RegExp(r'[.!?…](?:\s|$)').firstMatch(paragraph);
    return sentenceEnd == null
        ? paragraph
        : paragraph.substring(0, sentenceEnd.start + 1);
  }
}

class NewsFeed {
  const NewsFeed(
      {required this.title, required this.articles, this.link, this.icon});
  factory NewsFeed.parse(String source, Uri feedUri) {
    if (source.trimLeft().startsWith('{')) {
      return NewsFeed._parseJson(source, feedUri);
    }
    final document = XmlDocument.parse(source);
    final root = document.rootElement;
    final atom = root.name.local == 'feed';
    final channel = atom ? root : _child(root, 'channel');
    if ((!atom && root.name.local != 'rss') || channel == null) {
      throw const FormatException('Expected RSS or Atom');
    }
    final entries = channel.childElements.where(
      (node) => node.name.local == (atom ? 'entry' : 'item'),
    );
    final articles = <NewsArticle>[];
    final ids = <String>{};
    for (final entry in entries.take(maxArticles)) {
      final rawLink = atom
          ? entry.childElements
              .where((e) =>
                  e.name.local == 'link' &&
                  (e.getAttribute('rel') ?? 'alternate') == 'alternate')
              .firstOrNull
              ?.getAttribute('href')
          : _text(entry, 'link');
      final link = newsHttpUri(rawLink, feedUri);
      final content = _child(entry, atom ? 'content' : 'encoded') ??
          _child(entry, atom ? 'summary' : 'description');
      final rawBody = content?.getAttribute('type') == 'xhtml'
          ? content!.innerXml
          : content?.innerText ?? '';
      final body = _sanitize(rawBody, link ?? feedUri);
      final image = _bodyImage(body) ??
          entry.childElements
              .where((e) =>
                  e.name.local == 'thumbnail' ||
                  (e.name.local == 'content' &&
                      (e.getAttribute('medium') == 'image' ||
                          (e.getAttribute('type') ?? '')
                              .startsWith('image/'))) ||
                  (e.name.local == 'enclosure' &&
                      (e.getAttribute('type') ?? '').startsWith('image/')))
              .map((e) => newsHttpUri(e.getAttribute('url'), link ?? feedUri))
              .nonNulls
              .firstOrNull;
      final summary = _plainText(body);
      final rawTitle =
          _plainText(_sanitize(_text(entry, 'title'), link ?? feedUri));
      final title = _articleTitle(body, rawTitle, summary);
      if (title.isEmpty && summary.isEmpty && image == null) continue;
      final publishedAt =
          _parseDate(_text(entry, atom ? 'published' : 'pubDate')) ??
              _parseDate(_text(entry, atom ? 'updated' : 'date'));
      final suppliedId = _text(entry, atom ? 'id' : 'guid');
      final id = suppliedId.isNotEmpty
          ? suppliedId
          : link?.toString() ?? '$title|$publishedAt|$summary';
      if (!ids.add(id)) continue;
      articles.add(NewsArticle(
          id: id,
          title: title,
          body: body,
          summary: summary,
          publishedAt: publishedAt,
          image: image,
          tags: _tags(
              summary,
              entry.childElements.where((e) => e.name.local == 'category').map(
                  (e) => atom
                      ? e.getAttribute('term') ?? e.innerText
                      : e.innerText)),
          link: link));
    }
    return NewsFeed._sorted(
        _plainText(_sanitize(_text(channel, 'title'), feedUri)), articles,
        link: newsHttpUri(
            atom
                ? channel.childElements
                    .where((e) =>
                        e.name.local == 'link' &&
                        (e.getAttribute('rel') ?? 'alternate') == 'alternate')
                    .firstOrNull
                    ?.getAttribute('href')
                : _text(channel, 'link'),
            feedUri),
        icon: newsHttpUri(
            atom
                ? (_text(channel, 'icon').isNotEmpty
                    ? _text(channel, 'icon')
                    : _text(channel, 'logo'))
                : (_child(channel, 'image') == null
                    ? null
                    : _text(_child(channel, 'image')!, 'url')),
            feedUri));
  }

  factory NewsFeed._parseJson(String source, Uri feedUri) {
    final decoded = jsonDecode(source);
    if (decoded is! Map<String, dynamic> ||
        !const [
          'https://jsonfeed.org/version/1',
          'https://jsonfeed.org/version/1.1'
        ].contains(decoded['version']) ||
        decoded['items'] is! List) {
      throw const FormatException('Expected JSON Feed');
    }
    final articles = <NewsArticle>[];
    final ids = <String>{};
    for (final entry in (decoded['items'] as List).take(maxArticles)) {
      if (entry is! Map<String, dynamic>) continue;
      final link = newsHttpUri(_string(entry['url']), feedUri);
      final base = link ?? feedUri;
      final rawHtml = _string(entry['content_html']);
      final body = _sanitize(
          rawHtml.isNotEmpty
              ? rawHtml
              : '<p>${const HtmlEscape().convert(_string(entry['content_text'])).replaceAll('\n', '<br>')}</p>',
          base);
      final summary = _plainText(body);
      final rawTitle = _plainText(_sanitize(_string(entry['title']), base));
      // RSS-Bridge generates a truncated preview as the title. Restore the
      // complete first line of the post instead of repeating its excerpt.
      final title = _articleTitle(body, rawTitle, summary);
      final attachments = entry['attachments'];
      final image = newsHttpUri(_string(entry['image']), base) ??
          newsHttpUri(_string(entry['banner_image']), base) ??
          _bodyImage(body) ??
          (attachments is List
              ? attachments
                  .whereType<Map<String, dynamic>>()
                  .where((a) => _string(a['mime_type']).startsWith('image/'))
                  .map((a) => newsHttpUri(_string(a['url']), base))
                  .nonNulls
                  .firstOrNull
              : null);
      if (title.isEmpty && summary.isEmpty && image == null) continue;
      final publishedAt = _parseDate(_string(entry['date_published'])) ??
          _parseDate(_string(entry['date_modified']));
      final suppliedId = _string(entry['id']);
      final id = suppliedId.isNotEmpty
          ? suppliedId
          : link?.toString() ?? '$title|$publishedAt|$summary|$image';
      if (!ids.add(id)) continue;
      articles.add(NewsArticle(
          id: id,
          title: title,
          body: body,
          summary: summary,
          publishedAt: publishedAt,
          link: link,
          image: image,
          tags: _tags(
              summary,
              entry['tags'] is List
                  ? (entry['tags'] as List).whereType<String>()
                  : const [])));
    }
    return NewsFeed._sorted(
        _plainText(_sanitize(_string(decoded['title']), feedUri)), articles,
        link: newsHttpUri(_string(decoded['home_page_url']), feedUri),
        icon: newsHttpUri(
            _string(decoded['icon']).isNotEmpty
                ? _string(decoded['icon'])
                : _string(decoded['favicon']),
            feedUri));
  }

  factory NewsFeed._sorted(String title, List<NewsArticle> articles,
      {Uri? link, Uri? icon}) {
    // Stable ordering: dated posts first, undated posts retain feed order.
    final indexes = {
      for (var i = 0; i < articles.length; i++) articles[i].id: i
    };
    articles.sort((a, b) {
      final dateOrder = a.publishedAt == null
          ? (b.publishedAt == null ? 0 : 1)
          : b.publishedAt == null
              ? -1
              : b.publishedAt!.compareTo(a.publishedAt!);
      return dateOrder != 0
          ? dateOrder
          : indexes[a.id]!.compareTo(indexes[b.id]!);
    });
    return NewsFeed(
        title: title,
        articles: List.unmodifiable(articles),
        link: link,
        icon: icon);
  }

  final String title;
  final Uri? link;
  final Uri? icon;
  final List<NewsArticle> articles;

  /// Public Telegram channel links expose the username without an API request.
  String? get telegramUsername {
    final uri = link;
    if (uri == null ||
        !const {'t.me', 'telegram.me', 'www.t.me', 'www.telegram.me'}
            .contains(uri.host.toLowerCase())) {
      return null;
    }
    final parts = uri.pathSegments.where((part) => part.isNotEmpty).toList();
    final name = parts.length == 1
        ? parts.first
        : parts.length == 2 && parts.first == 's'
            ? parts.last
            : null;
    // Invite links and internal Telegram routes do not identify a public channel.
    if (name == null ||
        !RegExp(r'^[A-Za-z][A-Za-z0-9_]*$').hasMatch(name) ||
        const {
          's',
          'c',
          'joinchat',
          'share',
          'proxy',
          'socks',
          'addstickers',
          'addemoji'
        }.contains(name.toLowerCase())) {
      return null;
    }
    return name;
  }

  static const maxArticles = 100;

  NewsFeed forTag(String? tag) {
    final wanted = _normalizeTag(tag ?? '');
    if (wanted.isEmpty) return this;
    return NewsFeed(
        title: title,
        link: link,
        icon: icon,
        articles: List.unmodifiable(
            articles.where((article) => article.tags.contains(wanted))));
  }
}

/// Hide a final tag-only paragraph without changing tags used for filtering.
/// Walk text leaves so linked tags and appended Telegram galleries work alike.
void _removeTrailingHashtags(html.DocumentFragment fragment) {
  final text = StringBuffer();
  final leaves = <(html.Text, int)>[];
  void visit(html.Node node) {
    if (node is html.Text) {
      leaves.add((node, text.length));
      text.write(node.text);
    } else {
      node.nodes.forEach(visit);
      if (node is html.Element &&
          const {'br', 'p', 'div', 'li', 'blockquote'}
              .contains(node.localName)) {
        text.writeln();
      }
    }
  }

  visit(fragment);
  final suffix = RegExp(
          r'(?:^|\n)\s*#[\p{L}\p{N}_]+(?:\s+#[\p{L}\p{N}_]+)*\s*$',
          unicode: true)
      .firstMatch(text.toString());
  if (suffix == null) return;
  for (final (node, start) in leaves) {
    if (start + node.text.length > suffix.start) {
      node.text = node.text
          .substring(0, (suffix.start - start).clamp(0, node.text.length));
    }
  }
  void trim(html.Node node) {
    for (final child in node.nodes.toList()) {
      if (child is html.Element) {
        trim(child);
        if (child.localName != 'img' &&
            child.localName != 'br' &&
            child.nodes.isEmpty) {
          child.remove();
        }
      } else if (child is html.Text && child.text.isEmpty) {
        child.remove();
      }
    }
    while (node.nodes.isNotEmpty &&
        node.nodes.last is html.Element &&
        (node.nodes.last as html.Element).localName == 'br') {
      node.nodes.last.remove();
    }
  }

  trim(fragment);
}

String _string(Object? value) => value is String ? value.trim() : '';
Uri? _bodyImage(String body) => newsHttpUri(
    html_parser.parseFragment(body).querySelector('img')?.attributes['src']);

String _articleTitle(String body, String supplied, String summary) {
  final firstLine = summary.split('\n').first;
  final fragment = html_parser.parseFragment(body);
  final bold = fragment.querySelector('b, strong, h1, h2, h3');
  final boldText = bold == null ? '' : _plainText(bold.outerHtml);
  // Telegram headings can start with an emoji outside the bold element.
  if (boldText.isNotEmpty &&
      firstLine.length <= 200 &&
      firstLine.endsWith(boldText) &&
      firstLine.indexOf(boldText) <= 8) {
    return firstLine;
  }
  if (supplied.isEmpty || supplied.endsWith('...') || supplied.endsWith('…')) {
    return firstLine.isNotEmpty ? firstLine : supplied;
  }
  return supplied;
}

String _normalizeTag(String tag) =>
    tag.trim().replaceFirst(RegExp(r'^#'), '').toLowerCase();
List<String> _tags(String text, Iterable<String> categories) =>
    List.unmodifiable({
      ...categories.map(_normalizeTag).where((tag) => tag.isNotEmpty),
      ...RegExp(r'(?<![\p{L}\p{N}_])#([\p{L}\p{N}_]+)', unicode: true)
          .allMatches(text)
          .map((match) => match[1]!.toLowerCase()),
    });

XmlElement? _child(XmlElement node, String name) =>
    node.childElements.where((e) => e.name.local == name).firstOrNull;
String _text(XmlElement node, String name) =>
    _child(node, name)?.innerText.trim() ?? '';

String _sanitize(String source, Uri base) {
  // A bounded feed also bounds HTML parsing and layout cost.
  final fragment = html_parser.parseFragment(source);
  const removed = {
    'script',
    'style',
    'iframe',
    'object',
    'embed',
    'form',
    'input',
    'button',
    'video',
    'audio',
    'source',
    'link',
    'meta',
    'svg'
  };
  for (final element in fragment.querySelectorAll('*').toList()) {
    if (removed.contains(element.localName)) {
      element.remove();
      continue;
    }
    final href = element.localName == 'a'
        ? newsHttpUri(element.attributes['href'], base)
        : null;
    final src = element.localName == 'img'
        ? newsHttpUri(element.attributes['src'], base)
        : null;
    final alt = element.attributes['alt'];
    element.attributes.clear();
    if (href != null) element.attributes['href'] = href.toString();
    if (element.localName == 'img') {
      if (src == null) {
        element.remove();
      } else {
        element.attributes['src'] = src.toString();
        if (alt != null) element.attributes['alt'] = alt;
      }
    }
  }
  return fragment.outerHtml;
}

String _plainText(String source) {
  final fragment = html_parser.parseFragment(source);
  final buffer = StringBuffer();
  void visit(html.Node node) {
    if (node is html.Text) {
      buffer.write(node.text);
    } else {
      node.nodes.forEach(visit);
      if (node is html.Element &&
          const {
            'br',
            'p',
            'div',
            'li',
            'h1',
            'h2',
            'h3',
            'h4',
            'h5',
            'h6',
            'blockquote'
          }.contains(node.localName)) {
        buffer.writeln();
      }
    }
  }

  visit(fragment);
  return buffer
      .toString()
      .replaceAll(RegExp(r'[^\S\n]+'), ' ')
      .replaceAll(RegExp(r' *\n *'), '\n')
      .replaceAll(RegExp(r'\n{3,}'), '\n\n')
      .trim();
}

DateTime? _parseDate(String value) {
  final iso = DateTime.tryParse(value);
  if (iso != null) return iso.toUtc();
  try {
    return HttpDate.parse(value).toUtc();
  } on Exception {/* RSS offsets below. */}
  final match = RegExp(
          r'^(?:\w{3},\s*)?(\d{1,2}) (\w{3}) (\d{4}) (\d{2}):(\d{2})(?::(\d{2}))? ([+-])(\d{2})(\d{2})$')
      .firstMatch(value);
  if (match == null) return null;
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec'
  ];
  final month = months.indexOf(match[2]!) + 1;
  if (month == 0) return null;
  final offset = (int.parse(match[8]!) * 60 + int.parse(match[9]!)) *
      (match[7] == '+' ? 1 : -1);
  return DateTime.utc(
          int.parse(match[3]!),
          month,
          int.parse(match[1]!),
          int.parse(match[4]!),
          int.parse(match[5]!),
          int.parse(match[6] ?? '0'))
      .subtract(Duration(minutes: offset));
}
