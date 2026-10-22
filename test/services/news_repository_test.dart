import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gektusclashx/services/news/repository.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../fixtures/news_feed.dart';

void main() {
  const fixture = sampleNewsFeed;
  final uri = Uri.parse('https://feed.example/news');
  group('repository', () {
    late Directory directory;
    setUp(() async =>
        directory = await Directory.systemTemp.createTemp('news-test-'));
    tearDown(() async => directory.delete(recursive: true));

    test(
        'deduplicates concurrent requests and reloads disk cache after restart',
        () async {
      var requests = 0;
      final pending = Completer<http.Response>();
      final repo = NewsFeedRepository(
          cacheDirectory: () async => directory,
          client: () => MockClient((request) {
                requests++;
                expect(request.headers.containsKey('authorization'), isFalse);
                return pending.future;
              }));
      final first = repo.load(uri.toString());
      final second = repo.load(uri.toString());
      pending.complete(http.Response(fixture, 200,
          headers: {'content-type': 'application/xml; charset=utf-8'}));
      await Future.wait([first, second]);
      expect(requests, 1);
      final restarted = NewsFeedRepository(
          cacheDirectory: () async => directory,
          client: () =>
              throw StateError('Fresh disk cache must avoid network'));
      expect((await restarted.load(uri.toString())).feed.articles.first.id,
          'post-2');
    });

    test(
        'restart publishes expired disk cache before awaiting a background refresh',
        () async {
      var now = DateTime.utc(2026, 10, 22);
      final original = NewsFeedRepository(
          cacheDirectory: () async => directory,
          now: () => now,
          client: () => MockClient(
              (_) async => http.Response.bytes(utf8.encode(fixture), 200)));
      await original.load(uri.toString());
      now = now.add(const Duration(hours: 1));
      final response = Completer<http.Response>();
      final restarted = NewsFeedRepository(
          cacheDirectory: () async => directory,
          now: () => now,
          client: () => MockClient((_) => response.future));
      final stream = StreamIterator(restarted.watch(uri.toString()));
      expect(await stream.moveNext(), isTrue);
      expect(stream.current.feed.articles.first.id, 'post-2');
      expect(stream.current.isRefreshing, isTrue);
      expect(response.isCompleted, isFalse);
      final updated = stream.moveNext();
      response.complete(http.Response.bytes(
          utf8.encode(fixture.replaceAll('post-2', 'new-post')), 200));
      expect(await updated, isTrue);
      expect(stream.current.feed.articles.first.id, 'new-post');
      expect(stream.current.isRefreshing, isFalse);
      expect(await stream.moveNext(), isFalse);
    });

    test(
        'offline watch retains the cached post after a failed background refresh',
        () async {
      final original = NewsFeedRepository(
          cacheDirectory: () async => directory,
          client: () => MockClient(
              (_) async => http.Response.bytes(utf8.encode(fixture), 200)));
      await original.load(uri.toString());
      final offline = NewsFeedRepository(
          cacheDirectory: () async => directory,
          client: () => MockClient((_) async => http.Response('Offline', 503)));
      final updates =
          await offline.watch(uri.toString(), refresh: true).toList();
      expect(updates, hasLength(2));
      expect(updates.first.isRefreshing, isTrue);
      expect(updates.last.isStale, isTrue);
      expect(updates.last.feed.articles.first.id, 'post-2');
    });

    test('network failures retain cached news and isolate different feed URLs',
        () async {
      var fail = false;
      var now = DateTime.utc(2026, 10, 22);
      final repo = NewsFeedRepository(
          cacheDirectory: () async => directory,
          now: () => now,
          client: () => MockClient((_) async => http.Response(
              fail ? 'Forbidden' : fixture, fail ? 403 : 200,
              headers: {'content-type': 'application/xml; charset=utf-8'})));
      await repo.load(uri.toString());
      fail = true;
      now = now.add(const Duration(minutes: 16));
      final cached = await repo.load(uri.toString());
      expect(cached.isStale, isTrue);
      expect(cached.feed.articles, hasLength(2));
      await expectLater(
          repo.load('https://other.example/feed'), throwsFormatException);
    });

    test('oversized streamed response fails without caching partial XML',
        () async {
      final repo = NewsFeedRepository(
          cacheDirectory: () async => directory,
          client: () => MockClient.streaming((_, __) async =>
              http.StreamedResponse(
                  Stream.value(
                      List.filled(NewsFeedRepository.maxBytes + 1, 65)),
                  200)));
      await expectLater(repo.load(uri.toString()), throwsFormatException);
      expect(await directory.list().isEmpty, isTrue);
    });

    test('refresh bypasses cache and replaces latest article', () async {
      var source = fixture;
      final repo = NewsFeedRepository(
          cacheDirectory: () async => directory,
          client: () => MockClient(
              (_) async => http.Response.bytes(utf8.encode(source), 200)));
      await repo.load(uri.toString());
      source = fixture.replaceAll('post-2', 'post-new');
      expect(
          (await repo.load(uri.toString())).feed.articles.first.id, 'post-2');
      expect(
          (await repo.load(uri.toString(), refresh: true))
              .feed
              .articles
              .first
              .id,
          'post-new');
    });
  });
}
