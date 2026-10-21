import 'dart:convert';
import 'dart:io';

import 'package:shelf/shelf.dart' as shelf;

/// The phone-import HTTP boundary. Claim an import only after reading its body,
/// because multiple requests can be waiting for streamed bodies concurrently.
shelf.Handler createProfileImportHandler({
  required bool Function() isAvailable,
  required bool Function() isBusy,
  required void Function(String url) onReceive,
  void Function(Object error)? onInvalidRequest,
}) {
  shelf.Response response(int status, Map<String, Object> data) =>
      shelf.Response(
        status,
        body: jsonEncode(data),
        headers: {'content-type': 'application/json'},
      );

  shelf.Response? blocked() {
    if (!isAvailable()) return response(HttpStatus.gone, {'ok': false});
    if (isBusy()) {
      return response(HttpStatus.conflict, {'ok': false, 'status': 'busy'});
    }
    return null;
  }

  return (request) async {
    final beforeRead = blocked();
    if (beforeRead != null) return beforeRead;
    String? url;
    try {
      final payload = jsonDecode(await request.readAsString());
      if (payload is Map<String, dynamic> && payload['url'] is String) {
        url = (payload['url'] as String).trim();
      }
    } catch (error) {
      onInvalidRequest?.call(error);
    }
    final afterRead = blocked();
    if (afterRead != null) return afterRead;
    if (url == null || url.isEmpty) {
      return response(
          HttpStatus.badRequest, {'ok': false, 'error': 'invalid url'});
    }
    // The callback sets the busy state synchronously before starting async work.
    onReceive(url);
    return response(HttpStatus.ok, {'ok': true});
  };
}
