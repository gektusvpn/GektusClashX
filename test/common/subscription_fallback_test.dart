import 'package:flutter_test/flutter_test.dart';
import 'package:gektusclashx/common/subscription_fallback.dart';

void main() {
  const primaryUrl =
      'https://primary.example/subscription/TOKEN?device=android';
  const fallbackDomain = 'fallback.example';
  const fallbackUrl =
      'https://fallback.example/subscription/TOKEN?device=android';

  test('uses the primary subscription URL when it succeeds', () async {
    final requestedUrls = <String>[];

    final result = await fetchSubscriptionWithFallback(
      primaryUrl: primaryUrl,
      fallbackDomain: fallbackDomain,
      fetch: (url) async {
        requestedUrls.add(url);
        return 'profile';
      },
    );

    expect(result.value, 'profile');
    expect(result.usedFallback, isFalse);
    expect(result.requestUrl, primaryUrl);
    expect(requestedUrls, [primaryUrl]);
  });

  test('uses the fallback URL after a primary request failure', () async {
    final requestedUrls = <String>[];

    final result = await fetchSubscriptionWithFallback(
      primaryUrl: primaryUrl,
      fallbackDomain: '  $fallbackDomain  ',
      fetch: (url) async {
        requestedUrls.add(url);
        if (url == primaryUrl) throw Exception('primary unavailable');
        return 'profile';
      },
    );

    expect(result.value, 'profile');
    expect(result.usedFallback, isTrue);
    expect(result.fallbackDomain, fallbackDomain);
    expect(result.requestUrl, fallbackUrl);
    expect(requestedUrls, [primaryUrl, fallbackUrl]);
  });

  test('rethrows the primary error when fallback is unavailable', () async {
    final primaryError = Exception('primary unavailable');
    final requestedUrls = <String>[];

    final future = fetchSubscriptionWithFallback<void>(
      primaryUrl: primaryUrl,
      fallbackDomain: 'https://fallback.example/subscription',
      fetch: (url) async {
        requestedUrls.add(url);
        throw primaryError;
      },
    );

    await expectLater(future, throwsA(same(primaryError)));
    expect(requestedUrls, [primaryUrl]);
  });

  test('does not retry the same subscription URL', () async {
    final requestedUrls = <String>[];

    final future = fetchSubscriptionWithFallback<void>(
      primaryUrl: primaryUrl,
      fallbackDomain: 'primary.example',
      fetch: (url) async {
        requestedUrls.add(url);
        throw Exception('unavailable');
      },
    );

    await expectLater(future, throwsException);
    expect(requestedUrls, [primaryUrl]);
  });
}
