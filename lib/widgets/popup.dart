import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gektusclashx/models/common.dart';

typedef PopupOpen = void Function();
typedef PopupTargetBuilder = Widget Function(PopupOpen open,
    FocusNode focusNode, WidgetStatesController statesController);

/// The same focus, trigger state, and Material anchoring for every action menu.
class CommonPopupBox extends StatefulWidget {
  const CommonPopupBox({
    super.key,
    required this.targetBuilder,
    required this.popup,
    this.focusNode,
    this.alignmentOffset = const Offset(0, 4),
  });
  final PopupTargetBuilder targetBuilder;
  final CommonPopupMenu popup;
  final FocusNode? focusNode;
  final Offset alignmentOffset;

  @override
  State<CommonPopupBox> createState() => _CommonPopupBoxState();
}

class _CommonPopupBoxState extends State<CommonPopupBox> {
  final _controller = MenuController();
  final _ownTriggerFocus = FocusNode(debugLabel: 'Menu trigger');
  final _triggerStates = WidgetStatesController();
  final _itemFocus = <FocusNode>[];
  bool _keyboardNavigation = false;
  bool _disposing = false;
  LocalHistoryEntry? _historyEntry;

  FocusNode get _triggerFocus => widget.focusNode ?? _ownTriggerFocus;

  @override
  void initState() {
    super.initState();
    _syncItemFocus();
    FocusManager.instance.addEarlyKeyEventHandler(_onEarlyKeyEvent);
  }

  @override
  void didUpdateWidget(CommonPopupBox oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncItemFocus();
  }

  void _syncItemFocus() {
    while (_itemFocus.length < widget.popup.items.length) {
      _itemFocus.add(FocusNode(debugLabel: 'Menu item ${_itemFocus.length}'));
    }
    if (_itemFocus.length > widget.popup.items.length) {
      final removed = _itemFocus.sublist(widget.popup.items.length);
      _itemFocus.removeRange(widget.popup.items.length, _itemFocus.length);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        for (final node in removed) {
          node.dispose();
        }
      });
    }
  }

  @override
  void dispose() {
    _disposing = true;
    FocusManager.instance.removeEarlyKeyEventHandler(_onEarlyKeyEvent);
    final history = _historyEntry;
    _historyEntry = null;
    history?.remove();
    _ownTriggerFocus.dispose();
    _triggerStates.dispose();
    for (final node in _itemFocus) {
      node.dispose();
    }
    super.dispose();
  }

  void _setKeyboardNavigation(bool value) {
    if (_keyboardNavigation == value) return;
    setState(() => _keyboardNavigation = value);
  }

  KeyEventResult _onEarlyKeyEvent(KeyEvent event) {
    // Observe keys before button/menu shortcuts consume Enter or arrow keys.
    if ((event is KeyDownEvent || event is KeyRepeatEvent) &&
        (_triggerFocus.hasFocus || _itemFocus.any((node) => node.hasFocus))) {
      _setKeyboardNavigation(true);
    }
    return KeyEventResult.ignored;
  }

  void _onPointerInteraction(PointerEvent _) => _setKeyboardNavigation(false);

  void _toggle() {
    if (_controller.isOpen) {
      _controller.close();
    } else if (widget.popup.items.isNotEmpty) {
      _triggerFocus.requestFocus();
      _controller.open();
    }
  }

  void _onOpen() {
    if (_disposing) return;
    _triggerStates.update(WidgetState.pressed, true);
    final route = ModalRoute.of(context);
    if (route != null) {
      late LocalHistoryEntry entry;
      entry = LocalHistoryEntry(
        impliesAppBarDismissal: false,
        onRemove: () {
          if (identical(_historyEntry, entry)) {
            _historyEntry = null;
            if (_controller.isOpen) _controller.close();
          }
        },
      );
      _historyEntry = entry;
      route.addLocalHistoryEntry(entry);
    }
  }

  void _onClose() {
    final history = _historyEntry;
    _historyEntry = null;
    history?.remove();
    if (!_disposing) _triggerStates.update(WidgetState.pressed, false);
  }

  void _focusItem(int index) {
    _itemFocus[index].requestFocus();
    final context = _itemFocus[index].context;
    if (context != null) {
      unawaited(Scrollable.ensureVisible(context,
          alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd));
    }
  }

  KeyEventResult _onItemKey(FocusNode _, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final enabled = [
      for (var i = 0; i < widget.popup.items.length; i++)
        if (widget.popup.items[i].onPressed != null) i,
    ];
    if (enabled.isEmpty) return KeyEventResult.ignored;
    if (event.logicalKey == LogicalKeyboardKey.home ||
        event.logicalKey == LogicalKeyboardKey.end) {
      _focusItem(event.logicalKey == LogicalKeyboardKey.home
          ? enabled.first
          : enabled.last);
      return KeyEventResult.handled;
    }
    final letter = event.character?.toLowerCase();
    if (HardwareKeyboard.instance.isControlPressed ||
        HardwareKeyboard.instance.isAltPressed ||
        HardwareKeyboard.instance.isMetaPressed ||
        letter == null ||
        letter.runes.length != 1 ||
        letter.runes.first <= 32) {
      return KeyEventResult.ignored;
    }
    final current = _itemFocus.indexWhere((node) => node.hasFocus);
    for (var step = 1; step <= _itemFocus.length; step++) {
      final index = (current + step) % _itemFocus.length;
      if (enabled.contains(index) &&
          widget.popup.items[index].label
              .trimLeft()
              .toLowerCase()
              .startsWith(letter)) {
        _focusItem(index);
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) => Focus(
        canRequestFocus: false,
        skipTraversal: true,
        onKeyEvent: (_, event) {
          if (event is! KeyDownEvent) return KeyEventResult.ignored;
          if (_controller.isOpen &&
              event.logicalKey == LogicalKeyboardKey.escape) {
            _controller.close();
            return KeyEventResult.handled;
          }
          if (!_controller.isOpen &&
              (event.logicalKey == LogicalKeyboardKey.arrowDown ||
                  event.logicalKey == LogicalKeyboardKey.arrowUp)) {
            _toggle();
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: MenuAnchor(
          controller: _controller,
          childFocusNode: _triggerFocus,
          useRootOverlay: true,
          crossAxisUnconstrained: false,
          consumeOutsideTap: true,
          alignmentOffset: widget.alignmentOffset,
          clipBehavior: Clip.antiAlias,
          onOpen: _onOpen,
          onClose: _onClose,
          style: widget.popup.menuStyle(context),
          menuChildren: widget.popup.buildItems(context,
              focusNodes: _itemFocus,
              onKeyEvent: _onItemKey,
              showFocusHighlight: _keyboardNavigation,
              onPointerInteraction: _onPointerInteraction),
          builder: (_, controller, __) => CallbackShortcuts(
            bindings: {
              const SingleActivator(LogicalKeyboardKey.arrowDown): () {
                if (!controller.isOpen) _toggle();
              },
              const SingleActivator(LogicalKeyboardKey.arrowUp): () {
                if (!controller.isOpen) _toggle();
              },
            },
            child: Listener(
              onPointerDown: _onPointerInteraction,
              onPointerHover: _onPointerInteraction,
              child:
                  widget.targetBuilder(_toggle, _triggerFocus, _triggerStates),
            ),
          ),
        ),
      );
}

class CommonPopupMenu {
  const CommonPopupMenu({
    required this.items,
    this.minWidth = 200,
  });
  final List<PopupMenuItemData> items;
  final double minWidth;

  MenuStyle menuStyle(BuildContext context) => MenuStyle(
        backgroundColor: WidgetStatePropertyAll(
          Theme.of(context).colorScheme.surfaceContainerLow,
        ),
        // Material elevation level 2 is 3dp.
        elevation: const WidgetStatePropertyAll(3),
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        ),
        visualDensity: VisualDensity.standard,
        minimumSize: WidgetStatePropertyAll(Size(minWidth, 0)),
        maximumSize: const WidgetStatePropertyAll(Size(320, double.infinity)),
        shape: const WidgetStatePropertyAll(
          RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(16))),
        ),
      );

  List<Widget> buildItems(
    BuildContext context, {
    List<FocusNode>? focusNodes,
    FocusOnKeyEventCallback? onKeyEvent,
    bool showFocusHighlight = true,
    ValueChanged<PointerEvent>? onPointerInteraction,
  }) {
    final colors = Theme.of(context).colorScheme;
    final firstEnabled = items.indexWhere((item) => item.onPressed != null);
    return [
      for (var index = 0; index < items.length; index++)
        Listener(
          onPointerDown: onPointerInteraction,
          onPointerHover: onPointerInteraction,
          child: Focus(
            canRequestFocus: false,
            skipTraversal: true,
            onKeyEvent: onKeyEvent,
            child: MergeSemantics(
                child: Semantics(
              selected: items[index].selected,
              child: MenuItemButton(
                focusNode: focusNodes?[index],
                autofocus: index == firstEnabled,
                onPressed: items[index].onPressed,
                overflowAxis: Axis.vertical,
                style: ButtonStyle(
                  visualDensity: VisualDensity.standard,
                  minimumSize: const WidgetStatePropertyAll(Size(0, 48)),
                  padding: const WidgetStatePropertyAll(
                      EdgeInsets.symmetric(horizontal: 12, vertical: 12)),
                  backgroundColor: WidgetStateProperty.resolveWith((states) =>
                      (items[index].selected ?? false) &&
                              !states.contains(WidgetState.disabled)
                          ? colors.tertiaryContainer
                          : Colors.transparent),
                  foregroundColor: WidgetStateProperty.resolveWith(
                      (states) => states.contains(WidgetState.disabled)
                          ? colors.onSurface.withValues(alpha: 0.38)
                          : (items[index].selected ?? false)
                              ? colors.onTertiaryContainer
                              : colors.onSurface),
                  overlayColor: WidgetStateProperty.resolveWith((states) {
                    if (states.contains(WidgetState.disabled)) {
                      return Colors.transparent;
                    }
                    final color = (items[index].selected ?? false)
                        ? colors.onTertiaryContainer
                        : colors.onSurface;
                    if (states.contains(WidgetState.pressed) ||
                        (showFocusHighlight &&
                            states.contains(WidgetState.focused))) {
                      return color.withValues(alpha: 0.1);
                    }
                    if (states.contains(WidgetState.hovered)) {
                      return color.withValues(alpha: 0.08);
                    }
                    return Colors.transparent;
                  }),
                  side: WidgetStateProperty.resolveWith((states) =>
                      showFocusHighlight && states.contains(WidgetState.focused)
                          ? BorderSide(color: colors.secondary, width: 2)
                          : BorderSide.none),
                  shape: WidgetStatePropertyAll(RoundedRectangleBorder(
                    borderRadius: (items[index].selected ?? false)
                        ? BorderRadius.circular(12)
                        : BorderRadius.vertical(
                            top: Radius.circular(index == 0 ? 12 : 4),
                            bottom: Radius.circular(
                                index == items.length - 1 ? 12 : 4)),
                  )),
                  textStyle: WidgetStatePropertyAll(
                      Theme.of(context).textTheme.bodyLarge),
                ),
                child: _MenuItemContent(item: items[index]),
              ),
            )),
          ),
        ),
    ];
  }
}

class _MenuItemContent extends StatelessWidget {
  const _MenuItemContent({required this.item});
  final PopupMenuItemData item;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final enabled = item.onPressed != null;
    final iconColor = !enabled
        ? colors.onSurface.withValues(alpha: 0.38)
        : (item.selected ?? false)
            ? colors.onTertiaryContainer
            : colors.onSurfaceVariant;
    final leading = item.iconWidget ??
        (item.icon == null ? null : Icon(item.icon, size: 20));
    return Row(children: [
      if (leading != null) ...[
        ExcludeSemantics(
            child: IconTheme(
          data: IconThemeData(size: 20, color: iconColor),
          child:
              SizedBox.square(dimension: 20, child: FittedBox(child: leading)),
        )),
        const SizedBox(width: 8),
      ],
      Expanded(child: Text(item.label)),
      if (item.selected != null) ...[
        const SizedBox(width: 8),
        SizedBox.square(
            dimension: 20,
            child: (item.selected ?? false)
                ? ExcludeSemantics(
                    child:
                        Icon(Icons.check_rounded, size: 20, color: iconColor))
                : null),
      ],
    ]);
  }
}
