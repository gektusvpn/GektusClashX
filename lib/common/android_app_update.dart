import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:path/path.dart' as path;

import 'constant.dart';
import 'path.dart';
import 'request.dart';

enum AndroidAppUpdateError {
  assetNotFound,
  checksumNotFound,
  checksumMismatch,
  cancelled,
  downloadFailed,
}

class AndroidAppUpdateException implements Exception {
  const AndroidAppUpdateException(this.code, [this.cause]);

  final AndroidAppUpdateError code;
  final Object? cause;

  @override
  String toString() => cause == null ? code.name : '${code.name}: $cause';
}

class AndroidReleaseAsset {
  const AndroidReleaseAsset({
    required this.name,
    required this.downloadUrl,
    this.digest,
  });

  factory AndroidReleaseAsset.fromJson(Map<String, dynamic> json) =>
      AndroidReleaseAsset(
        name: json['name'] as String? ?? '',
        downloadUrl: json['browser_download_url'] as String? ?? '',
        digest: json['digest'] as String?,
      );

  final String name;
  final String downloadUrl;
  final String? digest;
}

class AndroidAppUpdater {
  static const _assetName = 'GektusClashX-android-universal.apk';
  static final _sha256Pattern = RegExp(r'^[0-9a-fA-F]{64}$');
  static final _digestPattern = RegExp(r'^sha256:([0-9a-fA-F]{64})$');

  Future<File> download(
    Map<String, dynamic> release, {
    required void Function(int received, int total) onProgress,
    CancelToken? cancelToken,
  }) async {
    final assets = _parseAssets(release['assets']);
    final asset = assets.where((asset) => asset.name == _assetName).firstOrNull;
    if (asset == null) {
      throw const AndroidAppUpdateException(
        AndroidAppUpdateError.assetNotFound,
      );
    }

    final String? expectedHash;
    try {
      expectedHash = await _getExpectedHash(asset, assets);
    } on DioException catch (error) {
      throw AndroidAppUpdateException(
        AndroidAppUpdateError.downloadFailed,
        error,
      );
    }
    if (expectedHash == null) {
      throw const AndroidAppUpdateException(
        AndroidAppUpdateError.checksumNotFound,
      );
    }

    final updateDirectory = Directory(
      path.join(await appPath.homeDirPath, 'updates'),
    );
    await updateDirectory.create(recursive: true);
    final target = File(path.join(updateDirectory.path, asset.name));
    final partial = File('${target.path}.part');

    try {
      if (partial.existsSync()) {
        partial.deleteSync();
      }
      await request.downloadFile(
        asset.downloadUrl,
        partial.path,
        cancelToken: cancelToken,
        onProgress: onProgress,
      );

      final actualHash =
          (await sha256.bind(partial.openRead()).first).toString();
      if (actualHash.toLowerCase() != expectedHash) {
        throw const AndroidAppUpdateException(
          AndroidAppUpdateError.checksumMismatch,
        );
      }

      if (target.existsSync()) {
        target.deleteSync();
      }
      return partial.rename(target.path);
    } on DioException catch (error) {
      if (CancelToken.isCancel(error)) {
        throw const AndroidAppUpdateException(
          AndroidAppUpdateError.cancelled,
        );
      }
      throw AndroidAppUpdateException(
        AndroidAppUpdateError.downloadFailed,
        error,
      );
    } on AndroidAppUpdateException {
      rethrow;
    } catch (error) {
      throw AndroidAppUpdateException(
        AndroidAppUpdateError.downloadFailed,
        error,
      );
    } finally {
      if (partial.existsSync()) {
        partial.deleteSync();
      }
    }
  }

  List<AndroidReleaseAsset> _parseAssets(Object? rawAssets) {
    if (rawAssets is! List) return const [];
    return rawAssets
        .whereType<Map>()
        .map((asset) => AndroidReleaseAsset.fromJson(
              Map<String, dynamic>.from(asset),
            ))
        .where(
          (asset) =>
              asset.name.isNotEmpty &&
              _isTrustedReleaseAsset(asset.downloadUrl),
        )
        .toList();
  }

  bool _isTrustedReleaseAsset(String value) {
    final uri = Uri.tryParse(value);
    return uri != null &&
        uri.scheme == 'https' &&
        uri.host.toLowerCase() == 'github.com' &&
        uri.path.startsWith('/$repository/releases/download/');
  }

  Future<String?> _getExpectedHash(
    AndroidReleaseAsset asset,
    List<AndroidReleaseAsset> assets,
  ) async {
    final digestMatch = _digestPattern.firstMatch(asset.digest?.trim() ?? '');
    if (digestMatch != null) {
      return digestMatch.group(1)!.toLowerCase();
    }

    final checksumName = '${asset.name}.sha256';
    final checksumAsset =
        assets.where((candidate) => candidate.name == checksumName).firstOrNull;
    if (checksumAsset == null) return null;

    final body = await request.getDirectText(checksumAsset.downloadUrl);
    final hash = body.trim().split(RegExp(r'\s+')).firstOrNull?.toLowerCase();
    return hash != null && _sha256Pattern.hasMatch(hash) ? hash : null;
  }
}

final androidAppUpdater = AndroidAppUpdater();
