import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gektusclashx/clash/core.dart';
import 'package:gektusclashx/common/common.dart';
import 'package:gektusclashx/common/yaml_dump.dart';
import 'package:gektusclashx/enum/enum.dart';
import 'package:gektusclashx/l10n/l10n.dart';
import 'package:gektusclashx/models/models.dart';
import 'package:gektusclashx/pages/editor.dart';
import 'package:gektusclashx/providers/providers.dart';
import 'package:gektusclashx/state.dart';
import 'package:gektusclashx/views/about.dart';
import 'package:gektusclashx/views/access.dart';
import 'package:gektusclashx/views/application_setting.dart';
import 'package:gektusclashx/views/config/config.dart';
import 'package:gektusclashx/views/hotkey.dart';
import 'package:gektusclashx/widgets/widgets.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' show dirname, join;
import 'package:re_editor/re_editor.dart';
import 'package:re_highlight/languages/yaml.dart';
import 'package:re_highlight/styles/atom-one-dark.dart';
import 'package:re_highlight/styles/atom-one-light.dart';

import 'backup_and_recovery.dart';
import 'developer.dart';
import 'theme.dart';

class ToolsView extends ConsumerStatefulWidget {
  const ToolsView({super.key});

  @override
  ConsumerState<ToolsView> createState() => _ToolboxViewState();
}

class _ToolboxViewState extends ConsumerState<ToolsView> {
  ListItem<dynamic> _buildNavigationMenuItem(NavigationItem navigationItem) =>
      ListItem.open(
        leading: _SettingsLeading(child: navigationItem.icon),
        title: Text(Intl.message(navigationItem.label.name)),
        subtitle: navigationItem.description != null
            ? Text(Intl.message(navigationItem.description!))
            : null,
        trailing: const _SettingsChevron(),
        delegate: OpenDelegate(
          title: Intl.message(navigationItem.label.name),
          widget: navigationItem.view,
        ),
      );

  @override
  Widget build(BuildContext context) {
    final vm2 = ref.watch(
      appSettingProvider.select(
        (state) => VM2(a: state.locale, b: state.developerMode),
      ),
    );
    final appLocale = AppLocalizations.of(context);
    final navigationItems = ref.watch(
      moreToolsSelectorStateProvider.select((state) => state.navigationItems),
    );
    final networkNavigationItems = navigationItems
        .where(
          (item) =>
              item.label == PageLabel.connections ||
              item.label == PageLabel.resources,
        )
        .toList();
    final systemNavigationItems = navigationItems
        .where(
          (item) =>
              item.label != PageLabel.connections &&
              item.label != PageLabel.resources,
        )
        .toList();

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        _SettingsSection(
          title: appLocale.app,
          children: [
            const _LocaleItem(),
            const _ThemeItem(),
            const _SettingItem(),
            if (system.isDesktop) const _HotkeyItem(),
            const _BackupItem(),
            const _InfoItem(),
          ],
        ),
        _SettingsSection(
          title: appLocale.network,
          children: [
            for (final item in networkNavigationItems)
              _buildNavigationMenuItem(item),
            if (Platform.isAndroid) const _AccessItem(),
            if (Platform.isWindows) const _LoopbackItem(),
            const _ConfigItem(),
          ],
        ),
        _SettingsSection(
          title: appLocale.system,
          children: [
            const _RuntimeConfigItem(),
            for (final item in systemNavigationItems)
              _buildNavigationMenuItem(item),
            const _CoreStatusItem(),
            if (vm2.b) const _DeveloperItem(),
          ],
        ),
      ],
    );
  }
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({this.title, required this.children});

  final String? title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    const outerRadius = Radius.circular(24);
    const innerRadius = Radius.circular(6);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
              child: Text(
                title!,
                style: context.textTheme.labelLarge?.copyWith(
                  color: context.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          for (var index = 0; index < children.length; index++)
            Padding(
              padding: EdgeInsets.only(
                bottom: index == children.length - 1 ? 0 : 2,
              ),
              child: Material(
                color: context.colorScheme.surfaceContainerHigh
                    .withValues(alpha: 0.88),
                shape: RoundedSuperellipseBorder(
                  borderRadius: BorderRadius.only(
                    topLeft: index == 0 ? outerRadius : innerRadius,
                    topRight: index == 0 ? outerRadius : innerRadius,
                    bottomLeft: index == children.length - 1
                        ? outerRadius
                        : innerRadius,
                    bottomRight: index == children.length - 1
                        ? outerRadius
                        : innerRadius,
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: ListTileTheme.merge(
                  minTileHeight: 72,
                  titleAlignment: ListTileTitleAlignment.center,
                  child: children[index],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SettingsLeading extends StatelessWidget {
  const _SettingsLeading({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
        width: 40,
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: context.colorScheme.secondaryContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: IconTheme(
          data: IconThemeData(
            size: 24,
            color: context.colorScheme.onSecondaryContainer,
          ),
          child: child,
        ),
      );
}

class _SettingsChevron extends StatelessWidget {
  const _SettingsChevron();

  @override
  Widget build(BuildContext context) => Icon(
        Icons.chevron_right_rounded,
        color: context.colorScheme.onSurfaceVariant,
      );
}

class _LocaleItem extends ConsumerWidget {
  const _LocaleItem();

  String _getLocaleString(BuildContext context, Locale? locale) {
    if (locale == null) return AppLocalizations.of(context).defaultText;
    return Intl.message(locale.toString());
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appLocale = AppLocalizations.of(context);
    final locale =
        ref.watch(appSettingProvider.select((state) => state.locale));
    final subTitle = locale ?? appLocale.defaultText;
    final currentLocale = utils.getLocaleForString(locale);
    return ListItem<Locale?>.options(
      leading: const _SettingsLeading(
        child: Icon(Icons.language_rounded),
      ),
      title: Text(appLocale.language),
      subtitle: Text(Intl.message(subTitle)),
      trailing: Icon(
        Icons.expand_more_rounded,
        color: context.colorScheme.onSurfaceVariant,
      ),
      delegate: OptionsDelegate(
        title: appLocale.language,
        options: [null, ...AppLocalizations.delegate.supportedLocales],
        onChanged: (locale) {
          ref.read(appSettingProvider.notifier).updateState(
                (state) => state.copyWith(locale: locale?.toString()),
              );
        },
        textBuilder: (locale) => _getLocaleString(context, locale),
        value: currentLocale,
      ),
    );
  }
}

class _ThemeItem extends StatelessWidget {
  const _ThemeItem();

  @override
  Widget build(BuildContext context) {
    final appLocale = AppLocalizations.of(context);
    return ListItem.open(
      leading: const _SettingsLeading(
        child: Icon(Icons.palette_outlined),
      ),
      title: Text(appLocale.theme),
      subtitle: Text(appLocale.themeDesc),
      trailing: const _SettingsChevron(),
      delegate: OpenDelegate(
        title: appLocale.theme,
        widget: const ThemeView(),
      ),
    );
  }
}

class _BackupItem extends StatelessWidget {
  const _BackupItem();

  @override
  Widget build(BuildContext context) {
    final appLocale = AppLocalizations.of(context);
    return ListItem.open(
      leading: const _SettingsLeading(
        child: Icon(Icons.cloud_sync_outlined),
      ),
      title: Text(appLocale.backupAndRecovery),
      subtitle: Text(appLocale.backupAndRecoveryDesc),
      trailing: const _SettingsChevron(),
      delegate: OpenDelegate(
        title: appLocale.backupAndRecovery,
        widget: const BackupAndRecovery(),
      ),
    );
  }
}

class _HotkeyItem extends StatelessWidget {
  const _HotkeyItem();

  @override
  Widget build(BuildContext context) {
    final appLocale = AppLocalizations.of(context);
    return ListItem.open(
      leading: const _SettingsLeading(
        child: Icon(Icons.keyboard_rounded),
      ),
      title: Text(appLocale.hotkeyManagement),
      subtitle: Text(appLocale.hotkeyManagementDesc),
      trailing: const _SettingsChevron(),
      delegate: OpenDelegate(
        title: appLocale.hotkeyManagement,
        widget: const HotKeyView(),
      ),
    );
  }
}

class _LoopbackItem extends StatelessWidget {
  const _LoopbackItem();

  @override
  Widget build(BuildContext context) {
    final appLocale = AppLocalizations.of(context);
    return ListItem(
      leading: const _SettingsLeading(
        child: Icon(Icons.lock_open_rounded),
      ),
      title: Text(appLocale.loopback),
      subtitle: Text(appLocale.loopbackDesc),
      trailing: Icon(
        Icons.open_in_new_rounded,
        color: context.colorScheme.onSurfaceVariant,
      ),
      onTap: () {
        windows?.runas(
          '"${join(dirname(Platform.resolvedExecutable), "EnableLoopback.exe")}"',
          "",
        );
      },
    );
  }
}

class _AccessItem extends StatelessWidget {
  const _AccessItem();

  @override
  Widget build(BuildContext context) {
    final appLocale = AppLocalizations.of(context);
    return ListItem.open(
      leading: const _SettingsLeading(
        child: Icon(Icons.apps_rounded),
      ),
      title: Text(appLocale.accessControl),
      subtitle: Text(appLocale.accessControlDesc),
      trailing: const _SettingsChevron(),
      delegate: OpenDelegate(
        title: appLocale.appAccessControl,
        widget: const AccessView(),
      ),
    );
  }
}

class _ConfigItem extends StatelessWidget {
  const _ConfigItem();

  @override
  Widget build(BuildContext context) {
    final appLocale = AppLocalizations.of(context);
    return ListItem.open(
      leading: const _SettingsLeading(
        child: Icon(Icons.tune_rounded),
      ),
      title: Text(appLocale.basicConfig),
      subtitle: Text(appLocale.basicConfigDesc),
      trailing: const _SettingsChevron(),
      delegate: OpenDelegate(
        title: appLocale.override,
        widget: const ConfigView(),
      ),
    );
  }
}

class _SettingItem extends StatelessWidget {
  const _SettingItem();

  @override
  Widget build(BuildContext context) {
    final appLocale = AppLocalizations.of(context);
    return ListItem.open(
      leading: const _SettingsLeading(
        child: Icon(Icons.settings_rounded),
      ),
      title: Text(appLocale.application),
      subtitle: Text(appLocale.applicationDesc),
      trailing: const _SettingsChevron(),
      delegate: OpenDelegate(
        title: appLocale.application,
        widget: const ApplicationSettingView(),
      ),
    );
  }
}

class _RuntimeConfigItem extends StatelessWidget {
  const _RuntimeConfigItem();

  @override
  Widget build(BuildContext context) {
    final appLocale = AppLocalizations.of(context);
    return ListItem(
      leading: const _SettingsLeading(
        child: Icon(Icons.code_rounded),
      ),
      title: Text(appLocale.runtimeConfig),
      trailing: const _SettingsChevron(),
      onTap: () {
        final config = globalState.lastRuntimeConfig;
        if (config == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(appLocale.runtimeConfigNotAvailable)),
          );
          return;
        }

        final buffer = StringBuffer();
        yamlDump(buffer, config, 0);

        unawaited(
          showExtend(
            context,
            builder: (_, type) => _RuntimeConfigSheet(
              type: type,
              text: buffer.toString(),
            ),
          ),
        );
      },
    );
  }
}

class _RuntimeConfigSheet extends ConsumerStatefulWidget {
  const _RuntimeConfigSheet({required this.type, required this.text});
  final SheetType type;
  final String text;

  @override
  ConsumerState<_RuntimeConfigSheet> createState() =>
      _RuntimeConfigSheetState();
}

class _RuntimeConfigSheetState extends ConsumerState<_RuntimeConfigSheet> {
  late final CodeLineEditingController _controller;
  late final CodeFindController _findController;

  @override
  void initState() {
    super.initState();
    _controller = CodeLineEditingController.fromText(widget.text);
    _findController = CodeFindController(_controller);
  }

  @override
  void dispose() {
    _findController.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isMobileView = ref.watch(isMobileViewProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AdaptiveSheetScaffold(
      type: widget.type,
      title: AppLocalizations.of(context).runtimeConfig,
      actions: [
        IconButton(
          onPressed: _findController.findMode,
          icon: const Icon(Icons.search),
        ),
      ],
      body: CodeEditor(
        readOnly: true,
        controller: _controller,
        findController: _findController,
        findBuilder: (context, controller, readOnly) => FindPanel(
          controller: controller,
          readOnly: readOnly,
          isMobileView: isMobileView,
        ),
        padding: const EdgeInsets.only(right: 16),
        scrollbarBuilder: (context, child, details) => CommonScrollBar(
          controller: details.controller,
          child: child,
        ),
        toolbarController: ContextMenuControllerImpl(editable: false),
        indicatorBuilder: (
          context,
          editingController,
          chunkController,
          notifier,
        ) =>
            Row(
          children: [
            DefaultCodeLineNumber(
              controller: editingController,
              notifier: notifier,
            ),
            const SizedBox(width: 16),
          ],
        ),
        style: CodeEditorStyle(
          fontSize: context.textTheme.bodyLarge?.fontSize?.ap,
          fontFamily: FontFamily.jetBrainsMono.value,
          codeTheme: CodeHighlightTheme(
            languages: {'yaml': CodeHighlightThemeMode(mode: langYaml)},
            theme: isDark ? atomOneDarkTheme : atomOneLightTheme,
          ),
        ),
      ),
    );
  }
}

class _InfoItem extends StatelessWidget {
  const _InfoItem();

  @override
  Widget build(BuildContext context) {
    final appLocale = AppLocalizations.of(context);
    return ListItem.open(
      leading: const _SettingsLeading(
        child: Icon(Icons.info_outline_rounded),
      ),
      title: Text(appLocale.about),
      trailing: const _SettingsChevron(),
      delegate: OpenDelegate(
        title: appLocale.about,
        widget: const AboutView(),
      ),
    );
  }
}

class _DeveloperItem extends StatelessWidget {
  const _DeveloperItem();

  @override
  Widget build(BuildContext context) {
    final appLocale = AppLocalizations.of(context);
    return ListItem.open(
      leading: const _SettingsLeading(
        child: Icon(Icons.developer_mode_rounded),
      ),
      title: Text(appLocale.developerMode),
      trailing: const _SettingsChevron(),
      delegate: OpenDelegate(
        title: appLocale.developerMode,
        widget: const DeveloperView(),
      ),
    );
  }
}

enum _CoreState { running, restarting, stopped }

class _CoreStatusItem extends StatefulWidget {
  const _CoreStatusItem();

  @override
  State<_CoreStatusItem> createState() => _CoreStatusItemState();
}

class _CoreStatusItemState extends State<_CoreStatusItem> {
  _CoreState _state = _CoreState.stopped;

  @override
  void initState() {
    super.initState();
    unawaited(_checkCoreStatus());
  }

  Future<void> _checkCoreStatus() async {
    try {
      final alive = await clashCore.isInit;
      if (mounted) {
        setState(
            () => _state = alive ? _CoreState.running : _CoreState.stopped);
      }
    } catch (_) {
      if (mounted) setState(() => _state = _CoreState.stopped);
    }
  }

  Color get _statusColor => switch (_state) {
        _CoreState.running => Colors.green,
        _CoreState.restarting => Colors.orange,
        _CoreState.stopped => Colors.red,
      };

  String _statusText(AppLocalizations l) => switch (_state) {
        _CoreState.running => l.coreStatusRunning,
        _CoreState.restarting => l.coreStatusRestarting,
        _CoreState.stopped => l.coreStatusStopped,
      };

  Future<void> _restart() async {
    if (_state == _CoreState.restarting) return;
    setState(() => _state = _CoreState.restarting);
    try {
      await globalState.appController.restartCore();
      if (mounted) setState(() => _state = _CoreState.running);
    } catch (_) {
      if (mounted) setState(() => _state = _CoreState.stopped);
    }
  }

  @override
  Widget build(BuildContext context) {
    final appLocale = AppLocalizations.of(context);
    return ListItem(
      leading: const _SettingsLeading(
        child: Icon(Icons.memory_rounded),
      ),
      title: Text(appLocale.restartCore),
      subtitle: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _statusColor,
            ),
          ),
          const SizedBox(width: 6),
          Text(_statusText(appLocale)),
        ],
      ),
      trailing: Icon(
        Icons.refresh_rounded,
        color: context.colorScheme.onSurfaceVariant,
      ),
      onTap: _restart,
    );
  }
}
