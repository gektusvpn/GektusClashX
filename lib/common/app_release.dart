import 'dart:io';

import 'package:dio/dio.dart';
import 'package:pub_semver/pub_semver.dart';

enum AppUpdateChannel { stable, testing }

/// Release versions use SemVer precedence, ignoring build metadata.
Version? parseAppVersion(String value) {
  final fullVersion = value.replaceFirst(RegExp(r'^v'), '');
  if (!RegExp(
          r'^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)(-[0-9A-Za-z-]+(\.[0-9A-Za-z-]+)*)?(\+[0-9A-Za-z-]+(\.[0-9A-Za-z-]+)*)?$')
      .hasMatch(fullVersion)) {
    return null;
  }
  final normalized = fullVersion.split('+').first;
  try {
    final version = Version.parse(normalized);
    // Numeric prerelease identifiers must not have leading zeroes.
    final pre = normalized.split('-').skip(1).join('-');
    if (pre.split('.').any((part) => RegExp(r'^0\d+$').hasMatch(part))) {
      return null;
    }
    return version;
  } on FormatException {
    return null;
  }
}

bool isAppRelease(Map<String, dynamic> release, AppUpdateChannel channel) {
  final tag = release['tag_name'];
  if (tag is! String || !tag.startsWith('v') || release['draft'] == true) {
    return false;
  }
  final version = parseAppVersion(tag);
  return version != null &&
      (channel == AppUpdateChannel.testing ||
          (!version.isPreRelease && release['prerelease'] != true));
}

/// Separate from core updates; the stable feed remains compatible with old apps.
class AppReleaseUpdates {
  AppReleaseUpdates(this.dio,
      {required this.repository, required this.githubUrl});

  final Dio dio;
  final String repository;
  final String Function(String) githubUrl;

  Future<Map<String, dynamic>?> check({
    required AppUpdateChannel channel,
    required String currentVersion,
  }) async {
    final current = parseAppVersion(currentVersion);
    if (current == null) return null;
    Map<String, dynamic>? latest;
    if (channel == AppUpdateChannel.stable) {
      latest = await _stable();
    } else {
      for (var page = 1;; page++) {
        final response = await dio.get<List<dynamic>>(
          'https://api.github.com/repos/$repository/releases',
          queryParameters: {'per_page': 100, 'page': page},
          options: Options(responseType: ResponseType.json),
        );
        if (response.statusCode != HttpStatus.ok || response.data == null) {
          throw StateError('Unable to read app releases');
        }
        for (final raw in response.data!.whereType<Map>()) {
          final release = Map<String, dynamic>.from(raw);
          if (!isAppRelease(release, channel)) continue;
          if (latest == null ||
              parseAppVersion(release['tag_name'])! >
                  parseAppVersion(latest['tag_name'])!) {
            latest = release;
          }
        }
        if (response.data!.length < 100) break;
      }
    }
    if (latest == null || parseAppVersion(latest['tag_name'])! <= current) {
      return null;
    }
    return latest;
  }

  Future<Map<String, dynamic>?> _stable() async {
    try {
      final response = await dio.get<Map<String, dynamic>>(
        githubUrl(
            'https://github.com/$repository/releases/latest/download/update.json'),
        options: Options(responseType: ResponseType.json),
      );
      if (response.statusCode == HttpStatus.ok &&
          response.data != null &&
          isAppRelease(response.data!, AppUpdateChannel.stable)) {
        return response.data;
      }
    } on DioException {
      // Missing, invalid, or unavailable manifests fall back to GitHub metadata.
    }
    final response = await dio.get<Map<String, dynamic>>(
      'https://api.github.com/repos/$repository/releases/latest',
      options: Options(responseType: ResponseType.json),
    );
    final release = response.data;
    return response.statusCode == HttpStatus.ok &&
            release != null &&
            isAppRelease(release, AppUpdateChannel.stable)
        ? release
        : null;
  }
}
