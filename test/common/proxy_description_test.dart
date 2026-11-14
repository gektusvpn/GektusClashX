import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gektusclashx/models/common.dart';
import 'package:gektusclashx/providers/state.dart';

void main() {
  for (final description in [null, '', '  ', 'Для видео', '  Для видео  ']) {
    test('proxy card description falls back only when empty: $description', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final proxy = Proxy.fromJson({
        'name': 'Германия',
        'type': 'Vless',
        'serverDescription': description,
      });
      expect(container.read(getProxyDescProvider(proxy)),
          (description?.trim().isNotEmpty ?? false) ? 'Для видео' : 'Vless');
    });
  }
}
