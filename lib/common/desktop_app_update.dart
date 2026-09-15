import 'dart:io';

import 'constant.dart';

enum _LinuxPackageFamily { deb, rpm, unknown }

class DesktopAppUpdater {
  Future<Uri?> downloadUri(Map<String, dynamic> release) async {
    final candidates = await _assetCandidates();
    if (candidates.isEmpty) return null;

    final rawAssets = release['assets'];
    if (rawAssets is! List) return null;

    final downloadUrls = <String, String>{};
    for (final rawAsset in rawAssets.whereType<Map>()) {
      final asset = Map<String, dynamic>.from(rawAsset);
      final name = asset['name'] as String?;
      final url = asset['browser_download_url'] as String?;
      if (name != null && url != null) {
        downloadUrls[name] = url;
      }
    }

    for (final candidate in candidates) {
      final uri = Uri.tryParse(downloadUrls[candidate] ?? '');
      if (uri != null && _isTrustedReleaseAsset(uri)) return uri;
    }
    return null;
  }

  Future<List<String>> _assetCandidates() async {
    final arch = await _architecture();
    if (arch == null) return const [];

    if (Platform.isWindows) {
      return ['GektusClashX-windows-$arch-setup.exe'];
    }
    if (Platform.isMacOS) {
      return ['GektusClashX-macos-$arch.dmg'];
    }
    if (!Platform.isLinux) return const [];

    if ((Platform.environment['APPIMAGE']?.isNotEmpty ?? false) &&
        arch == 'amd64') {
      return ['GektusClashX-linux-$arch.AppImage'];
    }

    return switch (await _linuxPackageFamily()) {
      _LinuxPackageFamily.deb => ['GektusClashX-linux-$arch.deb'],
      _LinuxPackageFamily.rpm => ['GektusClashX-linux-$arch.rpm'],
      _LinuxPackageFamily.unknown when arch == 'amd64' => [
          'GektusClashX-linux-$arch.AppImage'
        ],
      _ => const [],
    };
  }

  Future<String?> _architecture() async {
    if (Platform.isWindows) {
      final value = (Platform.environment['PROCESSOR_ARCHITEW6432'] ??
              Platform.environment['PROCESSOR_ARCHITECTURE'] ??
              '')
          .toLowerCase();
      if (value.contains('arm64')) return 'arm64';
      if (value.contains('amd64') || value.contains('x86_64')) return 'amd64';
      return null;
    }

    try {
      final result = await Process.run('uname', ['-m']);
      if (result.exitCode != 0) return null;
      return switch (result.stdout.toString().trim().toLowerCase()) {
        'arm64' || 'aarch64' => 'arm64',
        'amd64' || 'x86_64' => 'amd64',
        _ => null,
      };
    } catch (_) {
      return null;
    }
  }

  Future<_LinuxPackageFamily> _linuxPackageFamily() async {
    try {
      final osRelease = await File('/etc/os-release').readAsString();
      final identifiers = RegExp(
        r'^(?:ID|ID_LIKE)=(.*)$',
        multiLine: true,
      ).allMatches(osRelease).expand((match) {
        final value = match.group(1)?.replaceAll(RegExp(r'''["']'''), '') ?? '';
        return value.toLowerCase().split(RegExp(r'\s+'));
      }).toSet();

      const debianFamily = {
        'debian',
        'ubuntu',
        'linuxmint',
        'pop',
        'elementary',
        'zorin',
        'kali',
        'raspbian',
      };
      if (identifiers.any(debianFamily.contains)) {
        return _LinuxPackageFamily.deb;
      }

      const rpmFamily = {
        'fedora',
        'rhel',
        'centos',
        'rocky',
        'almalinux',
        'suse',
        'opensuse',
      };
      if (identifiers.any(rpmFamily.contains)) {
        return _LinuxPackageFamily.rpm;
      }
    } catch (_) {}
    return _LinuxPackageFamily.unknown;
  }

  bool _isTrustedReleaseAsset(Uri uri) {
    if (uri.scheme != 'https' || uri.host.toLowerCase() != 'github.com') {
      return false;
    }
    return uri.path.startsWith('/$repository/releases/download/');
  }
}

final desktopAppUpdater = DesktopAppUpdater();
