import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:qr_flutter/qr_flutter.dart';

/// Scroll only the owning list. Scrollable.ensureVisible also moves ancestor
/// PageViews, which can expose another destination while focusing a TV tab.
void revealTVFocus(BuildContext context, {double alignment = 0.5}) {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!context.mounted) return;
    final scrollable = Scrollable.maybeOf(context);
    final target = context.findRenderObject();
    if (scrollable == null || target == null) return;
    final viewport = RenderAbstractViewport.maybeOf(target);
    if (viewport == null) return;
    final position = scrollable.position;
    final margin = position.axis == Axis.vertical ? 24.0 : 8.0;
    final start = viewport.getOffsetToReveal(target, 0).offset - margin;
    final end = viewport.getOffsetToReveal(target, 1).offset + margin;
    final offset = end > start
        ? viewport.getOffsetToReveal(target, alignment).offset
        : position.pixels > start
            ? start
            : position.pixels < end
                ? end
                : position.pixels;
    if ((offset - position.pixels).abs() < 1) return;
    unawaited(position.animateTo(
      offset.clamp(position.minScrollExtent, position.maxScrollExtent),
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOutCubic,
    ));
  });
  WidgetsBinding.instance.ensureVisualUpdate();
}

/// Shared palette roles for TV controls: focus is primary, selection is tonal.
ButtonStyle tvButtonStyle(
  BuildContext context, {
  bool selected = false,
  bool prominent = false,
  bool transparent = false,
  double radius = 24,
}) {
  final colors = Theme.of(context).colorScheme;
  return ButtonStyle(
    minimumSize: const WidgetStatePropertyAll(Size(48, 48)),
    padding: const WidgetStatePropertyAll(
      EdgeInsets.symmetric(horizontal: 20, vertical: 12),
    ),
    animationDuration: const Duration(milliseconds: 120),
    shape: WidgetStatePropertyAll(RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radius),
    )),
    overlayColor: WidgetStateProperty.resolveWith((states) =>
        states.contains(WidgetState.pressed)
            ? colors.onPrimary.withValues(alpha: 0.12)
            : Colors.transparent),
    backgroundColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.disabled)) return colors.surfaceContainer;
      if (states.contains(WidgetState.focused) || prominent) {
        return colors.primary;
      }
      if (selected) return colors.secondaryContainer;
      return transparent ? Colors.transparent : colors.surfaceContainerHigh;
    }),
    foregroundColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.disabled)) {
        return colors.onSurface.withValues(alpha: 0.38);
      }
      if (states.contains(WidgetState.focused) || prominent) {
        return colors.onPrimary;
      }
      return selected ? colors.onSecondaryContainer : colors.onSurface;
    }),
    side: WidgetStateProperty.resolveWith((states) =>
        states.contains(WidgetState.focused)
            ? BorderSide(color: colors.primary, width: 2)
            : const BorderSide(color: Colors.transparent, width: 2)),
    textStyle: WidgetStatePropertyAll(Theme.of(context).textTheme.titleSmall),
  );
}

class TVActionButton extends StatelessWidget {
  const TVActionButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
    this.focusNode,
    this.autofocus = false,
    this.selected = false,
    this.prominent = false,
    this.radius = 24,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final FocusNode? focusNode;
  final bool autofocus;
  final bool selected;
  final bool prominent;
  final double radius;

  @override
  Widget build(BuildContext context) => TextButton.icon(
        focusNode: focusNode,
        autofocus: autofocus,
        onFocusChange: (focused) {
          if (focused) revealTVFocus(context);
        },
        onPressed: onPressed,
        style: tvButtonStyle(context,
            selected: selected, prominent: prominent, radius: radius),
        icon: Icon(icon, size: 22),
        label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
      );
}

/// Branded QR with a quiet zone and dark modules in both light and dark themes.
class TVQrCode extends StatelessWidget {
  const TVQrCode({super.key, required this.data});
  final String data;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final primaryIsLighter =
        colors.primary.computeLuminance() > colors.onPrimary.computeLuminance();
    final background = primaryIsLighter ? colors.primary : colors.onPrimary;
    final foreground = primaryIsLighter ? colors.onPrimary : colors.primary;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(16),
      ),
      child: QrImageView(
        data: data,
        size: 152,
        padding: EdgeInsets.zero,
        backgroundColor: background,
        dataModuleStyle: QrDataModuleStyle(
            color: foreground, dataModuleShape: QrDataModuleShape.square),
        eyeStyle: QrEyeStyle(color: foreground, eyeShape: QrEyeShape.square),
      ),
    );
  }
}
