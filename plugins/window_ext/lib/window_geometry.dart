import 'dart:ui';

class NativeDisplay {
  NativeDisplay(Map<Object?, Object?> data)
      : workArea = physicalRect(data),
        scale = (data['scale'] as num).toDouble(),
        primary = data['primary'] == true;
  final Rect workArea;
  final double scale;
  final bool primary;
}

Rect physicalRect(Map<Object?, Object?> data) => Rect.fromLTWH(
    (data['x'] as num).toDouble(),
    (data['y'] as num).toDouble(),
    (data['width'] as num).toDouble(),
    (data['height'] as num).toDouble());

class NativeGeometry {
  NativeGeometry(Map<Object?, Object?> data)
      : bounds = physicalRect(data),
        scale = (data['scale'] as num).toDouble(),
        visible = data['visible'] == true,
        minimized = data['minimized'] == true,
        maximized = data['maximized'] == true,
        fullscreen = data['fullscreen'] == true,
        displays = (data['displays'] as List)
            .map((e) => NativeDisplay(e as Map<Object?, Object?>))
            .toList();
  final Rect bounds;
  final double scale;
  final bool visible, minimized, maximized, fullscreen;
  final List<NativeDisplay> displays;
  bool get normal => !minimized && !maximized && !fullscreen;
  @override
  String toString() =>
      'bounds=$bounds scale=$scale visible=$visible minimized=$minimized maximized=$maximized fullscreen=$fullscreen displays=${displays.map((d) => '${d.workArea}@${d.scale} primary=${d.primary}').join(';')}';
}
