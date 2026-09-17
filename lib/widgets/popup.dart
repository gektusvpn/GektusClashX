import 'package:flutter/material.dart';
import 'package:gektusclashx/models/common.dart';

typedef PopupOpen = void Function();

/// Anchors a Material 3 menu to its trigger and keeps it inside the viewport.
class CommonPopupBox extends StatelessWidget {
  const CommonPopupBox({
    super.key,
    required this.targetBuilder,
    required this.popup,
  });
  final Widget Function(PopupOpen open) targetBuilder;
  final CommonPopupMenu popup;

  @override
  Widget build(BuildContext context) => MenuAnchor(
        useRootOverlay: true,
        consumeOutsideTap: true,
        alignmentOffset: const Offset(0, 4),
        clipBehavior: Clip.antiAlias,
        style: popup.menuStyle(context),
        menuChildren: popup.buildItems(context),
        builder: (_, controller, __) => targetBuilder(() {
          if (controller.isOpen) {
            controller.close();
          } else {
            controller.open();
          }
        }),
      );
}

class CommonPopupMenu {
  const CommonPopupMenu({
    required this.items,
    this.minWidth = 200,
    this.fontSize = 15,
  });
  final List<PopupMenuItemData> items;
  final double minWidth;
  final double fontSize;

  MenuStyle menuStyle(BuildContext context) => MenuStyle(
        backgroundColor: WidgetStatePropertyAll(
          Theme.of(context).colorScheme.surfaceContainer,
        ),
        elevation: const WidgetStatePropertyAll(3),
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(vertical: 8),
        ),
        minimumSize: WidgetStatePropertyAll(Size(minWidth, 0)),
        maximumSize: const WidgetStatePropertyAll(Size(320, double.infinity)),
        shape: WidgetStatePropertyAll(
          RoundedSuperellipseBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
      );

  List<Widget> buildItems(BuildContext context) => [
        for (final item in items)
          MenuItemButton(
            onPressed: item.onPressed,
            leadingIcon: item.iconWidget ??
                (item.icon == null ? null : Icon(item.icon, size: 24)),
            style: ButtonStyle(
              minimumSize: WidgetStatePropertyAll(Size(minWidth, 48)),
              padding: const WidgetStatePropertyAll(
                EdgeInsets.symmetric(horizontal: 16),
              ),
              shape: WidgetStatePropertyAll(
                RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              textStyle: WidgetStatePropertyAll(
                Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontSize: fontSize,
                      fontWeight: FontWeight.w500,
                    ),
              ),
            ),
            child: Text(item.label),
          ),
      ];
}
