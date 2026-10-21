import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gektusclashx/common/common.dart';
import 'package:gektusclashx/enum/enum.dart';
import 'package:gektusclashx/models/models.dart';
import 'package:gektusclashx/providers/providers.dart';
import 'package:gektusclashx/state.dart';
import 'package:gektusclashx/views/profiles/add_profile.dart';
import 'package:gektusclashx/widgets/widgets.dart';

Future<void> showTVProfileSwitcher(BuildContext context) =>
    Navigator.of(context).push<void>(
        MaterialPageRoute(builder: (_) => const TVProfileSwitcher()));

class TVProfileSwitcher extends ConsumerStatefulWidget {
  const TVProfileSwitcher({super.key});

  @override
  ConsumerState<TVProfileSwitcher> createState() => _TVProfileSwitcherState();
}

class _TVProfileSwitcherState extends ConsumerState<TVProfileSwitcher> {
  final _profileNodes = <String, FocusNode>{};
  final _addNode = FocusNode(debugLabel: 'TV add profile');
  final _scrollController = ScrollController();
  bool _initialFocusRequested = false;
  String? _focusedProfileId;

  @override
  void dispose() {
    for (final node in _profileNodes.values) {
      node.dispose();
    }
    _addNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _syncProfileNodes(List<Profile> profiles) {
    final ids = profiles.map((profile) => profile.id).toSet();
    for (final id in _profileNodes.keys.toList()) {
      if (ids.contains(id)) continue;
      final removed = _profileNodes.remove(id)!;
      WidgetsBinding.instance.addPostFrameCallback((_) => removed.dispose());
    }
    for (final profile in profiles) {
      _profileNodes.putIfAbsent(
        profile.id,
        () => FocusNode(debugLabel: 'TV profile: ${profile.id}'),
      );
    }
  }

  void _focusProfile(String? id) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final profiles = ref.read(profilesProvider);
      final index = id == null
          ? profiles.length
          : profiles.indexWhere((profile) => profile.id == id);
      if (index < 0) return;
      final node = id == null ? _addNode : _profileNodes[id];
      if (node?.context != null) {
        node!.requestFocus();
        return;
      }
      // Lazy grid rows have no attached FocusNode until they are laid out.
      // Reveal that row first instead of moving focus to the Add card.
      if (!_scrollController.hasClients) return;
      final columns = (profiles.length + 1).clamp(1, 4);
      _scrollController.jumpTo(
        ((index ~/ columns) * 256.0).clamp(
          _scrollController.position.minScrollExtent,
          _scrollController.position.maxScrollExtent,
        ),
      );
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && node?.context != null) node!.requestFocus();
      });
      WidgetsBinding.instance.ensureVisualUpdate();
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  void _openProfile(Profile profile) {
    ref.read(currentProfileIdProvider.notifier).value = profile.id;
    Navigator.of(context).pop();
  }

  Future<void> _deleteProfile(Profile profile) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        constraints: const BoxConstraints(maxWidth: 480),
        title: Text(appLocalizations.delete),
        content: Text(appLocalizations.deleteProfileConfirmation(
          profile.label ?? profile.id,
        )),
        actions: [
          TVActionButton(
            autofocus: true,
            label: appLocalizations.cancel,
            icon: Icons.close_rounded,
            onPressed: () => Navigator.of(context).pop(false),
          ),
          TVActionButton(
            label: appLocalizations.delete,
            icon: Icons.delete_outline_rounded,
            onPressed: () => Navigator.of(context).pop(true),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;
    final index = ref.read(profilesProvider).indexWhere(
          (item) => item.id == profile.id,
        );
    if (index == -1) return;
    await globalState.appController.deleteProfile(profile.id);
    if (!mounted) return;
    final remaining = ref.read(profilesProvider);
    if (remaining.isEmpty) {
      // The QR onboarding is on the home route, underneath this picker.
      globalState.appController.toPage(PageLabel.dashboard);
      Navigator.of(context).pop();
      return;
    }
    _focusProfile(remaining[index.clamp(0, remaining.length - 1)].id);
  }

  void _profileFocused(String? id) {
    if (_focusedProfileId == id) return;
    setState(() => _focusedProfileId = id);
  }

  @override
  Widget build(BuildContext context) {
    final profiles = ref.watch(profilesProvider);
    final currentProfileId = ref.watch(currentProfileIdProvider);
    final columns = (profiles.length + 1).clamp(1, 4);
    _syncProfileNodes(profiles);
    if (!_initialFocusRequested) {
      _initialFocusRequested = true;
      _focusProfile(profiles.getProfile(currentProfileId)?.id ??
          profiles.firstOrNull?.id);
    }

    return Scaffold(
      backgroundColor: context.colorScheme.surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(48, 28, 48, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                appLocalizations.selectProfile,
                style: context.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 24),
              Expanded(
                child: FocusTraversalGroup(
                  policy: ReadingOrderTraversalPolicy(),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: columns * 176 + (columns - 1) * 20 + 16,
                      ),
                      child: GridView.builder(
                        controller: _scrollController,
                        shrinkWrap: true,
                        padding: const EdgeInsets.all(8),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: columns,
                          mainAxisSpacing: 20,
                          crossAxisSpacing: 20,
                          mainAxisExtent: 236,
                        ),
                        itemCount: profiles.length + 1,
                        itemBuilder: (context, index) {
                          if (index == profiles.length) {
                            return Focus(
                              canRequestFocus: false,
                              onKeyEvent: (_, event) {
                                if (profiles.isNotEmpty &&
                                    (event is KeyDownEvent ||
                                        event is KeyRepeatEvent) &&
                                    event.logicalKey ==
                                        LogicalKeyboardKey.arrowLeft) {
                                  _focusProfile(profiles.last.id);
                                  return KeyEventResult.handled;
                                }
                                return KeyEventResult.ignored;
                              },
                              child: Align(
                                alignment: Alignment.topCenter,
                                child: SizedBox(
                                  height: 176,
                                  width: double.infinity,
                                  child: _AddProfileCard(
                                    focusNode: _addNode,
                                    autofocus: profiles.isEmpty,
                                    onFocused: () => _profileFocused(null),
                                    onPressed: () => unawaited(
                                      showAddProfileSheet(context),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }
                          final profile = profiles[index];
                          final isSelected = profile.id == currentProfileId;
                          return Focus(
                            key: ValueKey(profile.id),
                            canRequestFocus: false,
                            onFocusChange: (focused) {
                              if (focused) _profileFocused(profile.id);
                            },
                            // Left/right always go to a neighbouring profile,
                            // including when its action buttons have focus.
                            onKeyEvent: (_, event) {
                              if (event is! KeyDownEvent &&
                                  event is! KeyRepeatEvent) {
                                return KeyEventResult.ignored;
                              }
                              final delta = switch (event.logicalKey) {
                                LogicalKeyboardKey.arrowLeft => -1,
                                LogicalKeyboardKey.arrowRight => 1,
                                _ => 0,
                              };
                              if (delta == 0) return KeyEventResult.ignored;
                              final target = index + delta;
                              if (target >= 0 && target <= profiles.length) {
                                _focusProfile(target == profiles.length
                                    ? null
                                    : profiles[target].id);
                              }
                              return KeyEventResult.handled;
                            },
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                SizedBox(
                                  height: 176,
                                  child: _ProfileCard(
                                    focusNode: _profileNodes[profile.id]!,
                                    profile: profile,
                                    selected: isSelected,
                                    autofocus: isSelected ||
                                        (index == 0 &&
                                            profiles.getProfile(
                                                    currentProfileId) ==
                                                null),
                                    onPressed: () => _openProfile(profile),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Visibility(
                                  visible: _focusedProfileId == profile.id,
                                  maintainState: true,
                                  maintainAnimation: true,
                                  maintainSize: true,
                                  child: TVActionButton(
                                    label: appLocalizations.delete,
                                    icon: Icons.delete_outline_rounded,
                                    onPressed: () => unawaited(
                                      _deleteProfile(profile),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({
    required this.focusNode,
    required this.profile,
    required this.selected,
    required this.autofocus,
    required this.onPressed,
  });

  final Profile profile;
  final FocusNode focusNode;
  final bool selected;
  final bool autofocus;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final logoUrl = decodeServiceLogoUrl(
      profile.providerHeaders['gektusclashx-servicelogo'],
    );
    return TVFocusEffect(
      enabled: true,
      borderRadius: BorderRadius.circular(16),
      child: OutlinedButton(
        focusNode: focusNode,
        autofocus: autofocus,
        onPressed: onPressed,
        onFocusChange: (focused) {
          if (focused) revealTVFocus(context);
        },
        style: tvButtonStyle(context, selected: selected, radius: 16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                ClipOval(
                  child: SizedBox.square(
                    dimension: 76,
                    child: ColoredBox(
                      color: context.colorScheme.primaryContainer,
                      child: ServiceLogoImage(url: logoUrl),
                    ),
                  ),
                ),
                if (selected)
                  PositionedDirectional(
                    end: -4,
                    bottom: -4,
                    child: CircleAvatar(
                      radius: 13,
                      backgroundColor: context.colorScheme.primary,
                      foregroundColor: context.colorScheme.onPrimary,
                      child: const Icon(Icons.check_rounded, size: 18),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              profile.label ?? profile.id,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 16,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddProfileCard extends StatelessWidget {
  const _AddProfileCard({
    required this.focusNode,
    required this.autofocus,
    required this.onPressed,
    required this.onFocused,
  });

  final bool autofocus;
  final FocusNode focusNode;
  final VoidCallback onPressed;
  final VoidCallback onFocused;

  @override
  Widget build(BuildContext context) => TVFocusEffect(
        enabled: true,
        borderRadius: BorderRadius.circular(16),
        child: OutlinedButton(
          focusNode: focusNode,
          autofocus: autofocus,
          onPressed: onPressed,
          onFocusChange: (focused) {
            if (focused) {
              onFocused();
              revealTVFocus(context);
            }
          },
          style: tvButtonStyle(context, radius: 16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.add_rounded,
                size: 56,
              ),
              const SizedBox(height: 12),
              Text(
                appLocalizations.addProfile,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 16),
              ),
            ],
          ),
        ),
      );
}
