import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gektusclashx/common/common.dart';
import 'package:gektusclashx/enum/enum.dart';
import 'package:gektusclashx/models/models.dart';
import 'package:gektusclashx/providers/app.dart';
import 'package:gektusclashx/providers/config.dart';
import 'package:gektusclashx/providers/state.dart';
import 'package:gektusclashx/state.dart';
import 'package:gektusclashx/widgets/widgets.dart';

import 'card.dart';
import 'common.dart';

typedef GroupNameProxiesMap = Map<String, List<Proxy>>;

const _proxyGroupExpansionDuration = Duration(milliseconds: 360);

class ProxiesListView extends StatefulWidget {
  const ProxiesListView({super.key});

  @override
  State<ProxiesListView> createState() => _ProxiesListViewState();
}

class _ProxiesListViewState extends State<ProxiesListView> {
  final _controller = ScrollController();
  final _headerStateNotifier = ValueNotifier<ProxiesListHeaderSelectorState>(
    const ProxiesListHeaderSelectorState(
      offset: 0,
      currentIndex: 0,
    ),
  );
  final List<double> _headerOffset = [];
  GroupNameProxiesMap _lastGroupNameProxiesMap = {};

  int _lastGroupsVersion = 0;
  List<String> _lastGroupNames = [];

  @override
  void initState() {
    super.initState();
    _controller.addListener(_adjustHeader);
  }

  void _adjustHeader() {
    final offset = _controller.offset;
    final index = _headerOffset.findInterval(offset);
    final currentIndex = index;
    var headerOffset = 0.0;
    if (index + 1 <= _headerOffset.length - 1) {
      final endOffset = _headerOffset[index + 1];
      final startOffset = endOffset - listHeaderHeight - 8;
      if (offset > startOffset && offset < endOffset) {
        headerOffset = offset - startOffset;
      }
    }
    _headerStateNotifier.value = _headerStateNotifier.value.copyWith(
      currentIndex: currentIndex,
      offset: max(headerOffset, 0),
    );
  }

  @override
  void dispose() {
    _headerStateNotifier.dispose();
    _controller
      ..removeListener(_adjustHeader)
      ..dispose();
    super.dispose();
  }

  List<Widget> _buildItems(
    WidgetRef ref, {
    required List<String> groupNames,
    required int columns,
    required ProxyCardType type,
    required String query,
  }) {
    final items = <Widget>[];
    final groupNameProxiesMap = <String, List<Proxy>>{};
    final groups = <Group>[];
    for (final groupName in groupNames) {
      final group = ref.watch(
        groupsProvider.select(
          (state) => state.getGroup(groupName),
        ),
      );
      if (group != null) groups.add(group);
    }

    for (var groupIndex = 0; groupIndex < groups.length; groupIndex++) {
      final group = groups[groupIndex];
      final groupName = group.name;
      final sortedProxies = globalState.appController.getSortProxies(
        group.all
            .where((item) => item.name.toLowerCase().contains(query))
            .toList(),
        group.testUrl,
      );
      groupNameProxiesMap[groupName] = sortedProxies;
      final chunks = sortedProxies.chunks(columns);
      final rows = chunks
          .map<Widget>((proxies) {
            final children = proxies
                .map<Widget>(
                  (proxy) => Flexible(
                    flex: 1,
                    child: RepaintBoundary(
                      child: ProxyCard(
                        testUrl: group.testUrl,
                        type: type,
                        groupType: group.type,
                        key: ValueKey('$groupName.${proxy.name}'),
                        proxy: proxy,
                        groupName: groupName,
                      ),
                    ),
                  ),
                )
                .fill(
                  columns,
                  filler: (_) => const Flexible(
                    child: SizedBox(),
                  ),
                )
                .separated(
                  const SizedBox(
                    width: 8,
                  ),
                );

            return Row(
              children: children.toList(),
            );
          })
          .separated(
            SizedBox(
              height: type == ProxyCardType.oneline ? 4 : 8,
            ),
          )
          .toList();
      items.add(
        ProxyGroupCard(
          key: ValueKey(groupName),
          group: group,
          proxies: rows,
          isFirst: groupIndex == 0,
          isLast: groupIndex == groups.length - 1,
        ),
      );
    }
    _lastGroupNameProxiesMap = groupNameProxiesMap;
    return items;
  }

  @override
  Widget build(BuildContext context) => Consumer(
        builder: (_, ref, __) {
          final state = ref.watch(proxiesListSelectorStateProvider);

          final groupsVersion = ref.watch(versionProvider);

          ref.watch(themeSettingProvider.select((state) => state.textScale));

          if (_lastGroupsVersion != groupsVersion ||
              !listEquals(_lastGroupNames, state.groupNames)) {
            _lastGroupsVersion = groupsVersion;
            _lastGroupNames = state.groupNames;

            _lastGroupNameProxiesMap.clear();

            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                setState(() {});
              }
            });
          }

          if (state.groupNames.isEmpty) {
            return NullStatus(
              label: appLocalizations.nullTip(appLocalizations.proxies),
            );
          }
          final items = _buildItems(
            ref,
            groupNames: state.groupNames,
            columns: state.columns,
            type: state.proxyCardType,
            query: state.query,
          );
          return RepaintBoundary(
            child: CommonScrollBar(
              controller: _controller,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: ScrollConfiguration(
                      behavior: HiddenBarScrollBehavior(),
                      child: FocusTraversalGroup(
                        policy: WidgetOrderTraversalPolicy(),
                        child: ListView.builder(
                          padding: EdgeInsets.fromLTRB(
                            16,
                            16,
                            16,
                            MediaQuery.paddingOf(context).bottom + 16,
                          ),
                          controller: _controller,
                          itemCount: items.length,
                          itemBuilder: (_, index) => items[index],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
}

class ProxyGroupCard extends StatefulWidget {
  const ProxyGroupCard({
    super.key,
    required this.group,
    required this.proxies,
    required this.isFirst,
    required this.isLast,
  });
  final Group group;
  final List<Widget> proxies;
  final bool isFirst;
  final bool isLast;

  @override
  State<ProxyGroupCard> createState() => _ProxyGroupCardState();
}

class _ProxyGroupCardState extends State<ProxyGroupCard>
    with AutomaticKeepAliveClientMixin {
  final _expansibleController = ExpansibleController();

  bool isLock = false;

  String get icon => widget.group.icon;

  String get groupName => widget.group.name;

  @override
  void dispose() {
    _expansibleController.dispose();
    super.dispose();
  }

  void _toggleExpansion(Set<String> currentUnfoldSet) {
    final appController = globalState.appController;
    final unfoldSet = Set<String>.from(currentUnfoldSet);

    if (_expansibleController.isExpanded) {
      _expansibleController.collapse();
      unfoldSet.remove(groupName);
    } else {
      _expansibleController.expand();
      unfoldSet.add(groupName);
    }
    appController.updateCurrentUnfoldSet(unfoldSet);
  }

  Future<void> _delayTest() async {
    if (isLock) return;
    isLock = true;
    await delayTest(
      widget.group.all,
      widget.group.testUrl,
    );
    isLock = false;
  }

  Widget _buildIcon() => Consumer(
        builder: (_, ref, child) {
          final iconStyle = ref.watch(
            proxiesStyleSettingProvider.select(
              (state) => state.iconStyle,
            ),
          );
          final icon = ref.watch(proxiesStyleSettingProvider.select((state) {
            final iconMapEntryList = state.iconMap.entries.toList();
            final index = iconMapEntryList.indexWhere((item) {
              try {
                return RegExp(item.key).hasMatch(groupName);
              } catch (_) {
                return false;
              }
            });
            if (index != -1) {
              return iconMapEntryList[index].value;
            }
            return this.icon;
          }));
          return switch (iconStyle) {
            ProxiesIconStyle.icon => Container(
                margin: const EdgeInsets.only(
                  right: 16,
                ),
                child: LayoutBuilder(
                  builder: (_, constraints) => CommonTargetIcon(
                    src: icon,
                    size: 38,
                  ),
                ),
              ),
            ProxiesIconStyle.none => Container(),
          };
        },
      );

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final colorScheme = context.colorScheme;
    return Consumer(
      builder: (_, ref, __) {
        final unfoldSet = ref.watch(unfoldSetProvider);
        final shouldExpand = unfoldSet.contains(groupName);

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (shouldExpand && !_expansibleController.isExpanded) {
            _expansibleController.expand();
          } else if (!shouldExpand && _expansibleController.isExpanded) {
            _expansibleController.collapse();
          }
        });

        return RepaintBoundary(
          // No per-group FocusTraversalGroup: wrapping each card in its own
          // traversal group made every group a membrane the D-pad had to step
          // out of and back into, costing an extra press to cross between groups.
          // The whole list shares the outer group (ProxiesListView), so
          // directional nav flows straight through; ExcludeFocus still keeps a
          // folded group's hidden proxies out of the traversal.
          child: Expansible(
            controller: _expansibleController,
            animationStyle: const AnimationStyle(
              duration: _proxyGroupExpansionDuration,
              curve: Curves.easeOutCubic,
              reverseCurve: Curves.easeInCubic,
            ),
            headerBuilder: (context, animation) => GestureDetector(
              onTap: () => _toggleExpansion(unfoldSet),
              child: AnimatedContainer(
                duration: _proxyGroupExpansionDuration,
                curve: Curves.easeOutCubic,
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerLow.opacity80,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(widget.isFirst ? 24 : 6),
                    topRight: Radius.circular(widget.isFirst ? 24 : 6),
                    bottomLeft: Radius.circular(
                      shouldExpand ? 6 : (widget.isLast ? 24 : 6),
                    ),
                    bottomRight: Radius.circular(
                      shouldExpand ? 6 : (widget.isLast ? 24 : 6),
                    ),
                  ),
                ),
                margin: EdgeInsets.only(
                  bottom: widget.isLast && !shouldExpand ? 0 : 2,
                ),
                padding: const EdgeInsets.symmetric(
                  vertical: 10.0,
                  horizontal: 16.0,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Row(
                        children: [
                          _buildIcon(),
                          Flexible(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  groupName,
                                  style: context.textTheme.titleMedium,
                                ),
                                const SizedBox(height: 4),
                                Flexible(
                                  flex: 1,
                                  child: Consumer(
                                    builder: (_, ref, __) {
                                      final proxyName = ref
                                          .watch(getSelectedProxyNameProvider(
                                              groupName))
                                          .getSafeValue("");
                                      if (proxyName.isEmpty) {
                                        return const SizedBox.shrink();
                                      }
                                      return EmojiText(
                                        overflow: TextOverflow.ellipsis,
                                        proxyName,
                                        style: context
                                            .textTheme.labelMedium?.toLight,
                                      );
                                    },
                                  ),
                                ),
                                const SizedBox(width: 4),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Row(
                      children: [
                        // Ping the whole group straight from the header —
                        // available while collapsed too (previously expand-only),
                        // which also gives the TV D-pad a focus target on a
                        // folded group.
                        //
                        // Both header buttons share the exact same box so their
                        // top/bottom edges line up. With a D-pad, a vertical press
                        // then can't land on the horizontal sibling (which had a
                        // taller filled-tonal box), so up/down moves straight to
                        // the next/previous group in one press; left/right switches
                        // between ping and expand within the group.
                        IconButton(
                          tooltip: appLocalizations.testAllDelay,
                          onPressed: _delayTest,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints.tightFor(
                            width: 40,
                            height: 40,
                          ),
                          style: IconButton.styleFrom(
                            foregroundColor: colorScheme.onSurfaceVariant
                                .withValues(alpha: 0.72),
                          ),
                          icon: const Icon(Icons.network_ping),
                        ),
                        const SizedBox(width: 6),
                        IconButton.filledTonal(
                          onPressed: () => _toggleExpansion(unfoldSet),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints.tightFor(
                              width: 40, height: 40),
                          icon: RotationTransition(
                            turns: Tween<double>(begin: 0, end: 0.5).animate(
                              animation,
                            ),
                            child: const Icon(Icons.expand_more),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            bodyBuilder: (context, animation) => ExcludeFocus(
              // A collapsed group keeps its proxy cards mounted — SizeTransition
              // only clips them to zero height — and every card is a focusable
              // OutlinedButton. On Android TV the D-pad would otherwise dive into
              // these invisible cards, so the highlight jitters and looks like it
              // skips whole groups. Drop the folded body from focus traversal.
              excluding: !shouldExpand,
              child: RepaintBoundary(
                child: FadeTransition(
                  opacity: animation,
                  child: Container(
                    margin: EdgeInsets.only(bottom: widget.isLast ? 0 : 2),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerLow.opacity80,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(6),
                        topRight: const Radius.circular(6),
                        bottomLeft: Radius.circular(widget.isLast ? 24 : 6),
                        bottomRight: Radius.circular(widget.isLast ? 24 : 6),
                      ),
                    ),
                    child: Column(children: widget.proxies),
                  ),
                ),
              ),
            ),
            expansibleBuilder: (context, header, body, animation) =>
                Column(children: [header, body]),
          ),
        );
      },
    );
  }

  @override
  bool get wantKeepAlive => true;
}
