import 'package:flutter_test/flutter_test.dart';
import 'package:gektusclashx/common/proxies_style.dart';
import 'package:gektusclashx/enum/enum.dart';
import 'package:gektusclashx/models/config.dart';

void main() {
  const current = ProxiesStyle(
    type: ProxiesType.tab,
    iconMap: {'YouTube': 'youtube.svg'},
  );

  for (final card in ProxyCardType.values) {
    final header =
        'type:list; sort:delay; layout:tight; icon:none; card:${card.name}';
    test('TV accepts ${card.name} cards without applying other view settings',
        () {
      expect(
        applyProxiesViewHeader(current, header, isAndroidTV: true),
        current.copyWith(cardType: card),
      );
    });
    test('phones and desktops still apply all view settings (${card.name})',
        () {
      expect(
        applyProxiesViewHeader(current, header, isAndroidTV: false),
        current.copyWith(
          type: ProxiesType.list,
          sortType: ProxiesSortType.delay,
          layout: ProxiesLayout.tight,
          iconStyle: ProxiesIconStyle.none,
          cardType: card,
        ),
      );
    });
  }

  test('missing or invalid card settings preserve the current TV card', () {
    final style = current.copyWith(cardType: ProxyCardType.min);
    for (final header in [
      '',
      'type:list; sort:name; layout:loose; icon:none',
      'card:invalid; card:; card:shrink:invalid; invalid',
    ]) {
      expect(applyProxiesViewHeader(style, header, isAndroidTV: true), style);
    }
  });

  test('header matching remains case-insensitive and accepts the icon alias',
      () {
    final style = current.copyWith(iconStyle: ProxiesIconStyle.none);
    const header = ' CARD : ShRiNk ; ICON : STANDARD ; unknown:value';
    expect(
      applyProxiesViewHeader(style, header, isAndroidTV: true),
      style.copyWith(cardType: ProxyCardType.shrink),
    );
    expect(
      applyProxiesViewHeader(style, header, isAndroidTV: false),
      style.copyWith(
        cardType: ProxyCardType.shrink,
        iconStyle: ProxiesIconStyle.icon,
      ),
    );
  });
}
