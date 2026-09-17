import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter/cupertino.dart';
import 'package:gektusclashx/common/common.dart';
import 'package:gektusclashx/models/models.dart';
import 'package:gektusclashx/state.dart';

class Request {
  Request() {
    _dio = Dio(
      BaseOptions(
        headers: {
          "User-Agent": browserUa,
        },
        // Without these a profile/subscription fetch over a half-dead uplink
        // (mobile network, doze-restricted background) hangs forever: the card
        // spins indefinitely and the auto-update chain stalls until app restart.
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 60),
      ),
    );
    _clashDio = Dio(
      BaseOptions(
        // Only cap connection setup globally so a dead/blackholed exit node fails
        // fast instead of hanging the IP check. Receive time is left unbounded
        // here (large proxied downloads use this same client) and capped
        // per-request in checkIp instead.
        connectTimeout: const Duration(seconds: 5),
      ),
    );
    _clashDio.httpClientAdapter = IOHttpClientAdapter(createHttpClient: () {
      final client = HttpClient();
      client.findProxy = (uri) {
        client.userAgent = globalState.ua;
        return FlClashHttpOverrides.handleFindProxy(uri);
      };
      return client;
    });
  }
  late final Dio _dio;
  late final Dio _clashDio;
  String? userAgent;

  Future<Response<Uint8List>> getFileResponseForUrl(
    String rawUrl, {
    Map<String, dynamic>? headers,
    String? githubProxyBase,
  }) async {
    final normalizedUrl = rawUrl.normalizeUrlCredentials;
    final url = githubProxyBase == null
        ? globalState.githubUrl(normalizedUrl)
        : githubProxyUrlWithBase(normalizedUrl, githubProxyBase);
    final requestHeaders = headers ?? {};
    requestHeaders['User-Agent'] = globalState.ua;

    final dio = _dio;

    final firstResponse = await dio.get<Uint8List>(
      url,
      options: Options(
        responseType: ResponseType.bytes,
        headers: requestHeaders,
        followRedirects: false,
        validateStatus: (status) => status != null && status < 400,
      ),
    );

    if (firstResponse.isRedirect) {
      final newUrl = firstResponse.headers.value('location');
      if (newUrl == null) {
        throw Exception('Redirect detected, but no location header was found.');
      }

      commonPrint.log('HTTP redirect received');
      final finalResponse = await dio.get<Uint8List>(
        newUrl,
        options: Options(
          responseType: ResponseType.bytes,
          headers: requestHeaders,
          followRedirects: true,
          maxRedirects: 5,
          validateStatus: (status) => status != null && status < 400,
        ),
      );
      return finalResponse;
    }
    return firstResponse;
  }

  Future<Response> getTextResponseForUrl(String url) async {
    final response = await _clashDio.get(
      globalState.githubUrl(url),
      options: Options(
        responseType: ResponseType.plain,
      ),
    );
    return response;
  }

  Future<MemoryImage?> getImage(String url) async {
    if (url.isEmpty) return null;
    final response = await _dio.get<Uint8List>(
      globalState.githubUrl(url),
      options: Options(
        responseType: ResponseType.bytes,
      ),
    );
    final data = response.data;
    if (data == null) return null;
    return MemoryImage(data);
  }

  Future<String> getDirectText(String url) async {
    final response = await _dio.get<String>(
      globalState.githubUrl(url),
      options: Options(responseType: ResponseType.plain),
    );
    return response.data ?? '';
  }

  Future<void> downloadFile(
    String url,
    String targetPath, {
    int? expectedSize,
    CancelToken? cancelToken,
    void Function(int received, int total)? onProgress,
  }) async {
    final preferredUrl = globalState.githubUrl(url);
    await ResumableDownloader(_dio).download(
      urls: [preferredUrl, url],
      targetPath: targetPath,
      expectedSize: expectedSize,
      cancelToken: cancelToken,
      onProgress: onProgress ?? (_, __) {},
      onAttemptError: (attempt, sourceIndex, error) {
        final source = sourceIndex == 0 && preferredUrl != url
            ? 'configured GitHub proxy'
            : 'direct GitHub';
        commonPrint.log(
          'APK download attempt $attempt via $source failed: '
          '${error.type.name}, status ${error.response?.statusCode ?? '-'}',
        );
      },
    );
  }

  Future<Map<String, dynamic>?> checkForUpdate() async {
    final data = await _getLatestRelease();
    if (data == null) return null;
    final remoteVersion = data['tag_name'] as String?;
    if (remoteVersion == null || remoteVersion.isEmpty) return null;
    final version = globalState.packageInfo.version;
    final normalizedVersion = remoteVersion.replaceFirst(RegExp(r'^v'), '');
    final hasUpdate = utils.compareVersions(normalizedVersion, version) > 0;
    if (!hasUpdate) return null;
    return data;
  }

  Future<Map<String, dynamic>?> _getLatestRelease() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        globalState.githubUrl(
          "https://github.com/$repository/releases/latest/download/update.json",
        ),
        options: Options(responseType: ResponseType.json),
      );
      if (response.statusCode == HttpStatus.ok && response.data != null) {
        return response.data;
      }
    } on DioException catch (error) {
      commonPrint
          .log('Update manifest unavailable: ${error.response?.statusCode}');
    }

    final response = await _dio.get<Map<String, dynamic>>(
      "https://api.github.com/repos/$repository/releases/latest",
      options: Options(responseType: ResponseType.json),
    );
    return response.statusCode == HttpStatus.ok ? response.data : null;
  }

  Future<Map<String, dynamic>?> checkForCoreUpdate(
      String currentCoreVersion) async {
    final response = await _dio.get(
      "https://api.github.com/repos/$repository/releases",
      options: Options(responseType: ResponseType.json),
      queryParameters: {'per_page': 20},
    );
    if (response.statusCode != 200) return null;
    final current = currentCoreVersion.replaceAll(RegExp(r'^v'), '');
    final releases = response.data as List<dynamic>;
    for (final release in releases) {
      final tag = release['tag_name'] as String? ?? '';
      if (!tag.startsWith('core-')) continue;
      final remote =
          tag.replaceFirst('core-', '').replaceAll(RegExp(r'^v'), '');
      // Strictly newer only: a locally built core can be ahead of the newest
      // core-* release, and offering it back would be a silent downgrade.
      if (utils.compareVersions(remote, current) <= 0) return null;
      return release as Map<String, dynamic>;
    }
    return null;
  }

  Future<CoreUpdateDownloadError?> downloadCoreUpdate(
    String downloadUrl,
    String targetPath, {
    required String? expectedDigest,
    void Function(int received, int total)? onProgress,
  }) async {
    final digestMatch = RegExp(r'^sha256:([0-9a-fA-F]{64})$')
        .firstMatch(expectedDigest?.trim() ?? '');
    if (digestMatch == null) {
      return CoreUpdateDownloadError.verificationFailed;
    }

    final tmpFile = File('$targetPath.tmp');
    try {
      await _dio.download(
        globalState.githubUrl(downloadUrl),
        tmpFile.path,
        onReceiveProgress: onProgress,
      );
      if (!await tmpFile.exists()) {
        return CoreUpdateDownloadError.downloadFailed;
      }
      final actualDigest = (await sha256.bind(tmpFile.openRead()).first)
          .toString()
          .toLowerCase();
      if (actualDigest != digestMatch.group(1)!.toLowerCase()) {
        return CoreUpdateDownloadError.verificationFailed;
      }
      final target = File(targetPath);
      if (await target.exists()) await target.delete();
      await tmpFile.rename(targetPath);
      return null;
    } catch (_) {
      return CoreUpdateDownloadError.downloadFailed;
    } finally {
      try {
        if (await tmpFile.exists()) {
          await tmpFile.delete();
        }
      } catch (_) {}
    }
  }

  // Tried in order, first success wins. All return a dead-simple JSON with an
  // IPv4 exit IP + country code:
  //   ip.sb     — `api-ipv4` host is A-only, so the exit is forced over IPv4
  //   ip-api.com — IPv4-only on the free tier
  //   ipinfo.io — plain {ip, country}, used as a last-resort fallback
  final Map<String, IpInfo Function(Map<String, dynamic>)> _ipInfoSources = {
    "https://api-ipv4.ip.sb/geoip": IpInfo.fromIpSbJson,
    "http://ip-api.com/json/?fields=status,countryCode,query":
        IpInfo.fromIpApiComJson,
    "https://ipinfo.io/json": IpInfo.fromIpInfoIoJson,
  };

  /// Resolve the exit IP by trying each source **sequentially**, stopping at the
  /// first success. A healthy primary therefore means exactly one request — not
  /// a parallel race that fires every source through the tunnel at once. Each
  /// source is bounded by a short receive timeout (plus the client-wide connect
  /// timeout) so a slow/dead node falls through to the next instead of hanging.
  Future<Result<IpInfo?>> checkIp({CancelToken? cancelToken}) async {
    for (final source in _ipInfoSources.entries) {
      if (cancelToken?.isCancelled ?? false) {
        return Result.error("cancelled");
      }
      try {
        final res = await _clashDio.get<Map<String, dynamic>>(
          source.key,
          cancelToken: cancelToken,
          options: Options(
            responseType: ResponseType.json,
            receiveTimeout: const Duration(seconds: 3),
          ),
        );
        if (res.statusCode == HttpStatus.ok && res.data != null) {
          return Result.success(source.value(res.data!));
        }
      } on DioException catch (e) {
        if (e.type == DioExceptionType.cancel) {
          return Result.error("cancelled");
        }
        // connect/receive timeout or bad status — fall through to the next source
      } catch (_) {
        // unexpected shape / parse failure — try the next source
      }
    }
    // Every source failed (offline, all timed out, or unparseable).
    return Result.success(null);
  }

  Future<bool> pingHelper() async {
    try {
      final response = await _dio
          .get(
            "http://$localhost:$helperPort/ping",
            options: Options(
              responseType: ResponseType.plain,
            ),
          )
          .timeout(
            const Duration(
              milliseconds: 2000,
            ),
          );
      if (response.statusCode != HttpStatus.ok) {
        return false;
      }
      // Compare against the binary actually on disk, not the build-time
      // constant — a separately updated core is otherwise reported as a
      // helper mismatch forever.
      final diskHash = await coreUpdater.calcCoreSha256();
      return diskHash != null && (response.data as String) == diskHash;
    } catch (_) {
      return false;
    }
  }

  Future<bool> startCoreByHelper(String arg) async {
    try {
      final homeDirPath = await appPath.homeDirPath;
      final response = await _dio
          .post(
            "http://$localhost:$helperPort/start",
            data: json.encode({
              "path": appPath.corePath,
              "arg": arg,
              "home_dir": homeDirPath,
            }),
            options: Options(
              responseType: ResponseType.plain,
            ),
          )
          .timeout(
            const Duration(
              milliseconds: 2000,
            ),
          );
      if (response.statusCode != HttpStatus.ok) {
        return false;
      }
      final data = response.data as String;
      return data.isEmpty;
    } catch (_) {
      return false;
    }
  }

  /// Ask the SYSTEM helper to swap in the pending core update. Needed for
  /// per-machine installs (Program Files) where the unelevated app can't
  /// overwrite the binary itself. The helper stops the core, moves the file and
  /// refreshes the allow-list hash. Returns true only if it reports success.
  Future<bool> replaceCoreByHelper(
      String pendingPath, String targetPath) async {
    try {
      final response = await _dio
          .post(
            "http://$localhost:$helperPort/replace_core",
            data: json.encode({
              "pending": pendingPath,
              "target": targetPath,
            }),
            options: Options(responseType: ResponseType.plain),
          )
          .timeout(const Duration(milliseconds: 10000));
      if (response.statusCode != HttpStatus.ok) return false;
      final data = response.data as String;
      if (data.isNotEmpty) {
        commonPrint.log("replaceCoreByHelper: $data");
        return false;
      }
      return true;
    } catch (e) {
      commonPrint.log("replaceCoreByHelper error: $e");
      return false;
    }
  }

  Future<bool> stopCoreByHelper() async {
    try {
      final response = await _dio
          .post(
            "http://$localhost:$helperPort/stop",
            options: Options(responseType: ResponseType.plain),
          )
          .timeout(const Duration(milliseconds: 2000));

      if (response.statusCode != HttpStatus.ok) return false;
      final data = response.data as String;
      return data.isEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<Map<String, dynamic>?> getCoreVersion() async {
    try {
      final addr = globalState.effectiveExternalController.value;
      if (addr.isEmpty) return null;
      final response = await _dio
          .get<Map<String, dynamic>>(
            "http://$addr/version",
            options: Options(
              responseType: ResponseType.json,
            ),
          )
          .timeout(const Duration(seconds: 2));

      if (response.statusCode != HttpStatus.ok) return null;
      return response.data;
    } catch (_) {
      return null;
    }
  }
}

enum CoreUpdateDownloadError {
  verificationFailed,
  downloadFailed,
}

final request = Request();
