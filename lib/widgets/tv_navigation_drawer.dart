import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gektusclashx/common/common.dart';
import 'package:gektusclashx/enum/enum.dart';
import 'package:gektusclashx/models/models.dart';
import 'package:gektusclashx/providers/providers.dart';
import 'package:gektusclashx/state.dart';
import 'package:gektusclashx/views/profiles/tv_profile_switcher.dart';

import 'tv_controls.dart';

typedef TVNavigationLabelBuilder = String Function(PageLabel label);

FocusNode? _activeTVDestinationFocusNode;
bool _tvNavigationDrawerHasFocus = false;
FocusScopeNode? _activeTVContentScope;

bool focusTVPageContent() {
  final scope = _activeTVContentScope;
  if (scope == null) return false;
  final remembered = scope.focusedChild;
  if (remembered != null && remembered.canRequestFocus) {
    remembered.requestFocus();
    return true;
  }
  final target = ReadingOrderTraversalPolicy()
      .findFirstFocus(scope, ignoreCurrentFocus: true);
  if (target == null || target == scope) return false;
  target.requestFocus();
  return true;
}

/// Keeps each TV destination's focus history independent of the drawer.
class TVPageFocus extends StatefulWidget {
  const TVPageFocus({super.key, required this.active, required this.child});
  final bool active;
  final Widget child;

  @override
  State<TVPageFocus> createState() => _TVPageFocusState();
}

class _TVPageFocusState extends State<TVPageFocus> {
  final _scope = FocusScopeNode(debugLabel: 'TV destination content');

  @override
  void dispose() {
    if (_activeTVContentScope == _scope) _activeTVContentScope = null;
    _scope.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.active) _activeTVContentScope = _scope;
    return ExcludeFocus(
      excluding: !widget.active,
      child: FocusScope(node: _scope, child: widget.child),
    );
  }
}

bool get isTVNavigationDrawerFocused => _tvNavigationDrawerHasFocus;

/// Moves focus from page content to the active destination in the TV drawer.
/// Returns false when focus is already inside the drawer.
bool focusTVNavigationDrawer() {
  if (_tvNavigationDrawerHasFocus) return false;
  final node = _activeTVDestinationFocusNode;
  if (node == null || !node.canRequestFocus) return false;
  node.requestFocus();
  return true;
}

/// The left edge of a content row leads back to the active drawer item.
class TVDrawerEdge extends StatelessWidget {
  const TVDrawerEdge({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Focus(
        canRequestFocus: false,
        onKeyEvent: (_, event) {
          if ((event is KeyDownEvent || event is KeyRepeatEvent) &&
              event.logicalKey == LogicalKeyboardKey.arrowLeft &&
              focusTVNavigationDrawer()) {
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: child,
      );
}

/// TV navigation drawer that overlays content when expanded.
///
/// It stays as an icon rail until focus enters it, then reveals labels. The
/// profile entry is a switcher, while the middle and bottom entries are app
/// destinations.
class TVNavigationDrawer extends ConsumerStatefulWidget {
  const TVNavigationDrawer({
    super.key,
    required this.navigationItems,
    required this.currentIndex,
    required this.labelBuilder,
  });

  final List<NavigationItem> navigationItems;
  final int currentIndex;
  final TVNavigationLabelBuilder labelBuilder;

  @override
  ConsumerState<TVNavigationDrawer> createState() => _TVNavigationDrawerState();
}

class _TVNavigationDrawerState extends ConsumerState<TVNavigationDrawer> {
  bool _expanded = false;
  bool _returningToProfile = false;
  final _profileFocusNode = FocusNode(debugLabel: 'TV switch profile');
  final _destinationFocusNodes = <PageLabel, FocusNode>{};

  void _syncDestinationFocusNodes(List<NavigationItem> items) {
    final labels = items.map((item) => item.label).toSet();
    final removedLabels = _destinationFocusNodes.keys.toSet()
      ..removeAll(labels);
    for (final label in removedLabels) {
      final removed = _destinationFocusNodes.remove(label);
      if (removed != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) => removed.dispose());
      }
    }
    for (final item in items) {
      _destinationFocusNodes.putIfAbsent(
        item.label,
        () => FocusNode(debugLabel: 'TV drawer: ${item.label.name}'),
      );
    }
  }

  @override
  void didUpdateWidget(covariant TVNavigationDrawer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_expanded && oldWidget.currentIndex != widget.currentIndex) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_expanded) return;
        _activeTVDestinationFocusNode?.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    if (_destinationFocusNodes.values.contains(
      _activeTVDestinationFocusNode,
    )) {
      _activeTVDestinationFocusNode = null;
      _tvNavigationDrawerHasFocus = false;
    }
    _profileFocusNode.dispose();
    for (final node in _destinationFocusNodes.values) {
      node.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _syncDestinationFocusNodes(widget.navigationItems);
    _activeTVDestinationFocusNode = _destinationFocusNodes[
        widget.navigationItems[widget.currentIndex].label];
    final profile = ref.watch(currentProfileProvider);
    final primaryItems = widget.navigationItems
        .where((item) => item.label != PageLabel.tools)
        .toList();
    final settingsItem = widget.navigationItems
        .where((item) => item.label == PageLabel.tools)
        .firstOrNull;

    return Focus(
      canRequestFocus: false,
      onKeyEvent: (_, event) {
        if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
          return KeyEventResult.ignored;
        }
        final key = event.logicalKey;
        if (key == LogicalKeyboardKey.arrowRight) {
          focusTVPageContent();
          return KeyEventResult.handled;
        }
        if (key == LogicalKeyboardKey.arrowLeft) return KeyEventResult.handled;
        if (key == LogicalKeyboardKey.arrowUp ||
            key == LogicalKeyboardKey.arrowDown) {
          final nodes = [
            _profileFocusNode,
            ...primaryItems.map((item) => _destinationFocusNodes[item.label]!),
            if (settingsItem != null)
              _destinationFocusNodes[settingsItem.label]!,
          ];
          final index = nodes.indexWhere((node) => node.hasFocus);
          if (index >= 0) {
            final next = (index + (key == LogicalKeyboardKey.arrowUp ? -1 : 1))
                .clamp(0, nodes.length - 1);
            nodes[next].requestFocus();
          }
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      onFocusChange: (hasFocus) {
        final focusEnteredDrawer = hasFocus && !_tvNavigationDrawerHasFocus;
        _tvNavigationDrawerHasFocus = hasFocus;
        if (_expanded != hasFocus) setState(() => _expanded = hasFocus);
        if (focusEnteredDrawer && !_returningToProfile) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted || !_expanded) return;
            _activeTVDestinationFocusNode?.requestFocus();
          });
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        width: _expanded ? 280 : 80,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: AlignmentDirectional.centerStart,
            end: AlignmentDirectional.centerEnd,
            colors: _expanded
                ? [
                    context.colorScheme.surfaceContainer,
                    context.colorScheme.surfaceContainer,
                    context.colorScheme.surfaceContainer
                        .withValues(alpha: 0.94),
                    context.colorScheme.surfaceContainer.withValues(alpha: 0),
                  ]
                : List.filled(4, context.colorScheme.surfaceContainer),
            stops: const [0, 0.72, 0.88, 1],
          ),
        ),
        child: SafeArea(
          right: false,
          child: AnimatedPadding(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            padding: EdgeInsetsDirectional.fromSTEB(
              12,
              24,
              _expanded ? 40 : 12,
              24,
            ),
            child: Column(
              children: [
                _TVProfileButton(
                  expanded: _expanded,
                  focusNode: _profileFocusNode,
                  label: profile?.label ?? profile?.id,
                  onPressed: () async {
                    _returningToProfile = true;
                    await showTVProfileSwitcher(context);
                    if (!mounted) return;
                    _profileFocusNode.requestFocus();
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      _returningToProfile = false;
                    });
                  },
                ),
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (var index = 0;
                            index < primaryItems.length;
                            index++) ...[
                          if (index > 0) const SizedBox(height: 12),
                          _TVDestinationButton(
                            item: primaryItems[index],
                            focusNode: _destinationFocusNodes[
                                primaryItems[index].label]!,
                            expanded: _expanded,
                            selected: widget.navigationItems
                                    .indexOf(primaryItems[index]) ==
                                widget.currentIndex,
                            label: widget.labelBuilder(
                              primaryItems[index].label,
                            ),
                            onSelected: () => globalState.appController
                                .toPage(primaryItems[index].label),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                if (settingsItem != null)
                  SizedBox(
                      height: 80,
                      child: Center(
                          child: _TVDestinationButton(
                        item: settingsItem,
                        focusNode: _destinationFocusNodes[settingsItem.label]!,
                        expanded: _expanded,
                        selected:
                            widget.navigationItems.indexOf(settingsItem) ==
                                widget.currentIndex,
                        label: widget.labelBuilder(settingsItem.label),
                        onSelected: () => globalState.appController
                            .toPage(settingsItem.label),
                      ))),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Fixed icon slot keeps the rail icons still throughout drawer expansion.
class _TVNavigationContent extends StatelessWidget {
  const _TVNavigationContent(
      {required this.icon,
      required this.label,
      required this.expanded,
      this.subtitle});
  final Widget icon;
  final String label;
  final String? subtitle;
  final bool expanded;

  @override
  Widget build(BuildContext context) => ClipRect(
        child: OverflowBox(
          alignment: AlignmentDirectional.centerStart,
          minWidth: 228,
          maxWidth: 228,
          child: Row(children: [
            SizedBox(width: 56, child: Center(child: icon)),
            const SizedBox(width: 4),
            Expanded(
                child: AnimatedOpacity(
              opacity: expanded ? 1 : 0,
              duration: const Duration(milliseconds: 140),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w500)),
                  if (subtitle != null) ...[
                    const SizedBox(height: 4),
                    Text(subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w400)),
                  ],
                ],
              ),
            )),
            const SizedBox(width: 12),
          ]),
        ),
      );
}

class _TVProfileButton extends StatelessWidget {
  const _TVProfileButton(
      {required this.expanded,
      required this.focusNode,
      required this.label,
      required this.onPressed});
  final bool expanded;
  final FocusNode focusNode;
  final String? label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 80,
        child: Semantics(
          label: label ?? appLocalizations.selectProfile,
          hint: appLocalizations.switchProfile,
          child: TextButton(
            focusNode: focusNode,
            onPressed: onPressed,
            style: tvButtonStyle(context, transparent: true, radius: 16)
                .copyWith(
                    padding: const WidgetStatePropertyAll(EdgeInsets.zero)),
            child: _TVNavigationContent(
              expanded: expanded,
              label: label ?? appLocalizations.profile,
              subtitle: appLocalizations.switchProfile,
              icon: CircleAvatar(
                radius: 22,
                backgroundColor: context.colorScheme.secondaryContainer,
                foregroundColor: context.colorScheme.onSecondaryContainer,
                child: const Icon(Icons.person_outline_rounded, size: 28),
              ),
            ),
          ),
        ),
      );
}

class _TVDestinationButton extends StatelessWidget {
  const _TVDestinationButton(
      {required this.item,
      required this.focusNode,
      required this.expanded,
      required this.selected,
      required this.label,
      required this.onSelected});
  final NavigationItem item;
  final FocusNode focusNode;
  final bool expanded;
  final bool selected;
  final String label;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) => Semantics(
        label: expanded ? null : label,
        button: true,
        selected: selected,
        child: SizedBox(
          height: 48,
          width: double.infinity,
          child: TextButton(
            focusNode: focusNode,
            onPressed: onSelected,
            style: tvButtonStyle(context, selected: selected, transparent: true)
                .copyWith(
                    padding: const WidgetStatePropertyAll(EdgeInsets.zero)),
            child: _TVNavigationContent(
              expanded: expanded,
              label: label,
              icon: IconTheme.merge(
                  data: const IconThemeData(size: 24), child: item.icon),
            ),
          ),
        ),
      );
}
