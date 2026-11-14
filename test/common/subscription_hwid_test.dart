import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gektusclashx/common/subscription_fallback.dart';
import 'package:gektusclashx/common/subscription_hwid.dart';
import 'package:gektusclashx/l10n/l10n.dart';

void main() {
  setUpAll(() async => AppLocalizations.load(const Locale('en')));

  test('announce is the entire message, plain or base64 encoded', () {
    const message = 'Доступно только пять устройств. Обратитесь в поддержку.';
    for (final value in [
      message,
      base64.encode(utf8.encode(message)),
      'base64:${base64.encode(utf8.encode(message))}'
    ]) {
      expect(
          SubscriptionDeviceLimitException(announce: value).message, message);
    }
  });

  test('missing or empty announce uses the default explanation', () {
    for (final value in [null, '', '  ', 'base64:', 'base64:IA==']) {
      expect(SubscriptionDeviceLimitException(announce: value).message,
          AppLocalizations.current.hwidDeviceLimitMessage);
    }
  });

  for (final status in [200, 403, 404, 500]) {
    test('recognizes the HWID refusal before config processing (HTTP $status)',
        () async {
      final response = Response<String>(
        requestOptions:
            RequestOptions(path: 'https://example.com/subscription'),
        statusCode: status,
        data: 'not a valid configuration',
        headers: Headers.fromMap({
          'X-Hwid-Max-Devices-Reached': [' TRUE '],
          'announce': ['Your custom explanation'],
          'support-url': [' https://example.com/support '],
        }),
      );
      var saved = false;
      Future<void> update() async {
        await fetchSubscriptionResponse(() async {
          if (status >= 400) {
            throw DioException.badResponse(
                statusCode: status,
                requestOptions: response.requestOptions,
                response: response);
          }
          return response;
        });
        saved = true;
      }

      await expectLater(
          update(),
          throwsA(isA<SubscriptionDeviceLimitException>()
              .having((e) => e.message, 'message', 'Your custom explanation')
              .having((e) => e.supportUrl, 'support URL',
                  'https://example.com/support')));
      expect(saved, isFalse);
    });
  }

  test('normal response and unrelated HTTP errors retain their behavior',
      () async {
    final response = Response<String>(
        requestOptions: RequestOptions(path: '/'), data: 'config');
    expect(
        await fetchSubscriptionResponse(() async => response), same(response));
    final error = DioException(
        requestOptions: response.requestOptions, response: response);
    await expectLater(
        fetchSubscriptionResponse<String>(() async => throw error),
        throwsA(same(error)));
  });

  test('device limit does not trigger domain fallback', () async {
    final requested = <String>[];
    final error = SubscriptionDeviceLimitException(announce: 'Limit reached');
    await expectLater(
        fetchSubscriptionWithFallback<String>(
          primaryUrl: 'https://primary.example/subscription',
          fallbackDomain: 'fallback.example',
          fetch: (url) async {
            requested.add(url);
            throw error;
          },
        ),
        throwsA(same(error)));
    expect(requested, ['https://primary.example/subscription']);
  });
}
