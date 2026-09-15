import 'dart:io';

import 'package:package_info_plus/package_info_plus.dart';

extension PackageInfoExtension on PackageInfo {
  /// Default User-Agent used when the profile sets no `global-ua`.
  String ua({required String appVersion, String? coreVersion}) {
    final normalizedAppVersion = appVersion.replaceFirst(RegExp(r'^[vV]'), '');
    return [
      "GektusClashX/v$normalizedAppVersion",
      if (coreVersion != null && coreVersion.isNotEmpty) "core/$coreVersion",
      "Platform/${Platform.operatingSystem}",
    ].join(" ");
  }
}
