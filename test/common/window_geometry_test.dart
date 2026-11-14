import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:gektusclashx/common/window_geometry.dart';

void main() {
  const primary =
      WindowDisplay(Rect.fromLTWH(0, 0, 1920, 1040), 1, primary: true);
  WindowPlacement? restore(List<WindowDisplay> displays,
          {Offset? position,
          Size size = const Size(450, 900),
          double scale = 1}) =>
      restoreWindowGeometry(
          displays: displays,
          logicalSize: size,
          savedPosition: position,
          savedScale: scale);

  test('origin is a real position; missing and offscreen positions center', () {
    expect(
        restore([primary], position: Offset.zero)!.bounds.topLeft, Offset.zero);
    for (final position in [
      null,
      const Offset(99999, 100),
      const Offset(double.nan, 1)
    ]) {
      final result = restore([primary], position: position)!;
      expect(result.reason, 'primary fallback');
      expect(result.bounds.center, primary.workArea.center);
    }
  });

  test('physical coordinates prevent the saved 2200 -> 3300 DPI regression',
      () {
    const displays = [
      WindowDisplay(Rect.fromLTWH(0, 0, 1920, 1080), 1.5, primary: true),
      WindowDisplay(Rect.fromLTWH(1920, 0, 1280, 1080), 1),
    ];
    final result = restore(displays, position: const Offset(2200, 100))!;
    expect(result.bounds.left, 2200);
    expect(result.reason, 'preserved');
    expect(coveredByDisplays(result.bounds, displays), isTrue);
  });

  test('negative monitor coordinates and saved scale round trip', () {
    const display = WindowDisplay(Rect.fromLTWH(-2560, -1440, 2560, 1440), 2);
    final result = restore([primary, display],
        position: const Offset(-1000, -650),
        size: const Size(500, 600),
        scale: 2)!;
    expect(result.bounds.topLeft, const Offset(-2000, -1300));
    expect(result.bounds.size, const Size(1000, 1200));
  });

  test('disconnected monitor and changed primary use current primary', () {
    const replacement =
        WindowDisplay(Rect.fromLTWH(-1920, 0, 1920, 1080), 1, primary: true);
    expect(
        restore([replacement], position: const Offset(2200, 100))!
            .bounds
            .center,
        replacement.workArea.center);
  });

  test('intersection with neither old corner visible is retained and fitted',
      () {
    final result = restore([primary],
        position: const Offset(-100, 300), size: const Size(2200, 600))!;
    expect(result.reason, 'clamped');
    expect(coveredByDisplays(result.bounds, [primary]), isTrue);
    expect(result.bounds.top, 300);
  });

  test('lower corner only is insufficient; header becomes accessible', () {
    final result = restore([primary], position: const Offset(-300, -700))!;
    expect(result.bounds.topLeft, Offset.zero);
  });

  test('union preserves spanning windows but detects gaps and taskbars', () {
    const adjacent = WindowDisplay(Rect.fromLTWH(1920, 0, 1280, 1040), 1);
    final result = restore([primary, adjacent],
        position: const Offset(1700, 100), size: const Size(450, 600))!;
    expect(result.reason, 'preserved');
    const gap = WindowDisplay(Rect.fromLTWH(2020, 0, 1280, 1040), 1);
    expect(coveredByDisplays(result.bounds, [primary, gap]), isFalse);
    const inset =
        WindowDisplay(Rect.fromLTWH(40, 40, 1880, 1000), 1, primary: true);
    final fitted = restore([inset], position: Offset.zero)!;
    expect(fitted.bounds.left, 40);
    expect(fitted.bounds.top, 40);
  });

  test('invalid size and tiny work area remain finite and fit', () {
    const tiny = WindowDisplay(Rect.fromLTWH(0, 0, 300, 200), 2, primary: true);
    final result = restore([tiny], size: const Size(double.infinity, -1))!;
    expect(result.bounds, tiny.workArea);
    expect(result.minimumSize, const Size(150, 100));
    expect(restore([], position: Offset.zero), isNull);
    expect(restore([const WindowDisplay(Rect.zero, 0)]), isNull);
  });

  test('restoration is idempotent across scaling and topology combinations',
      () {
    for (final scale in [1.0, 1.25, 1.5, 2.0]) {
      final displays = [
        primary,
        WindowDisplay(const Rect.fromLTWH(-2560, -200, 2560, 1440), scale)
      ];
      for (final position in [
        const Offset(-2300, 0),
        const Offset(1800, -500),
        const Offset(50000, 0),
        const Offset(-300, 40)
      ]) {
        final first = restore(displays, position: position)!;
        expect(validWindowRect(first.bounds), isTrue);
        expect(coveredByDisplays(first.bounds, displays), isTrue);
        final target =
            displays.firstWhere((d) => d.workArea.overlaps(first.bounds));
        final second = restore(displays,
            position: first.bounds.topLeft / target.scale,
            size: first.bounds.size / target.scale,
            scale: target.scale)!;
        expect(second.bounds, first.bounds);
      }
    }
  });
}
