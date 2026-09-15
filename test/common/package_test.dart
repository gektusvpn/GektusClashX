import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gektusclashx/common/package.dart';
import 'package:package_info_plus/package_info_plus.dart';

void main() {
  test('builds a stable GektusClashX User-Agent', () {
    final packageInfo = PackageInfo(
      appName: 'GektusClashX',
      packageName: 'com.gektus.clashx',
      version: '0.4.2',
      buildNumber: '1',
    );
    final expected =
        'clash.meta/1.19.30 GektusClashX/v0.4.2 Platform/${Platform.operatingSystem}';

    expect(
      packageInfo.ua(appVersion: '0.4.2', coreVersion: 'v1.19.30'),
      expected,
    );
    expect(
      packageInfo.ua(appVersion: 'v0.4.2', coreVersion: 'v1.19.30'),
      expected,
    );
  });
}
