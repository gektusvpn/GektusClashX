import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'file_logger.dart';

final _startupClock = Stopwatch()..start();
void startupLog(String message) {
  if (!Platform.isWindows) return;
  final line =
      '[startup pid=$pid +${_startupClock.elapsedMilliseconds}ms] $message';
  debugPrint(line);
  fileLogger.log(line);
}

Future<T> startupStage<T>(String name, Future<T> Function() action) async {
  if (!Platform.isWindows) return action();
  startupLog('$name begin');
  final timer = Timer.periodic(
      const Duration(seconds: 10), (_) => startupLog('$name still waiting'));
  try {
    final result = await action();
    startupLog('$name complete');
    return result;
  } catch (error, stack) {
    startupLog('$name failed: $error\n$stack');
    rethrow;
  } finally {
    timer.cancel();
  }
}

final windowsStartupReady = ValueNotifier(false);
final windowsStartupError = ValueNotifier<String?>(null);
