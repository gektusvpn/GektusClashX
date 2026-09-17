class SubscriptionFetchResult<T> {
  const SubscriptionFetchResult({
    required this.value,
    required this.requestUrl,
    required this.fallbackDomain,
  });

  final T value;
  final String requestUrl;
  final String? fallbackDomain;

  bool get usedFallback => fallbackDomain != null;
}

Future<SubscriptionFetchResult<T>> fetchSubscriptionWithFallback<T>({
  required String primaryUrl,
  required String? fallbackDomain,
  required Future<T> Function(String url) fetch,
}) async {
  try {
    return SubscriptionFetchResult(
      value: await fetch(primaryUrl),
      requestUrl: primaryUrl,
      fallbackDomain: null,
    );
  } catch (error, stackTrace) {
    final domain = _validFallbackDomain(fallbackDomain);
    final fallbackUrl = _replaceDomain(primaryUrl, domain);
    if (domain == null || fallbackUrl == null || fallbackUrl == primaryUrl) {
      Error.throwWithStackTrace(error, stackTrace);
    }

    return SubscriptionFetchResult(
      value: await fetch(fallbackUrl),
      requestUrl: fallbackUrl,
      fallbackDomain: domain,
    );
  }
}

String? _validFallbackDomain(String? value) {
  final candidate = value?.trim();
  if (candidate == null || candidate.isEmpty) {
    return null;
  }

  final uri = Uri.tryParse('https://$candidate');
  if (uri == null || uri.host.isEmpty) {
    return null;
  }
  if (uri.userInfo.isNotEmpty || uri.hasPort || uri.path.isNotEmpty) {
    return null;
  }
  if (uri.hasQuery || uri.hasFragment) {
    return null;
  }
  return uri.host;
}

String? _replaceDomain(String primaryUrl, String? fallbackDomain) {
  if (fallbackDomain == null) {
    return null;
  }

  final primary = Uri.tryParse(primaryUrl.trim());
  if (primary == null || primary.host.isEmpty) {
    return null;
  }
  if (primary.scheme != 'http' && primary.scheme != 'https') {
    return null;
  }
  if (primary.host == fallbackDomain) {
    return null;
  }
  return primary.replace(host: fallbackDomain).toString();
}
