import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gektusclashx/common/core_compatibility.dart';
import 'package:gektusclashx/common/subscription_fallback.dart';
import 'package:gektusclashx/l10n/l10n.dart';
import 'package:gektusclashx/models/core.dart';

void main() {
  setUpAll(() async => AppLocalizations.load(const Locale('ru')));
  final cases = jsonDecode(
      File('test/fixtures/core_compatibility.json').readAsStringSync()) as List;
  for (final item in cases) {
    test('shared Dart/Go versions: ${item['current']} >= ${item['minimum']}',
        () {
      final minimum = normalizeMinCoreVersion(item['minimum'] as String);
      expect(
          minimum == null
              ? true
              : isCoreCompatible(item['current'] as String, minimum),
          item['compatible']);
    });
  }

  test('optional/invalid requirement never queries the core', () async {
    for (final requirement in [null, '', ' ', 'latest']) {
      await ensureCoreCompatibility(requirement,
          readVersion: () async => fail('Core should not be queried'));
    }
  });

  test('refusal has friendly text without announce or version details',
      () async {
    await expectLater(
        ensureCoreCompatibility('1.19.30',
            readVersion: () async => '1.19.29',
            supportUrl: 'https://example.com/help'),
        throwsA(isA<CoreCompatibilityException>()
            .having((e) => e.message, 'message',
                'Обновите приложение для получения новой конфигурации из подписки.')
            .having((e) => e.supportUrl, 'support', 'https://example.com/help')
            .having((e) => e.diagnostic, 'diagnostic', contains('1.19.29'))));
  });

  test('unavailable core stops validation with retry explanation', () async {
    await expectLater(
        ensureCoreCompatibility('1.19.30',
            readVersion: () async => throw StateError('offline')),
        throwsA(isA<CoreCompatibilityException>()
            .having((e) => e.unknown, 'unknown', true)
            .having((e) => e.message, 'message',
                'Не удалось проверить совместимость подписки. Попробуйте ещё раз.')));
  });

  test('compatibility refusal is not retried on the fallback domain', () async {
    final urls = <String>[];
    await expectLater(
        fetchSubscriptionWithFallback<String>(
          primaryUrl: 'https://primary.example/subscription',
          fallbackDomain: 'fallback.example',
          fetch: (url) async {
            urls.add(url);
            await ensureCoreCompatibility('1.19.30',
                readVersion: () async => '1.19.29');
            return 'must not be saved';
          },
        ),
        throwsA(isA<CoreCompatibilityException>()));
    expect(urls, ['https://primary.example/subscription']);
  });

  test('structured native errors are readable and friendly', () {
    final error = parseCoreCompatibilityError(
        '$coreCompatibilityErrorPrefix{"minimum":"1.19.30","current":"1.19.29","unknown":false}');
    expect(error!.minimum, '1.19.30');
    expect(error.current, '1.19.29');
    expect(error.toString(), AppLocalizations.current.coreCompatibilityMessage);
    expect(parseCoreCompatibilityError('ordinary error'), isNull);
  });

  for (final version in ['1.19.29', '1.19.31', 'unknown']) {
    test('profile change during version query discards stale result: $version',
        () async {
      final versionResult = Completer<String>();
      var selected = true;
      final check = ensureSelectedCoreCompatibility(
        '1.19.30',
        readVersion: () => versionResult.future,
        isCurrent: () => selected,
      );
      selected = false;
      versionResult.complete(version);
      expect(await check, isFalse);
    });
  }

  test('support action accepts a URL or an email-only contact', () {
    expect(
        coreCompatibilitySupportTarget({
          'support-url': ' https://example.com/help ',
          'support-email': 'help@example.com'
        }),
        'https://example.com/help');
    expect(
        coreCompatibilitySupportTarget({'support-email': ' help@example.com '}),
        'mailto:help@example.com');
    expect(
        coreCompatibilitySupportTarget(
            {'support-email': 'mailto:help@example.com'}),
        'mailto:help@example.com');
    expect(coreCompatibilitySupportTarget({}), isNull);
  });

  test('SetupParams roundtrip preserves optional requirement and old payloads',
      () {
    final old = SetupParams.fromJson({
      'config': <String, dynamic>{},
      'selected-map': <String, String>{},
      'test-url': ''
    });
    expect(old.minCoreVersion, isNull);
    final updated = old.copyWith(minCoreVersion: '1.19.30');
    expect(SetupParams.fromJson(updated.toJson()).minCoreVersion, '1.19.30');
  });
}
