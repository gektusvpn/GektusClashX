import 'dart:io';

import 'package:gektusclashx/common/common.dart';

import 'startup_diagnostics.dart';

class SingleInstanceLock {
  factory SingleInstanceLock() {
    _instance ??= SingleInstanceLock._internal();
    return _instance!;
  }

  SingleInstanceLock._internal();
  static SingleInstanceLock? _instance;
  RandomAccessFile? _accessFile;

  Future<bool> acquire() async {
    startupLog('single-instance acquire begin');
    try {
      final lockFilePath = await appPath.lockFilePath;
      final lockFile = File(lockFilePath);
      await lockFile.create();
      _accessFile = await lockFile.open(mode: FileMode.write);
      await _accessFile?.lock();
      startupLog('single-instance acquired');
      return true;
    } catch (error, stack) {
      startupLog('single-instance refused: $error\n$stack');
      return false;
    }
  }
}

final singleInstanceLock = SingleInstanceLock();
