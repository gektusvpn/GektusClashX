import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import 'feed.dart';

class NewsFeedResult {
  const NewsFeedResult(this.feed,
      {this.isStale = false, this.isRefreshing = false});
  final NewsFeed feed;
  final bool isStale;
  final bool isRefreshing;
}

class _CachedFeed {
  const _CachedFeed(this.source, this.fetchedAt, this.feed);
  final String source;
  final DateTime fetchedAt;
  final NewsFeed feed;
}

class NewsFeedRepository {
  NewsFeedRepository(
      {http.Client Function()? client,
      Future<Directory> Function()? cacheDirectory,
      DateTime Function()? now})
      : _client = client ?? http.Client.new,
        _cacheDirectory = cacheDirectory ?? getApplicationCacheDirectory,
        _now = now ?? DateTime.now;

  static const maxBytes = 2 * 1024 * 1024;
  static const cacheLifetime = Duration(minutes: 15);
  final http.Client Function() _client;
  final Future<Directory> Function() _cacheDirectory;
  final DateTime Function() _now;
  final _memory = <String, _CachedFeed>{};
  final _inFlight = <String, Future<NewsFeedResult>>{};

  /// Publish the persistent cache before waiting for a potentially slow network.
  Stream<NewsFeedResult> watch(String url, {bool refresh = false}) async* {
    final uri = newsHttpUri(url);
    if (uri == null) throw const FormatException('Invalid news feed URL');
    final cached = await _readCache(url, uri);
    final age = cached == null ? null : _now().difference(cached.fetchedAt);
    final needsUpdate =
        refresh || age == null || age.isNegative || age >= cacheLifetime;
    if (cached != null) {
      yield NewsFeedResult(cached.feed, isRefreshing: needsUpdate);
    }
    if (needsUpdate) yield await load(url, refresh: true);
  }

  void _remember(String url, _CachedFeed entry) {
    if (_memory.length >= 8 && !_memory.containsKey(url)) {
      _memory.remove(_memory.keys.first);
    }
    _memory[url] = entry;
  }

  Future<NewsFeedResult> load(String url, {bool refresh = false}) =>
      _inFlight.putIfAbsent(
          url,
          () => _load(url, refresh).whenComplete(() {
                unawaited(_inFlight.remove(url));
              }));

  Future<File> _file(String url) async => File(
      '${(await _cacheDirectory()).path}/news/${sha256.convert(utf8.encode(url))}.json');

  Future<_CachedFeed?> _readCache(String url, Uri uri) async {
    if (_memory.containsKey(url)) return _memory[url];
    try {
      final file = await _file(url);
      // Keep filesystem metadata checks off the UI thread.
      // ignore: avoid_slow_async_io
      if (!await file.exists() || await file.length() > maxBytes * 3) {
        return null;
      }
      final data =
          jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      final source = data['source'] as String;
      if (utf8.encode(source).length > maxBytes) return null;
      final entry = _CachedFeed(
          source,
          DateTime.parse(data['fetchedAt'] as String),
          NewsFeed.parse(source, uri));
      _remember(url, entry);
      return entry;
    } catch (_) {
      return null;
    }
  }

  Future<NewsFeedResult> _load(String url, bool refresh) async {
    final uri = newsHttpUri(url);
    if (uri == null) throw const FormatException('Invalid news feed URL');
    final cached = await _readCache(url, uri);
    final age = cached == null ? null : _now().difference(cached.fetchedAt);
    if (!refresh && age != null && !age.isNegative && age < cacheLifetime) {
      return NewsFeedResult(cached!.feed);
    }
    final client = _client();
    try {
      final request = http.Request('GET', uri)
        ..headers.addAll({
          'Accept':
              'application/rss+xml, application/atom+xml, application/feed+json, application/json, application/xml, text/xml',
          'User-Agent': 'GektusClashX News',
        });
      final response =
          await client.send(request).timeout(const Duration(seconds: 15));
      if (response.statusCode != 200 ||
          (response.contentLength ?? 0) > maxBytes) {
        throw const FormatException('News feed unavailable');
      }
      final bytes = <int>[];
      await for (final chunk
          in response.stream.timeout(const Duration(seconds: 15))) {
        if (bytes.length + chunk.length > maxBytes) {
          throw const FormatException('News feed too large');
        }
        bytes.addAll(chunk);
      }
      final source = utf8.decode(bytes);
      final feed = NewsFeed.parse(source, uri);
      final entry = _CachedFeed(source, _now(), feed);
      _remember(url, entry);
      try {
        final file = await _file(url);
        await file.parent.create(recursive: true);
        await file.writeAsString(
            jsonEncode({
              'source': source,
              'fetchedAt': entry.fetchedAt.toIso8601String(),
            }),
            flush: true);
      } catch (_) {/* News remain usable when disk caching is unavailable. */}
      return NewsFeedResult(feed);
    } catch (_) {
      if (cached != null) return NewsFeedResult(cached.feed, isStale: true);
      rethrow;
    } finally {
      client.close();
    }
  }
}

final newsRepositoryProvider = Provider((ref) => NewsFeedRepository());
final _newsRefreshProvider =
    StateProvider.autoDispose.family<int, String>((ref, url) => 0);
final newsFeedProvider =
    StreamProvider.autoDispose.family<NewsFeedResult, String>(
  (ref, url) {
    final timer = Timer.periodic(
        NewsFeedRepository.cacheLifetime, (_) => ref.invalidateSelf());
    ref.onDispose(timer.cancel);
    return ref
        .watch(newsRepositoryProvider)
        .watch(url, refresh: ref.watch(_newsRefreshProvider(url)) > 0);
  },
);

void refreshNews(WidgetRef ref, String url) {
  ref.read(_newsRefreshProvider(url).notifier).state++;
}
