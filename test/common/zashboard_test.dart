import 'package:flutter_test/flutter_test.dart';
import 'package:gektusclashx/common/zashboard.dart';
import 'package:path/path.dart' as path;

void main() {
  test('keeps Zashboard archive entries inside the destination', () {
    final root = path.join(path.separator, 'tmp', 'zashboard');

    expect(
      safeZashboardArchivePath(root, 'assets/app.js'),
      path.join(root, 'assets', 'app.js'),
    );
    expect(safeZashboardArchivePath(root, '../config.yaml'), isNull);
    expect(safeZashboardArchivePath(root, '/etc/passwd'), isNull);
    expect(safeZashboardArchivePath(root, r'..\config.yaml'), isNull);
  });
}
