import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:gektusclashx/models/config.dart';

void main() {
  test('legacy props and scale serialize compatibly', () {
    final legacy = WindowProps.fromJson({'left': 0, 'top': -100, 'width': 500});
    expect(legacy.left, 0);
    expect(legacy.top, -100);
    expect(legacy.positionScale, isNull);
    final updated = legacy.copyWith(positionScale: 1.5);
    expect(WindowProps.fromJson(updated.toJson()), updated);
  });
  test('bad geometry is sanitized without losing unrelated config', () {
    final data = jsonDecode(jsonEncode(Config(themeProps: defaultThemeProps)))
        as Map<String, dynamic>;
    data['windowProps'] = {
      'width': 'bad',
      'height': -20,
      'left': double.nan,
      'top': double.infinity,
      'positionScale': 0
    };
    data['currentProfileId'] = 'keep-me';
    final config = Config.fromJson(data);
    expect(config.currentProfileId, 'keep-me');
    expect(config.windowProps, const WindowProps());
    data['windowProps'] = 'broken';
    expect(Config.fromJson(data).currentProfileId, 'keep-me');
    expect(Config.fromJson(data).windowProps, const WindowProps());
  });
}
