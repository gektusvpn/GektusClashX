const _githubHosts = {
  'github.com',
  'raw.githubusercontent.com',
};

String githubProxyUrlWithBase(String targetUrl, String? proxyUrl) {
  final target = Uri.tryParse(targetUrl);
  if (target == null ||
      target.scheme != 'https' ||
      !_githubHosts.contains(target.host.toLowerCase())) {
    return targetUrl;
  }

  final trimmedProxyUrl = proxyUrl?.trim();
  if (trimmedProxyUrl == null || trimmedProxyUrl.isEmpty) return targetUrl;

  final proxy = Uri.tryParse(trimmedProxyUrl);
  if (proxy == null ||
      proxy.scheme != 'https' ||
      proxy.host.isEmpty ||
      proxy.hasQuery ||
      proxy.hasFragment) {
    return targetUrl;
  }

  final base = trimmedProxyUrl.replaceFirst(RegExp(r'/+$'), '');
  return '$base/$targetUrl';
}
