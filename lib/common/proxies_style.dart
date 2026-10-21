import 'package:gektusclashx/enum/enum.dart';
import 'package:gektusclashx/models/config.dart';

/// Applies the subscription's `gektusclashx-view` header. TV keeps its own
/// navigation and grid layout; only the card presentation is provider-controlled.
ProxiesStyle applyProxiesViewHeader(
  ProxiesStyle current,
  String header, {
  required bool isAndroidTV,
}) {
  var style = current;
  for (final setting in header.split(';')) {
    final parts = setting.split(':');
    if (parts.length != 2) continue;
    final key = parts[0].trim().toLowerCase();
    final value = parts[1].trim().toLowerCase();
    if (isAndroidTV && key != 'card') continue;
    style = switch (key) {
      'type' => style.copyWith(
          type: ProxiesType.values.firstWhere(
            (item) => item.name == value,
            orElse: () => style.type,
          ),
        ),
      'sort' => style.copyWith(
          sortType: ProxiesSortType.values.firstWhere(
            (item) => item.name == value,
            orElse: () => style.sortType,
          ),
        ),
      'layout' => style.copyWith(
          layout: ProxiesLayout.values.firstWhere(
            (item) => item.name == value,
            orElse: () => style.layout,
          ),
        ),
      'icon' => style.copyWith(
          iconStyle: ProxiesIconStyle.values.firstWhere(
            (item) => item.name == (value == 'standard' ? 'icon' : value),
            orElse: () => style.iconStyle,
          ),
        ),
      'card' => style.copyWith(
          cardType: ProxyCardType.values.firstWhere(
            (item) => item.name == value,
            orElse: () => style.cardType,
          ),
        ),
      _ => style,
    };
  }
  return style;
}
