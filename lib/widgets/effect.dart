import 'dart:ui';

import 'package:flutter/material.dart';

import 'tv_controls.dart';

/// Adds the clear scale, outline, and glow used for D-pad focus on Android TV.
///
/// The wrapper does not become a focus target itself. It observes focus on the
/// interactive descendant, so buttons and InkWells keep their native actions
/// and semantics.
class TVFocusEffect extends StatefulWidget {
  const TVFocusEffect({
    super.key,
    required this.enabled,
    required this.borderRadius,
    required this.child,
    this.scrollAlignment,
  });

  final bool enabled;
  final BorderRadiusGeometry borderRadius;
  final Widget child;
  final double? scrollAlignment;

  @override
  State<TVFocusEffect> createState() => _TVFocusEffectState();
}

class _TVFocusEffectState extends State<TVFocusEffect> {
  bool _focused = false;

  void _handleFocusChange(bool focused) {
    if (_focused == focused) return;
    setState(() => _focused = focused);
    if (focused && widget.scrollAlignment != null) {
      revealTVFocus(context, alignment: widget.scrollAlignment!);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;

    final colorScheme = Theme.of(context).colorScheme;
    return Focus(
      canRequestFocus: false,
      onFocusChange: _handleFocusChange,
      child: AnimatedScale(
        scale: _focused ? 1.025 : 1,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOutCubic,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            borderRadius: widget.borderRadius,
            boxShadow: _focused
                ? [
                    BoxShadow(
                      color: colorScheme.primary.withValues(alpha: 0.12),
                      blurRadius: 4,
                      spreadRadius: 1,
                    ),
                  ]
                : const [],
          ),
          foregroundDecoration: BoxDecoration(
            borderRadius: widget.borderRadius,
            border: _focused
                ? Border.all(color: colorScheme.primary, width: 2)
                : null,
          ),
          child: widget.child,
        ),
      ),
    );
  }
}

class EffectGestureDetector extends StatefulWidget {
  const EffectGestureDetector({
    super.key,
    required this.child,
    this.onLongPress,
    this.onTap,
  });
  final Widget child;
  final GestureLongPressCallback? onLongPress;
  final GestureTapCallback? onTap;

  @override
  State<EffectGestureDetector> createState() => _EffectGestureDetectorState();
}

class _EffectGestureDetectorState extends State<EffectGestureDetector>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  double _scale = 1;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedScale(
        scale: _scale,
        duration: kThemeAnimationDuration,
        curve: Curves.easeOut,
        child: GestureDetector(
          onLongPress: widget.onLongPress,
          onLongPressStart: (_) {
            setState(() {
              _scale = 0.95;
            });
          },
          onTap: widget.onTap,
          onLongPressEnd: (_) {
            setState(() {
              _scale = 1;
            });
          },
          child: widget.child,
        ),
      );
}

class CommonExpandIcon extends StatefulWidget {
  const CommonExpandIcon({
    super.key,
    this.expand = false,
  });
  final bool expand;

  @override
  State<CommonExpandIcon> createState() => _CommonExpandIconState();
}

class _CommonExpandIconState extends State<CommonExpandIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _iconTurns;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _iconTurns = _animationController.drive(
      Tween<double>(begin: 0.0, end: 0.5),
    );
    if (widget.expand) {
      _animationController.value = 1.0;
    }
  }

  @override
  void didUpdateWidget(covariant CommonExpandIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.expand != widget.expand) {
      if (widget.expand) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _animationController.view,
        builder: (_, child) => RotationTransition(
          turns: _iconTurns,
          child: child,
        ),
        child: const Icon(
          Icons.expand_more,
        ),
      );
}

Widget proxyDecorator(
  Widget child,
  int index,
  Animation<double> animation,
) =>
    AnimatedBuilder(
      animation: animation,
      builder: (_, child) {
        final animValue = Curves.easeInOut.transform(animation.value);
        final scale = lerpDouble(1, 1.02, animValue)!;
        return Transform.scale(
          scale: scale,
          child: child,
        );
      },
      child: child,
    );
