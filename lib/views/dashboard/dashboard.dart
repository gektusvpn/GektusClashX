import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gektusclashx/common/common.dart';
import 'package:gektusclashx/enum/enum.dart';
import 'package:gektusclashx/providers/providers.dart';
import 'package:gektusclashx/views/tools.dart';
import 'package:gektusclashx/widgets/widgets.dart';

import 'widgets/hero_connect.dart';

class DashboardView extends ConsumerStatefulWidget {
  const DashboardView({super.key});

  @override
  ConsumerState<DashboardView> createState() => _DashboardViewState();
}

class _DashboardViewState extends ConsumerState<DashboardView> with PageMixin {
  @override
  void initState() {
    super.initState();
    ref.listenManual(
      isCurrentPageProvider(PageLabel.dashboard),
      (previous, next) {
        if (previous != next && next) {
          initPageState();
        }
      },
      fireImmediately: true,
    );
  }

  @override
  List<Widget> get actions => [
        IconButton(
          tooltip: appLocalizations.settings,
          onPressed: _openSettings,
          icon: const Icon(Icons.settings_rounded),
        ),
      ];

  Future<void> _openSettings() async {
    await showExtend<void>(
      context,
      props: const ExtendProps(maxWidth: 480),
      builder: (_, type) => AdaptiveSheetScaffold(
        type: type,
        title: appLocalizations.settings,
        body: const ToolsView(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => const HeroConnect();
}
