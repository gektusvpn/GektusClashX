import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gektusclashx/clash/clash.dart';
import 'package:gektusclashx/common/common.dart';
import 'package:gektusclashx/enum/enum.dart';
import 'package:gektusclashx/models/models.dart';
import 'package:gektusclashx/providers/providers.dart';
import 'package:gektusclashx/state.dart';
import 'package:gektusclashx/views/proxies/list.dart';
import 'package:gektusclashx/views/proxies/providers.dart';
import 'package:gektusclashx/widgets/widgets.dart';

import 'common.dart';
import 'setting.dart';
import 'tab.dart';

class ProxiesView extends ConsumerStatefulWidget {
  const ProxiesView({super.key});

  @override
  ConsumerState<ProxiesView> createState() => _ProxiesViewState();
}

class _ProxiesViewState extends ConsumerState<ProxiesView> with PageMixin {
  bool _hasProviders = false;
  bool _isTab = false;

  Future<void> _pingAllGroups() async {
    // Fan out the per-group delay test (the same path the per-group ping button uses
    // and is known to update every member) across all groups in parallel — each group
    // tests its OWN full member list with its OWN test URL. This is both parallel and
    // correct, unlike collecting a flat unique list where group names only resolve to
    // their active member and inactive hosts (e.g. in SERVERS) never get tested.
    final groups = ref.read(currentGroupsStateProvider).value;
    if (groups.isEmpty) {
      await clashCore.healthCheck();
      return;
    }
    await Future.wait(
      groups.map((group) => delayTest(group.all, group.testUrl)),
    );
  }

  @override
  List<Widget> get actions => [
        Consumer(
          builder: (_, ref, child) {
            final globalModeEnabled = ref.watch(globalModeEnabledProvider);
            if (!globalModeEnabled) return const SizedBox.shrink();
            return child!;
          },
          child: const _ModeSelectorAction(),
        ),
        if (!_isTab) ...[
          Consumer(
            builder: (_, ref, __) {
              final unfoldSet = ref.watch(unfoldSetProvider);
              final groupNames = ref.watch(
                currentGroupsStateProvider.select(
                  (state) => state.value.map((e) => e.name).toList(),
                ),
              );
              final allExpanded =
                  groupNames.isNotEmpty && groupNames.every(unfoldSet.contains);
              return IconButton(
                tooltip: allExpanded
                    ? appLocalizations.collapseAll
                    : appLocalizations.expandAll,
                onPressed: () {
                  if (allExpanded) {
                    globalState.appController.updateCurrentUnfoldSet({});
                  } else {
                    globalState.appController
                        .updateCurrentUnfoldSet(groupNames.toSet());
                  }
                },
                icon: Icon(
                  allExpanded ? Icons.unfold_less : Icons.unfold_more,
                ),
              );
            },
          ),
        ],
        CommonPopupBox(
          targetBuilder: (open) => IconButton(
            onPressed: open,
            icon: const Icon(
              Icons.more_vert,
            ),
          ),
          popup: CommonPopupMenu(
            items: [
              PopupMenuItemData(
                icon: Icons.network_ping,
                label: appLocalizations.testAllDelay,
                onPressed: () => unawaited(_pingAllGroups()),
              ),
              PopupMenuItemData(
                icon: Icons.tune,
                label: appLocalizations.settings,
                onPressed: () => unawaited(
                  showSheet(
                    context: context,
                    props: const SheetProps(
                      isScrollControlled: true,
                    ),
                    builder: (_, type) => AdaptiveSheetScaffold(
                      type: type,
                      body: const ProxiesSetting(),
                      title: appLocalizations.settings,
                    ),
                  ),
                ),
              ),
              if (_hasProviders)
                PopupMenuItemData(
                  icon: Icons.poll_outlined,
                  label: appLocalizations.providers,
                  onPressed: () => unawaited(
                    showExtend(
                      context,
                      builder: (_, type) => const ProvidersView(),
                    ),
                  ),
                ),
              if (!_isTab)
                PopupMenuItemData(
                  icon: Icons.style_outlined,
                  label: appLocalizations.iconConfiguration,
                  onPressed: () => unawaited(
                    showExtend(
                      context,
                      builder: (_, type) => const _IconConfigView(),
                    ),
                  ),
                ),
            ],
          ),
        )
      ];

  @override
  void initState() {
    ref.listenManual(
      proxiesActionsStateProvider,
      fireImmediately: true,
      (prev, next) {
        if (prev == next) {
          return;
        }
        if (next.pageLabel == PageLabel.proxies) {
          _hasProviders = next.hasProviders;
          _isTab = next.type == ProxiesType.tab;
          initPageState();
          return;
        }
      },
    );
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final proxiesType = ref.watch(
      proxiesStyleSettingProvider.select(
        (state) => state.type,
      ),
    );
    return switch (proxiesType) {
      ProxiesType.tab => const ProxiesTabView(),
      ProxiesType.list => const ProxiesListView(),
    };
  }
}

class _ModeSelectorAction extends ConsumerWidget {
  const _ModeSelectorAction();

  String _modeLabel(BuildContext context, Mode mode) => switch (mode) {
        Mode.rule => appLocalizations.rule,
        Mode.global => appLocalizations.global,
        Mode.direct => appLocalizations.direct,
      };

  IconData _modeIcon(Mode mode) => switch (mode) {
        Mode.rule => Icons.rule,
        Mode.global => Icons.public,
        Mode.direct => Icons.flash_on,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(
      patchClashConfigProvider.select((state) => state.mode),
    );

    return CommonPopupBox(
      targetBuilder: (open) => IconButton(
        tooltip: appLocalizations.action_mode,
        onPressed: open,
        icon: Icon(_modeIcon(mode)),
      ),
      popup: CommonPopupMenu(
        items: [
          for (final item in Mode.values.where((m) => m != Mode.direct))
            PopupMenuItemData(
              icon: _modeIcon(item),
              label: _modeLabel(context, item),
              onPressed: () {
                globalState.appController.changeMode(item);
              },
            ),
        ],
      ),
    );
  }
}

class _IconConfigView extends ConsumerWidget {
  const _IconConfigView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final iconMap = ref.watch(proxiesStyleSettingProvider.select(
      (state) => state.iconMap,
    ));
    return CommonScaffold(
      title: appLocalizations.iconConfiguration,
      body: MapInputPage(
        title: appLocalizations.iconConfiguration,
        map: iconMap,
        keyLabel: appLocalizations.regExp,
        valueLabel: appLocalizations.icon,
        titleBuilder: (item) => Text(item.key),
        leadingBuilder: (item) => Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
          ),
          clipBehavior: Clip.antiAlias,
          child: CommonTargetIcon(
            src: item.value,
            size: 42,
          ),
        ),
        subtitleBuilder: (item) => Text(
          item.value,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        onChange: (value) {
          ref.read(proxiesStyleSettingProvider.notifier).updateState(
                (state) => state.copyWith(
                  iconMap: value,
                ),
              );
        },
      ),
    );
  }
}
