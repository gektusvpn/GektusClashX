import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:gektusclashx/services/news/feed.dart';

import '../fixtures/news_feed.dart';

void main() {
  const fixture = sampleNewsFeed;
  final uri = Uri.parse('https://feed.example/news');
  test(
      'RSS prefers full content, sorts dates, decodes text and removes duplicates',
      () {
    final feed = NewsFeed.parse(fixture, uri);
    expect(feed.articles, hasLength(2));
    final latest = feed.articles.first;
    expect(latest.id, 'post-2');
    expect(latest.body, contains('<strong>обновление</strong>'));
    expect(latest.summary, contains('Что изменилось\n'));
    expect(latest.summary, isNot(contains('<')));
    expect(latest.publishedAt, DateTime.utc(2026, 10, 22, 9, 30));
  });

  test('feed identity is safe and survives tag filtering in RSS, Atom and JSON',
      () {
    final rss = NewsFeed.parse(
        fixture.replaceFirst('<link>https://t.me/example</link>',
            '<link>https://t.me/s/example</link><image><url>/avatar.jpg</url></image>'),
        uri);
    expect(rss.link, Uri.parse('https://t.me/s/example'));
    expect(rss.icon, Uri.parse('https://feed.example/avatar.jpg'));
    expect(rss.forTag('missing').link, rss.link);
    expect(rss.forTag('missing').icon, rss.icon);
    final atom = NewsFeed.parse(
        '<feed><title>Source</title><link rel="self" href="/feed"/><link href="/channel"/><icon>/avatar.png</icon></feed>',
        uri);
    expect(atom.link, Uri.parse('https://feed.example/channel'));
    expect(atom.icon, Uri.parse('https://feed.example/avatar.png'));
    final json = NewsFeed.parse(
        jsonEncode({
          'version': 'https://jsonfeed.org/version/1.1',
          'title': 'Source',
          'home_page_url': 'javascript:alert(1)',
          'icon': 'file:///avatar.png',
          'items': []
        }),
        uri);
    expect(json.link, isNull);
    expect(json.icon, isNull);
  });

  test(
      'reading hides only trailing tag paragraphs, preserving inline tags and galleries',
      () {
    for (final ending in [
      '<p>#GektusClashX #Новости</p>',
      '<br><a href="/tag">#GektusClashX</a> <a href="/tag2">#Новости</a><br><br><div><p><img src="/cover.jpg"></p></div>',
      '\n#GektusClashX\n#Новости',
    ]) {
      final feed = NewsFeed.parse(
          '<rss><channel><item><title>Title</title><description><![CDATA[<p>Use #VPN in this sentence.</p><p>Keep <b>these</b> words.</p>$ending]]></description></item></channel></rss>',
          uri);
      final article = feed.articles.single;
      expect(article.readingBody, contains('Use #VPN in this sentence.'));
      expect(article.readingBody, contains('Keep <b>these</b> words.'));
      expect(article.readingBody, isNot(contains('#GektusClashX')));
      expect(article.readingBody, isNot(contains('#Новости')));
      expect(feed.forTag('GektusClashX').articles, hasLength(1));
      if (ending.contains('<img')) {
        expect(article.readingBody, contains('https://feed.example/cover.jpg'));
      }
    }
    final article = NewsFeed.parse(
            '<rss><channel><item><title>Title</title><description><![CDATA[<p>Read more about #VPN</p>]]></description></item></channel></rss>',
            uri)
        .articles
        .single;
    expect(article.readingBody, contains('Read more about #VPN'));
  });

  test('Telegram usernames come only from public channel URLs', () {
    NewsFeed source(String link) =>
        NewsFeed(title: '', articles: const [], link: Uri.parse(link));
    expect(source('https://t.me/gektusvpn').telegramUsername, 'gektusvpn');
    expect(source('https://t.me/s/GektusVPN').telegramUsername, 'GektusVPN');
    expect(
        source('https://telegram.me/gektusvpn/').telegramUsername, 'gektusvpn');
    expect(source('https://example.com/gektusvpn').telegramUsername, isNull);
    expect(source('https://t.me/+invite').telegramUsername, isNull);
    expect(source('https://t.me/joinchat/invite').telegramUsername, isNull);
    expect(source('https://t.me/c/123456').telegramUsername, isNull);
    expect(source('https://t.me/share').telegramUsername, isNull);
  });

  test('Atom uses alternate links, fallback titles and missing dates', () {
    final feed = NewsFeed.parse(
        '''<feed xmlns="http://www.w3.org/2005/Atom"><title>Feed</title>
<entry><id>one</id><link rel="self" href="/api/1"/><link href="/posts/1"/>
<updated>2026-10-22T12:00:00Z</updated><content type="html">&lt;p&gt;First line&lt;br&gt;Second line&lt;/p&gt;</content></entry>
<entry><id>two</id><title>Undated</title><summary>Body</summary></entry></feed>''',
        uri);
    expect(feed.articles.first.link.toString(), 'https://feed.example/posts/1');
    expect(feed.articles.first.title, 'First line');
    expect(feed.articles.last.publishedAt, isNull);
  });

  test('Telegram RSS uses the bold heading, first sentence and gallery cover',
      () {
    final article = NewsFeed.parse(
            '''<rss xmlns:content="http://purl.org/rss/1.0/modules/content/"><channel>
<item><title>Generated excerpt...</title><description></description>
<content:encoded><![CDATA[⚡️ <b>Трафика стало больше</b><br/><br/>Пакеты доступны на my.example.com. Остаток переносится на следующий месяц!<br/><br/>#GektusClashX<br/><div><p><img src="/cover.jpg"></p></div>]]></content:encoded>
</item></channel></rss>''', uri)
        .articles
        .single;
    expect(article.title, '⚡️ Трафика стало больше');
    expect(article.excerpt, 'Пакеты доступны на my.example.com.');
    expect(article.image, Uri.parse('https://feed.example/cover.jpg'));
    expect(article.tags, contains('gektusclashx'));
    expect(article.body, contains('<b>Трафика стало больше</b>'));
    expect(article.readingBody, isNot(contains('Трафика стало больше')));
    expect(article.readingBody,
        contains('<img src="https://feed.example/cover.jpg">'));
    expect(article.readingBody,
        startsWith('<img src="https://feed.example/cover.jpg">'));
    expect('<img'.allMatches(article.readingBody), hasLength(1));
  });

  test(
      'JSON Feed supports RSS-Bridge HTML, dates, covers and plain text safely',
      () {
    final feed = NewsFeed.parse(
        jsonEncode({
          'version': 'https://jsonfeed.org/version/1',
          'title': 'Service',
          'items': [
            {
              'id': 'old',
              'content_text': '<script>Text only</script>\nSecond line',
              'date_published': '2026-01-01T00:00:00Z',
              'image': 'file:///etc/passwd',
              'attachments': [
                {'mime_type': 'image/jpeg', 'url': '/attachment.jpg'}
              ]
            },
            {
              'id': 'latest',
              'url': '/posts/2',
              'title': 'An incomplete...',
              'content_html':
                  '<a href="/posts/2"><img src="//img.example/cover.jpg"></a><br><b>A complete heading</b><br><br>First sentence. Second sentence.<script>bad()</script>',
              'date_modified': '2026-10-22T12:00:00+03:00',
              'tags': ['GektusClashX']
            },
            {'id': 'latest', 'content_text': 'Duplicate'},
          ],
        }),
        uri);
    expect(feed.articles, hasLength(2));
    final article = feed.articles.first;
    expect(article.title, 'A complete heading');
    expect(article.excerpt, 'First sentence.');
    expect(article.image, Uri.parse('https://img.example/cover.jpg'));
    expect(article.publishedAt, DateTime.utc(2026, 10, 22, 9));
    expect(article.body, isNot(contains('bad()')));
    expect(feed.articles.last.body,
        contains('&lt;script&gt;Text only&lt;/script&gt;'));
    expect(feed.articles.last.image,
        Uri.parse('https://feed.example/attachment.jpg'));
    expect(feed.forTag('#gektusclashx').articles.single.id, 'latest');
    expect(() => NewsFeed.parse('{"items": []}', uri), throwsFormatException);
  });

  test(
      'tag filter is optional, exact, case-insensitive and supports RSS categories',
      () {
    final feed = NewsFeed.parse('''<rss><channel>
<item><guid>1</guid><description>#GEKTUSCLASHX Announcement</description></item>
<item><guid>2</guid><description>#GektusClashXExtra Other app</description></item>
<item><guid>3</guid><description>News</description><category>GektusClashX</category></item>
<item><guid>4</guid><description>Unmarked post</description></item>
</channel></rss>''', uri);
    expect(feed.forTag(null).articles, hasLength(4));
    expect(
        feed.forTag('  #GektusClashX ').articles.map((a) => a.id), ['1', '3']);
    expect(feed.forTag('missing').articles, isEmpty);
  });

  test('image-only enclosures are retained; invalid image URLs are ignored',
      () {
    final feed = NewsFeed.parse('''<rss><channel>
<item><guid>image</guid><enclosure type="image/jpeg" url="/image.jpg"/></item>
<item><guid>invalid</guid><enclosure type="image/jpeg" url="javascript:bad()"/></item>
</channel></rss>''', uri);
    expect(feed.articles.single.id, 'image');
    expect(feed.articles.single.image,
        Uri.parse('https://feed.example/image.jpg'));
    expect(feed.articles.single.readingBody,
        contains('<img src="https://feed.example/image.jpg">'));
  });

  test('HTML cannot load executable content, local files or styled overlays',
      () {
    final feed = NewsFeed.parse('''<rss><channel><item><title>Title</title>
<description><![CDATA[<script>secret()</script><iframe src="https://other.example"></iframe><p style="position:fixed" onclick="bad()">Text &amp; more</p><a href="javascript:evil()">Bad</a><img src="file:///etc/passwd"><img src="/photo.jpg" alt="Photo"><a href="../post">Link</a>]]></description>
</item></channel></rss>''', uri);
    final body = feed.articles.single.body;
    for (final forbidden in [
      'script',
      'iframe',
      'style=',
      'onclick',
      'javascript:',
      'file:'
    ]) {
      expect(body, isNot(contains(forbidden)));
    }
    expect(body, contains('https://feed.example/photo.jpg'));
    expect(body, contains('https://feed.example/post'));
    expect(feed.articles.single.summary, contains('Text & more'));
  });

  test('HTML error pages and malformed XML are rejected; empty RSS is valid',
      () {
    expect(() => NewsFeed.parse('<html><body>Forbidden</body></html>', uri),
        throwsFormatException);
    expect(() => NewsFeed.parse('<rss>', uri), throwsA(isA<Exception>()));
    expect(
        NewsFeed.parse(
                '<rss><channel><title>Empty</title></channel></rss>', uri)
            .articles,
        isEmpty);
    expect(newsHttpUri('file:///etc/passwd'), isNull);
    expect(newsHttpUri('https://user:password@example.com'), isNull);
  });
}
