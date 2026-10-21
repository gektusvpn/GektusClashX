import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gektusclashx/common/common.dart';
import 'package:gektusclashx/enum/enum.dart';
import 'package:gektusclashx/models/models.dart';
import 'package:gektusclashx/providers/providers.dart';
import 'package:gektusclashx/state.dart';

import 'scaffold.dart';
import 'side_sheet.dart';

@immutable
class SheetProps {
  const SheetProps({
    this.maxWidth,
    this.maxHeight,
    this.fitContent = false,
    this.useSafeArea = true,
    this.isScrollControlled = false,
    this.blur = true,
  });
  final double? maxWidth;
  final double? maxHeight;

  /// Let TV dialogs shrink to their contents within [maxHeight].
  final bool fitContent;
  final bool isScrollControlled;
  final bool useSafeArea;
  final bool blur;
}

@immutable
class ExtendProps {
  const ExtendProps({
    this.maxWidth,
    this.useSafeArea = true,
    this.blur = true,
  });
  final double? maxWidth;
  final bool useSafeArea;
  final bool blur;
}

enum SheetType {
  page,
  bottomSheet,
  sideSheet,
  tvDialog,
}

typedef SheetBuilder = Widget Function(BuildContext context, SheetType type);

Future<T?> showSheet<T>({
  required BuildContext context,
  required SheetBuilder builder,
  SheetProps props = const SheetProps(),
}) async {
  final isTV = await ProviderScope.containerOf(context, listen: false)
      .read(isAndroidTVProvider.future);
  if (!context.mounted) return null;
  if (isTV) {
    return _showTVSheet(context, builder, props.maxWidth,
        height: props.maxHeight ?? 440, fitContent: props.fitContent);
  }
  final isMobile = globalState.appState.viewMode == ViewMode.mobile;
  return switch (isMobile) {
    true => showModalBottomSheet<T>(
        context: context,
        isScrollControlled: props.isScrollControlled,
        backgroundColor: Colors.transparent,
        builder: (_) => BackdropFilter(
          filter: props.blur ? commonFilter : ImageFilter.blur(),
          child: SafeArea(
            child: builder(context, SheetType.bottomSheet),
          ),
        ),
        showDragHandle: false,
        useSafeArea: props.useSafeArea,
      ),
    false => showModalSideSheet<T>(
        useSafeArea: props.useSafeArea,
        isScrollControlled: props.isScrollControlled,
        context: context,
        constraints: BoxConstraints(
          maxWidth: props.maxWidth ?? 360,
        ),
        filter: props.blur ? commonFilter : null,
        builder: (_) => builder(context, SheetType.sideSheet),
      ),
  };
}

Future<T?> showExtend<T>(
  BuildContext context, {
  required SheetBuilder builder,
  ExtendProps props = const ExtendProps(),
}) async {
  final isTV = await ProviderScope.containerOf(context, listen: false)
      .read(isAndroidTVProvider.future);
  if (!context.mounted) return null;
  if (isTV) {
    return _showTVSheet(context, builder, props.maxWidth);
  }
  final isMobile = globalState.appState.viewMode == ViewMode.mobile;
  return switch (isMobile) {
    true => BaseNavigator.push(
        context,
        builder(context, SheetType.page),
      ),
    false => showModalSideSheet<T>(
        useSafeArea: props.useSafeArea,
        context: context,
        constraints: BoxConstraints(
          maxWidth: props.maxWidth ?? 360,
        ),
        filter: props.blur ? commonFilter : null,
        builder: (context) => builder(context, SheetType.sideSheet),
      ),
  };
}

Future<T?> _showTVSheet<T>(
        BuildContext context, SheetBuilder builder, double? maxWidth,
        {double height = 440, bool fitContent = false}) =>
    showDialog<T>(
      context: context,
      barrierColor: Colors.black54,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 48, vertical: 28),
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: SizedBox(
          width: (maxWidth ?? 640).clamp(480.0, 800.0),
          height: fitContent ? null : height,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: height),
            child: builder(context, SheetType.tvDialog),
          ),
        ),
      ),
    );

class AdaptiveSheetScaffold extends ConsumerStatefulWidget {
  const AdaptiveSheetScaffold({
    super.key,
    required this.type,
    required this.body,
    required this.title,
    this.actions = const [],
    this.disableBackground = true,
    this.fitContent = false,
  });
  final SheetType type;
  final Widget body;
  final String title;
  final List<Widget> actions;
  final bool disableBackground;
  final bool fitContent;

  @override
  ConsumerState<AdaptiveSheetScaffold> createState() =>
      _AdaptiveSheetScaffoldState();
}

class _AdaptiveSheetScaffoldState extends ConsumerState<AdaptiveSheetScaffold> {
  final _tvScope = FocusScopeNode(debugLabel: 'TV sheet content');

  @override
  void initState() {
    super.initState();
    if (widget.type == SheetType.tvDialog) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ReadingOrderTraversalPolicy()
            .findFirstFocus(_tvScope, ignoreCurrentFocus: true)
            ?.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    _tvScope.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    if (widget.type == SheetType.tvDialog) {
      return Material(
        color: colorScheme.surfaceContainerHigh,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
              mainAxisSize:
                  widget.fitContent ? MainAxisSize.min : MainAxisSize.max,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
                  child: Row(children: [
                    Expanded(
                        child: Text(widget.title,
                            style: context.textTheme.headlineSmall)),
                    ...widget.actions,
                  ]),
                ),
                Flexible(
                  fit: widget.fitContent ? FlexFit.loose : FlexFit.tight,
                  child: FocusScope(node: _tvScope, child: widget.body),
                ),
              ]),
        ),
      );
    }
    final isAndroidTV = ref.watch(isAndroidTVProvider).valueOrNull ?? false;
    final bottomSheet = widget.type == SheetType.bottomSheet;
    final sideSheet = widget.type == SheetType.sideSheet;
    final backgroundColor = sideSheet
        ? colorScheme.surface.withValues(alpha: 0.92)
        : colorScheme.surface.withValues(alpha: 0.92);
    final appBar = AppBar(
      forceMaterialTransparency: bottomSheet ? true : false,
      automaticallyImplyLeading: isAndroidTV
          ? false
          : bottomSheet
              ? false
              : widget.actions.isEmpty && sideSheet
                  ? false
                  : true,
      centerTitle: bottomSheet,
      backgroundColor: backgroundColor,
      title: Text(
        widget.title,
        style: context.textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
        ),
      ),
      actions: genActions([
        if (!isAndroidTV && widget.actions.isEmpty && sideSheet)
          const CloseButton(),
        ...widget.actions,
      ]),
    );
    if (bottomSheet) {
      const handleSize = Size(32, 4);
      return Container(
        clipBehavior: Clip.hardEdge,
        decoration: ShapeDecoration(
          color: backgroundColor,
          shape: const RoundedSuperellipseBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(28.0)),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Container(
                alignment: Alignment.center,
                height: handleSize.height,
                width: handleSize.width,
                decoration: ShapeDecoration(
                  shape: RoundedSuperellipseBorder(
                    borderRadius: BorderRadius.circular(handleSize.height / 2),
                  ),
                  color: context.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            appBar,
            Flexible(
              flex: 1,
              child: widget.body,
            )
          ],
        ),
      );
    }
    return CommonScaffold(
      appBar: appBar,
      backgroundColor: backgroundColor,
      body: widget.body,
      disableBackground: widget.disableBackground,
    );
  }
}
