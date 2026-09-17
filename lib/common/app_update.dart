import 'dart:io';

import 'package:flutter/foundation.dart';

enum AppUpdatePhase {
  available,
  downloading,
  readyToInstall,
  installing,
  failed,
}

enum AppUpdateFailure {
  assetNotFound,
  verificationFailed,
  downloadFailed,
  invalidPackage,
  permissionDenied,
  installerUnavailable,
}

@immutable
class AppUpdateState {
  const AppUpdateState({
    required this.release,
    required this.phase,
    this.downloadUri,
    this.progress,
    this.apk,
    this.failure,
  });

  factory AppUpdateState.available(
    Map<String, dynamic> release, {
    Uri? downloadUri,
  }) =>
      AppUpdateState(
        release: Map.unmodifiable(release),
        phase: AppUpdatePhase.available,
        downloadUri: downloadUri,
      );

  final Map<String, dynamic> release;
  final AppUpdatePhase phase;
  final Uri? downloadUri;
  final double? progress;
  final File? apk;
  final AppUpdateFailure? failure;

  String get version => release['tag_name'] as String? ?? '';
}
