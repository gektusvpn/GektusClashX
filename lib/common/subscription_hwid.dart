import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:gektusclashx/common/app_localizations.dart';

/// A provider refusal, rather than a network outage or an invalid config.
class SubscriptionDeviceLimitException implements Exception {
  SubscriptionDeviceLimitException({this.announce, this.supportUrl});

  final String? announce;
  final String? supportUrl;

  String get message {
    final value = announce?.trim() ?? '';
    if (value.isNotEmpty) {
      final encoded = value.startsWith('base64:') ? value.substring(7) : value;
      try {
        final decoded = utf8.decode(base64.decode(base64.normalize(encoded)));
        if (decoded.trim().isNotEmpty) return decoded;
      } on FormatException {
        return value;
      }
    }
    return appLocalizations.hwidDeviceLimitMessage;
  }

  @override
  String toString() => message;
}

/// Check headers even when Dio rejects an HTTP error status. Never parse or
/// save the refusal body as a subscription configuration.
Future<Response<T>> fetchSubscriptionResponse<T>(
    Future<Response<T>> Function() fetch) async {
  void check(Headers? headers) {
    if (headers?.value('x-hwid-max-devices-reached')?.trim().toLowerCase() ==
        'true') {
      throw SubscriptionDeviceLimitException(
        announce: headers!.value('announce'),
        supportUrl: headers.value('support-url')?.trim(),
      );
    }
  }

  try {
    final response = await fetch();
    check(response.headers);
    return response;
  } on DioException catch (error) {
    check(error.response?.headers);
    rethrow;
  }
}
