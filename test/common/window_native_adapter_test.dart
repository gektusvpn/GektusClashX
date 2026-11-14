import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:window_ext/window_ext.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('window_ext');
  test('physical bounds pass unchanged; snapshot keeps each monitor scale',
      () async {
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return {
        'x': -2200.0,
        'y': -100.0,
        'width': 900.0,
        'height': 1200.0,
        'scale': 2.0,
        'visible': false,
        'minimized': false,
        'maximized': false,
        'fullscreen': false,
        'displays': [
          {
            'x': -2560.0,
            'y': -200.0,
            'width': 2560.0,
            'height': 1440.0,
            'scale': 2.0,
            'primary': false
          },
          {
            'x': 0.0,
            'y': 0.0,
            'width': 1920.0,
            'height': 1040.0,
            'scale': 1.0,
            'primary': true
          },
        ]
      };
    });
    addTearDown(() => TestDefaultBinaryMessengerBinding
        .instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null));
    final snapshot = await windowExtManager.getGeometrySnapshot();
    expect(snapshot.normal, isTrue);
    expect(snapshot.visible, isFalse);
    expect(snapshot.displays[0].scale, 2);
    const rect = Rect.fromLTWH(-2200, -100, 900, 1200);
    await windowExtManager.setPhysicalBounds(rect);
    expect(calls.map((c) => c.method),
        ['getGeometrySnapshot', 'setPhysicalBounds']);
    expect(calls.last.arguments['x'], -2200);
    expect(calls.last.arguments['width'], 900);
  });
}
