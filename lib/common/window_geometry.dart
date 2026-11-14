import 'dart:math' as math;
import 'dart:ui';

/// All rectangles in this module are physical desktop pixels.
class WindowDisplay {
  const WindowDisplay(this.workArea, this.scale, {this.primary = false});
  final Rect workArea;
  final double scale;
  final bool primary;
}

bool validWindowRect(Rect rect) =>
    rect.left.isFinite &&
    rect.top.isFinite &&
    rect.width.isFinite &&
    rect.height.isFinite &&
    rect.width > 0 &&
    rect.height > 0;

/// Subtract work areas instead of testing corners (also handles gaps).
bool coveredByDisplays(Rect rect, List<WindowDisplay> displays) {
  if (!validWindowRect(rect)) return false;
  var remaining = <Rect>[rect];
  for (final display in displays) {
    final next = <Rect>[];
    for (final part in remaining) {
      final cut = part.intersect(display.workArea);
      if (cut.isEmpty) {
        next.add(part);
        continue;
      }
      final pieces = [
        Rect.fromLTRB(part.left, part.top, part.right, cut.top),
        Rect.fromLTRB(part.left, cut.bottom, part.right, part.bottom),
        Rect.fromLTRB(part.left, cut.top, cut.left, cut.bottom),
        Rect.fromLTRB(cut.right, cut.top, part.right, cut.bottom),
      ];
      next.addAll(pieces.where((r) => !r.isEmpty));
    }
    remaining = next;
  }
  return remaining.isEmpty;
}

class WindowPlacement {
  const WindowPlacement(this.bounds, this.minimumSize, this.reason);
  final Rect bounds;
  final Size minimumSize; // logical pixels on the selected monitor
  final String reason;
}

WindowPlacement? restoreWindowGeometry({
  required List<WindowDisplay> displays,
  required Size logicalSize,
  Offset? savedPosition,
  required double savedScale,
}) {
  final screens = displays
      .where(
          (d) => validWindowRect(d.workArea) && d.scale.isFinite && d.scale > 0)
      .toList();
  if (screens.isEmpty) return null;
  var target = screens.where((d) => d.primary).firstOrNull ?? screens.first;
  double dimension(double value, double fallback, double minimum) =>
      value.isFinite && value > 0 ? math.max(value, minimum) : fallback;
  final size = Size(dimension(logicalSize.width, 450, 380),
      dimension(logicalSize.height, 900, 600));
  final scale = savedScale.isFinite && savedScale > 0 ? savedScale : 1.0;
  final position = savedPosition != null &&
          savedPosition.dx.isFinite &&
          savedPosition.dy.isFinite
      ? savedPosition * scale
      : null;
  Rect? candidate = position == null ? null : position & (size * scale);
  var largest = 0.0;
  if (candidate != null && validWindowRect(candidate)) {
    for (final screen in screens) {
      final intersection = candidate.intersect(screen.workArea);
      final area =
          intersection.isEmpty ? 0.0 : intersection.width * intersection.height;
      if (area > largest) {
        largest = area;
        target = screen;
      }
    }
  }
  final work = target.workArea;
  final minimum = Size(math.min(380, work.width / target.scale),
      math.min(600, work.height / target.scale));
  // Logical size follows the destination monitor's DPI, position stays physical.
  final physicalSize = size * target.scale;
  candidate = position == null ? null : position & physicalSize;
  if (largest > 0 &&
      candidate != null &&
      coveredByDisplays(candidate, screens)) {
    return WindowPlacement(candidate, minimum, 'preserved');
  }
  final fitted = Size(math.min(physicalSize.width, work.width),
      math.min(physicalSize.height, work.height));
  final center = position == null || largest == 0;
  final offset = center
      ? Offset(work.left + (work.width - fitted.width) / 2,
          work.top + (work.height - fitted.height) / 2)
      : Offset(position.dx.clamp(work.left, work.right - fitted.width),
          position.dy.clamp(work.top, work.bottom - fitted.height));
  return WindowPlacement(
      offset & fitted, minimum, center ? 'primary fallback' : 'clamped');
}
