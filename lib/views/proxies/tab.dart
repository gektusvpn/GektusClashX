import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gektusclashx/common/common.dart';
import 'package:gektusclashx/models/models.dart';
import 'package:gektusclashx/providers/providers.dart';
import 'package:gektusclashx/state.dart';
import 'package:gektusclashx/widgets/widgets.dart';

import 'card.dart';
import 'common.dart';

class ProxiesTabView extends ConsumerStatefulWidget {
  const ProxiesTabView({super.key, this.isAndroidTV = false});

  final bool isAndroidTV;

  @override
  ConsumerState<ProxiesTabView> createState() => ProxiesTabViewState();
}

class ProxiesTabViewState extends ConsumerState<ProxiesTabView>
    with TickerProviderStateMixin {
  TabController? _tabController;
  final _tabsScrollController = ScrollController();
  final _tabFocusNodes = <String, FocusNode>{};
  final _hasMoreButtonNotifier = ValueNotifier<bool>(false);

  @override
  void initState() {
    super.initState();
    _tabsScrollController.addListener(_updateTabsOverflow);
    _handleTabListen();
  }

  @override
  void dispose() {
    _destroyTabController();
    _tabsScrollController
      ..removeListener(_updateTabsOverflow)
      ..dispose();
    for (final focusNode in _tabFocusNodes.values) {
      focusNode.dispose();
    }
    _tabFocusNodes.clear();
    _hasMoreButtonNotifier.dispose();
    super.dispose();
  }

  void _syncTabFocusNodes(List<String> groupNames) {
    final removedNames = _tabFocusNodes.keys.toSet()..removeAll(groupNames);
    for (final groupName in removedNames) {
      final removed = _tabFocusNodes.remove(groupName);
      if (removed != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) => removed.dispose());
      }
    }
    for (final groupName in groupNames) {
      _tabFocusNodes.putIfAbsent(
        groupName,
        () => FocusNode(debugLabel: 'TV proxy tab: $groupName'),
      );
    }
  }

  void _updateTabsOverflow() {
    if (!_tabsScrollController.hasClients) return;
    _hasMoreButtonNotifier.value =
        _tabsScrollController.position.maxScrollExtent > 0;
  }

  void _scheduleTabsOverflowUpdate() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _updateTabsOverflow();
    });
  }

  Consumer _buildMoreButton() => Consumer(
        builder: (_, ref, ___) {
          final isMobileView = ref.watch(isMobileViewProvider);
          return IconButton(
            onPressed: _showMoreMenu,
            icon: isMobileView
                ? const Icon(
                    Icons.expand_more,
                  )
                : const Icon(
                    Icons.chevron_right,
                  ),
          );
        },
      );

  void _showMoreMenu() {
    unawaited(
      showSheet(
        context: context,
        props: const SheetProps(
          isScrollControlled: false,
        ),
        builder: (_, type) => AdaptiveSheetScaffold(
          type: type,
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Consumer(
              builder: (_, ref, __) {
                final state = ref.watch(proxiesSelectorStateProvider);
                return SizedBox(
                  width: double.infinity,
                  child: Wrap(
                    alignment: WrapAlignment.center,
                    runSpacing: 8,
                    spacing: 8,
                    children: [
                      for (final groupName in state.groupNames)
                        SettingTextCard(
                          groupName,
                          onPressed: () {
                            final index = state.groupNames.indexWhere(
                              (item) => item == groupName,
                            );
                            if (index == -1) return;
                            _tabController?.index = index;
                            globalState.appController
                                .updateCurrentGroupName(groupName);
                            Navigator.of(context).pop();
                          },
                          isSelected: groupName == state.currentGroupName,
                        )
                    ],
                  ),
                );
              },
            ),
          ),
          title: appLocalizations.proxyGroup,
        ),
      ),
    );
  }

  Widget _buildTVTabs(
    List<String> groupNames,
    List<Group> groups,
    String? currentGroupName,
  ) {
    _scheduleTabsOverflowUpdate();
    return SizedBox(
      height: 48,
      child: ValueListenableBuilder(
        valueListenable: _hasMoreButtonNotifier,
        builder: (_, hasOverflow, moreButton) => Stack(
          alignment: AlignmentDirectional.centerStart,
          children: [
            SingleChildScrollView(
              controller: _tabsScrollController,
              scrollDirection: Axis.horizontal,
              padding: EdgeInsetsDirectional.only(
                start: 16,
                end: hasOverflow ? 56 : 16,
                top: 8,
                bottom: 8,
              ),
              child: Row(
                children: [
                  for (var index = 0; index < groupNames.length; index++) ...[
                    if (index > 0) const SizedBox(width: 8),
                    Focus(
                        canRequestFocus: false,
                        onKeyEvent: (_, event) {
                          if (index == 0 &&
                              (event is KeyDownEvent ||
                                  event is KeyRepeatEvent) &&
                              event.logicalKey ==
                                  LogicalKeyboardKey.arrowLeft) {
                            focusTVNavigationDrawer();
                            return KeyEventResult.handled;
                          }
                          return KeyEventResult.ignored;
                        },
                        child: _TVProxyTab(
                          label: groupNames[index],
                          icon: groups.getGroup(groupNames[index])?.icon ?? '',
                          focusNode: _tabFocusNodes[groupNames[index]]!,
                          selected: groupNames[index] == currentGroupName ||
                              (currentGroupName == null && index == 0),
                          onPressed: () {
                            if (_tabController?.index != index) {
                              _tabController?.index = index;
                            }
                            if (currentGroupName != groupNames[index]) {
                              globalState.appController.updateCurrentGroupName(
                                groupNames[index],
                              );
                            }
                          },
                        )),
                  ],
                ],
              ),
            ),
            if (hasOverflow)
              PositionedDirectional(
                end: 0,
                child: moreButton!,
              ),
          ],
        ),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: AlignmentDirectional.centerStart,
              end: AlignmentDirectional.centerEnd,
              colors: [
                context.colorScheme.surface.withValues(alpha: 0.1),
                context.colorScheme.surface,
              ],
              stops: const [0, 0.18],
            ),
          ),
          child: _buildMoreButton(),
        ),
      ),
    );
  }

  void _tabControllerListener([int? index]) {
    var groupIndex = index;
    if (groupIndex == -1) {
      return;
    }
    final appController = globalState.appController;
    if (groupIndex == null) {
      final currentIndex = _tabController?.index;
      groupIndex = currentIndex;
    }
    final currentGroups = appController.getCurrentGroups();
    if (groupIndex == null || groupIndex >= currentGroups.length) {
      return;
    }
    final currentGroup = currentGroups[groupIndex];
    WidgetsBinding.instance.addPostFrameCallback((_) {
      globalState.appController.updateCurrentGroupName(
        currentGroup.name,
      );
    });
  }

  void _destroyTabController() {
    _tabController?.removeListener(_tabControllerListener);
    _tabController?.dispose();
    _tabController = null;
  }

  void _updateTabController(int length, int index) {
    if (length == 0) {
      _destroyTabController();
      return;
    }
    final realIndex = index == -1 ? 0 : index;
    _tabController ??= TabController(
      length: length,
      initialIndex: realIndex,
      vsync: this,
    );
    _tabControllerListener(realIndex);
    _tabController?.addListener(_tabControllerListener);
  }

  void _handleTabListen() {
    ref.listenManual(
      proxiesSelectorStateProvider,
      (prev, next) {
        if (prev == next) {
          return;
        }
        if (!stringListEquality.equals(prev?.groupNames, next.groupNames)) {
          _syncTabFocusNodes(next.groupNames);
          _destroyTabController();
          final index = next.groupNames.indexWhere(
            (item) => item == next.currentGroupName,
          );
          _updateTabController(next.groupNames.length, index);
        }
      },
      fireImmediately: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(themeSettingProvider.select((state) => state.textScale));
    final state = ref.watch(groupNamesStateProvider);
    final groupNames = state.groupNames;
    final groups = ref.watch(currentGroupsStateProvider).value;
    final currentGroupName = ref.watch(
      proxiesSelectorStateProvider.select((state) => state.currentGroupName),
    );
    if (groupNames.isEmpty) {
      return NullStatus(
        label: appLocalizations.nullTip(appLocalizations.proxies),
      );
    }
    final children = groupNames
        .map((groupName) => KeepScope(
              child: ProxyGroupView(
                key: ValueKey(groupName),
                groupName: groupName,
                isAndroidTV: widget.isAndroidTV,
                onMoveToTabs: widget.isAndroidTV
                    ? () => _tabFocusNodes[groupName]?.requestFocus()
                    : null,
              ),
            ))
        .toList();
    return Column(
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.isAndroidTV)
          _buildTVTabs(groupNames, groups, currentGroupName)
        else
          NotificationListener<ScrollMetricsNotification>(
            onNotification: (scrollNotification) {
              _hasMoreButtonNotifier.value =
                  scrollNotification.metrics.maxScrollExtent > 0;
              return true;
            },
            child: ValueListenableBuilder(
              valueListenable: _hasMoreButtonNotifier,
              builder: (_, value, child) => Stack(
                alignment: AlignmentDirectional.centerStart,
                children: [
                  TabBar(
                    controller: _tabController,
                    padding: EdgeInsets.only(
                      left: 16,
                      right: 16 + (value ? 16 : 0),
                    ),
                    dividerColor: Colors.transparent,
                    isScrollable: true,
                    tabAlignment: TabAlignment.start,
                    overlayColor:
                        const WidgetStatePropertyAll(Colors.transparent),
                    tabs: [
                      for (final groupName in groupNames) Tab(text: groupName),
                    ],
                  ),
                  if (value)
                    Positioned(
                      right: 0,
                      child: child!,
                    ),
                ],
              ),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [
                        context.colorScheme.surface.opacity10,
                        context.colorScheme.surface,
                      ],
                      stops: const [
                        0.0,
                        0.1
                      ]),
                ),
                child: _buildMoreButton(),
              ),
            ),
          ),
        Expanded(
          child: widget.isAndroidTV
              ? ProxyGroupView(
                  key: ValueKey(currentGroupName ?? groupNames.first),
                  groupName: groupNames.contains(currentGroupName)
                      ? currentGroupName!
                      : groupNames.first,
                  isAndroidTV: true,
                  onMoveToTabs: () =>
                      _tabFocusNodes[currentGroupName ?? groupNames.first]
                          ?.requestFocus(),
                )
              : TabBarView(controller: _tabController, children: children),
        )
      ],
    );
  }
}

class _TVProxyTab extends StatelessWidget {
  const _TVProxyTab({
    required this.label,
    required this.icon,
    required this.focusNode,
    required this.selected,
    required this.onPressed,
  });

  final String label;
  final String icon;
  final FocusNode focusNode;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 32,
        child: TextButton(
          focusNode: focusNode,
          onPressed: onPressed,
          onFocusChange: (focused) {
            if (!focused) return;
            onPressed();
            revealTVFocus(context);
          },
          style: ButtonStyle(
            minimumSize: const WidgetStatePropertyAll(Size.zero),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            padding: const WidgetStatePropertyAll(
              EdgeInsetsDirectional.fromSTEB(12, 6, 16, 6),
            ),
            shape: const WidgetStatePropertyAll(StadiumBorder()),
            overlayColor: const WidgetStatePropertyAll(Colors.transparent),
            backgroundColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.focused)) {
                return context.colorScheme.primary;
              }
              if (selected) return context.colorScheme.secondaryContainer;
              return Colors.transparent;
            }),
            foregroundColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.focused)) {
                return context.colorScheme.onPrimary;
              }
              if (selected) return context.colorScheme.onSecondaryContainer;
              return context.colorScheme.onSurfaceVariant;
            }),
            textStyle: WidgetStatePropertyAll(
              context.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CommonTargetIcon(src: icon, size: 18),
              const SizedBox(width: 6),
              Text(label),
            ],
          ),
        ),
      );
}

class ProxyGroupView extends ConsumerStatefulWidget {
  const ProxyGroupView({
    super.key,
    required this.groupName,
    this.isAndroidTV = false,
    this.onMoveToTabs,
  });
  final String groupName;
  final bool isAndroidTV;
  final VoidCallback? onMoveToTabs;

  @override
  ConsumerState<ProxyGroupView> createState() => ProxyGroupViewState();
}

class ProxyGroupViewState extends ConsumerState<ProxyGroupView> {
  final _controller = ScrollController();

  String get groupName => widget.groupName;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(proxyGroupSelectorStateProvider(groupName));
    final proxies = state.proxies;
    final columns = widget.isAndroidTV ? 3 : state.columns;
    final proxyCardType = state.proxyCardType;
    final sortedProxies = globalState.appController.getSortProxies(
      proxies,
      state.testUrl,
    );
    return Align(
      alignment: Alignment.topCenter,
      child: CommonAutoHiddenScrollBar(
        controller: _controller,
        child: GridView.builder(
          controller: _controller,
          padding: EdgeInsets.only(
            top: widget.isAndroidTV ? 12 : 16,
            left: 16,
            right: 16,
            bottom: widget.isAndroidTV
                ? 24
                : MediaQuery.paddingOf(context).bottom + 16,
          ),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisSpacing: widget.isAndroidTV ? 20 : 8,
            crossAxisSpacing: widget.isAndroidTV ? 20 : 8,
            mainAxisExtent: getItemHeight(proxyCardType),
          ),
          itemCount: sortedProxies.length,
          itemBuilder: (_, index) {
            final proxy = sortedProxies[index];
            final card = ProxyCard(
              testUrl: state.testUrl,
              groupType: state.groupType,
              type: proxyCardType,
              key: ValueKey('$groupName.${proxy.name}'),
              proxy: proxy,
              groupName: groupName,
              isAndroidTV: widget.isAndroidTV,
            );
            if (!widget.isAndroidTV) return card;
            return Focus(
              canRequestFocus: false,
              onKeyEvent: (_, event) {
                if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
                  return KeyEventResult.ignored;
                }
                if (index % columns == 0 &&
                    event.logicalKey == LogicalKeyboardKey.arrowLeft) {
                  focusTVNavigationDrawer();
                  return KeyEventResult.handled;
                }
                if (index < columns &&
                    event.logicalKey == LogicalKeyboardKey.arrowUp) {
                  widget.onMoveToTabs?.call();
                  return KeyEventResult.handled;
                }
                return KeyEventResult.ignored;
              },
              child: card,
            );
          },
        ),
      ),
    );
  }
}
