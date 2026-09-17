import 'dart:io';

import 'package:dio/dio.dart';

typedef DownloadAttemptError = void Function(
  int attempt,
  int sourceIndex,
  DioException error,
);

/// Downloads a file in resumable chunks and keeps the partial file when a
/// transient network error occurs.
class ResumableDownloader {
  ResumableDownloader(
    this._dio, {
    this.maxAttempts = 4,
    this.retryDelay = const Duration(seconds: 1),
  });

  final Dio _dio;
  final int maxAttempts;
  final Duration retryDelay;

  Future<void> download({
    required List<String> urls,
    required String targetPath,
    required void Function(int received, int total) onProgress,
    int? expectedSize,
    CancelToken? cancelToken,
    DownloadAttemptError? onAttemptError,
  }) async {
    final sources = <String>[];
    for (final url in urls) {
      if (url.isNotEmpty && !sources.contains(url)) sources.add(url);
    }
    if (sources.isEmpty) {
      throw ArgumentError.value(urls, 'urls', 'At least one URL is required.');
    }

    final file = File(targetPath);
    if (await file.exists() &&
        expectedSize != null &&
        await file.length() > expectedSize) {
      await file.delete();
    }

    DioException? lastError;
    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      _throwIfCancelled(cancelToken);
      final sourceIndex = attempt % sources.length;
      try {
        await _downloadAttempt(
          url: sources[sourceIndex],
          file: file,
          expectedSize: expectedSize,
          cancelToken: cancelToken,
          onProgress: onProgress,
        );
        return;
      } on DioException catch (error) {
        if (CancelToken.isCancel(error)) rethrow;
        lastError = error;
        onAttemptError?.call(attempt + 1, sourceIndex, error);
      }

      if (attempt + 1 < maxAttempts) {
        await Future<void>.delayed(retryDelay * (attempt + 1));
      }
    }

    throw lastError ??
        DioException.connectionError(
          requestOptions: RequestOptions(path: sources.first),
          reason: 'Download failed without a response.',
        );
  }

  Future<void> _downloadAttempt({
    required String url,
    required File file,
    required int? expectedSize,
    required CancelToken? cancelToken,
    required void Function(int received, int total) onProgress,
  }) async {
    var resumeOffset = await file.exists() ? await file.length() : 0;
    if (expectedSize != null && resumeOffset == expectedSize) {
      onProgress(expectedSize, expectedSize);
      return;
    }

    final headers = <String, dynamic>{
      HttpHeaders.acceptEncodingHeader: 'identity',
      if (resumeOffset > 0) HttpHeaders.rangeHeader: 'bytes=$resumeOffset-',
    };

    await _dio.download(
      url,
      (responseHeaders) {
        if (resumeOffset > 0 &&
            !_rangeStartsAt(
              responseHeaders.value(HttpHeaders.contentRangeHeader),
              resumeOffset,
            )) {
          // Some GitHub proxies ignore Range and return HTTP 200. Replace the
          // partial file in that case instead of appending a second full APK.
          if (file.existsSync()) file.deleteSync();
          resumeOffset = 0;
        }
        return file.path;
      },
      cancelToken: cancelToken,
      deleteOnError: false,
      fileAccessMode: FileAccessMode.append,
      options: Options(
        headers: headers,
        followRedirects: true,
        maxRedirects: 5,
        // This is an inactivity timeout, not a limit for the whole APK.
        receiveTimeout: const Duration(minutes: 2),
      ),
      onReceiveProgress: (received, total) {
        final completeReceived = resumeOffset + received;
        final completeTotal =
            expectedSize ?? (total > 0 ? resumeOffset + total : total);
        onProgress(completeReceived, completeTotal);
      },
    );
  }

  bool _rangeStartsAt(String? contentRange, int expectedStart) {
    if (contentRange == null) return false;
    final match = RegExp(r'^bytes\s+(\d+)-\d+/(?:\d+|\*)$')
        .firstMatch(contentRange.trim().toLowerCase());
    return match != null && int.tryParse(match.group(1)!) == expectedStart;
  }

  void _throwIfCancelled(CancelToken? cancelToken) {
    final error = cancelToken?.cancelError;
    if (error != null) throw error;
  }
}
