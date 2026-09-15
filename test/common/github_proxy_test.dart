import 'package:flutter_test/flutter_test.dart';
import 'package:gektusclashx/common/github_proxy.dart';

void main() {
  const proxy = 'https://proxy.example/gh/token';

  test('proxies supported GitHub hosts', () {
    expect(
      githubProxyUrlWithBase(
        'https://github.com/gektusvpn/GektusClashX/releases/latest',
        proxy,
      ),
      '$proxy/https://github.com/gektusvpn/GektusClashX/releases/latest',
    );
    expect(
      githubProxyUrlWithBase(
        'https://raw.githubusercontent.com/owner/repo/main/file',
        '$proxy/',
      ),
      '$proxy/https://raw.githubusercontent.com/owner/repo/main/file',
    );
  });

  test('leaves unsupported hosts unchanged', () {
    const apiUrl = 'https://api.github.com/repos/owner/repo/releases/latest';
    const externalUrl = 'https://example.com/config.yaml';

    expect(githubProxyUrlWithBase(apiUrl, proxy), apiUrl);
    expect(githubProxyUrlWithBase(externalUrl, proxy), externalUrl);
  });

  test('ignores invalid proxy bases', () {
    const target = 'https://github.com/owner/repo/releases/latest';

    expect(githubProxyUrlWithBase(target, 'http://proxy.example'), target);
    expect(
        githubProxyUrlWithBase(target, 'https://proxy.example/?q=1'), target);
    expect(githubProxyUrlWithBase(target, 'not a URL'), target);
  });
}
