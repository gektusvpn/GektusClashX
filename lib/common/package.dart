import 'dart:io';

import 'package:package_info_plus/package_info_plus.dart';

extension PackageInfoExtension on PackageInfo {
  /// Default User-Agent used when the profile sets no `global-ua`.
  String ua({required String appVersion, String? coreVersion}) {
    final normalizedAppVersion = appVersion.replaceFirst(RegExp(r'^[vV]'), '');
    final version = coreVersion?.replaceFirst(RegExp(r'^v'), '');
    final mihomoUserAgent = version == null || version.isEmpty
        ? "clash.meta"
        : "clash.meta/$version";
    return [
      mihomoUserAgent,
      "GektusClashX/v$normalizedAppVersion",
      "Platform/${Platform.operatingSystem}",
    ].join(" ");
  }
}
