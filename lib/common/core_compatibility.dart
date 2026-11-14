import 'dart:convert';

import 'app_localizations.dart';
import 'print.dart';

const minCoreVersionHeader = 'gektusclashx-min-core-version';
const coreCompatibilityErrorPrefix = 'gektusclashx-core-compatibility:';
final _releasePattern = RegExp(
    r'^v?(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$',
    caseSensitive: false);
final _runningPattern = RegExp(
    r'^v?(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)(?:-([0-9A-Za-z.-]+))?(?:\+([0-9A-Za-z.-]+))?$',
    caseSensitive: false);

String? normalizeMinCoreVersion(String? value) {
  final text = value?.trim() ?? '';
  if (text.isEmpty) return null;
  final match = _releasePattern.firstMatch(text);
  if (match == null) {
    commonPrint.log('Ignoring invalid $minCoreVersionHeader');
    return null;
  }
  return '${match[1]}.${match[2]}.${match[3]}';
}

/// Null means that the running version cannot be identified.
bool? isCoreCompatible(String current, String minimum) {
  final live = _runningPattern.firstMatch(current.trim());
  final required = _releasePattern.firstMatch(minimum.trim());
  if (live == null || required == null) return null;
  for (var i = 1; i <= 3; i++) {
    final a = live[i]!;
    final b = required[i]!;
    final comparison =
        a.length != b.length ? a.length.compareTo(b.length) : a.compareTo(b);
    if (comparison != 0) return comparison > 0;
  }
  return live[4] == null;
}

String? coreCompatibilitySupportTarget(Map<String, String>? headers) {
  final url = headers?['support-url']?.trim();
  if (url != null && url.isNotEmpty) return url;
  final email = headers?['support-email']?.trim();
  if (email == null || email.isEmpty) return null;
  return email.toLowerCase().startsWith('mailto:')
      ? email
      : Uri(scheme: 'mailto', path: email).toString();
}

class CoreCompatibilityException implements Exception {
  const CoreCompatibilityException(
      {required this.minimum,
      required this.current,
      this.supportUrl,
      this.unknown = false});
  final String minimum;
  final String current;
  final String? supportUrl;
  final bool unknown;
  String get message => unknown
      ? appLocalizations.coreCompatibilityUnknown
      : appLocalizations.coreCompatibilityMessage;
  String get diagnostic => 'minimum=$minimum current=$current unknown=$unknown';
  @override
  String toString() => message;
}

CoreCompatibilityException? parseCoreCompatibilityError(String value) {
  if (!value.startsWith(coreCompatibilityErrorPrefix)) return null;
  try {
    final data =
        jsonDecode(value.substring(coreCompatibilityErrorPrefix.length))
            as Map<String, dynamic>;
    return CoreCompatibilityException(
        minimum: data['minimum'] as String,
        current: data['current'] as String,
        unknown: data['unknown'] == true);
  } catch (_) {
    return null;
  }
}

Future<void> ensureCoreCompatibility(
  String? requirement, {
  required Future<String> Function() readVersion,
  String? supportUrl,
}) async {
  final minimum = normalizeMinCoreVersion(requirement);
  if (minimum == null) return;
  String current;
  try {
    current = await readVersion().timeout(const Duration(seconds: 10));
  } catch (_) {
    current = '';
  }
  final compatible = isCoreCompatible(current, minimum);
  if (compatible ?? false) return;
  final error = CoreCompatibilityException(
      minimum: minimum,
      current: current,
      supportUrl: supportUrl,
      unknown: compatible == null);
  commonPrint.log('Core compatibility refusal: ${error.diagnostic}');
  throw error;
}

/// A response for a profile that was replaced during the version query must
/// neither apply configuration nor show a refusal for the new selection.
Future<bool> ensureSelectedCoreCompatibility(
  String? requirement, {
  required Future<String> Function() readVersion,
  required bool Function() isCurrent,
  String? supportUrl,
}) async {
  try {
    await ensureCoreCompatibility(requirement,
        readVersion: readVersion, supportUrl: supportUrl);
  } on CoreCompatibilityException {
    if (!isCurrent()) return false;
    rethrow;
  }
  return isCurrent();
}
