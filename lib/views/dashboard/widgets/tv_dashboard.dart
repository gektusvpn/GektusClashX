import 'package:flutter/material.dart';
import 'package:gektusclashx/widgets/tv_navigation_drawer.dart';

/// TV arranges the shared expressive dashboard cards for a landscape display.
class TVDashboard extends StatelessWidget {
  const TVDashboard({
    super.key,
    required this.identity,
    required this.connection,
    this.subscription,
    this.support,
    this.announcement,
    this.update,
    this.buyTraffic,
    this.linksBuilder,
  });

  final Widget identity;
  final Widget connection;
  final Widget? subscription;
  final Widget? support;
  final Widget? announcement;
  final Widget? update;
  final Widget? buyTraffic;
  final Widget Function({required bool drawerAtLeft})? linksBuilder;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth - 40 >= 640;
          final linksBesideSubscription = wide && subscription != null;
          final links =
              linksBuilder?.call(drawerAtLeft: !linksBesideSubscription);
          final connect =
              TVDrawerEdge(child: SizedBox(width: 268, child: connection));
          return SingleChildScrollView(
            key: const PageStorageKey('tv-dashboard-scroll'),
            padding: const EdgeInsets.fromLTRB(24, 48, 16, 28),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 24),
                child: wide
                    ? Row(children: [
                        Expanded(child: identity),
                        const SizedBox(width: 24),
                        connect,
                      ])
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          identity,
                          const SizedBox(height: 20),
                          connect,
                        ],
                      ),
              ),
              if (update != null) update!,
              if (announcement != null)
                Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: announcement),
              if (subscription != null || support != null) ...[
                const SizedBox(height: 24),
                if (wide && subscription != null)
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Expanded(flex: 6, child: subscription!),
                    const SizedBox(width: 20),
                    Expanded(
                        flex: 5,
                        child: Column(children: [
                          if (support != null) support!,
                          if (support != null && links != null)
                            const SizedBox(height: 20),
                          if (links != null) links,
                        ])),
                  ])
                else
                  Column(children: [
                    if (subscription != null) subscription!,
                    if (subscription != null && support != null)
                      const SizedBox(height: 20),
                    if (support != null) support!,
                  ]),
              ],
              if (buyTraffic != null)
                Padding(
                    padding: const EdgeInsets.only(top: 16), child: buyTraffic),
              if (links != null && !linksBesideSubscription)
                Padding(padding: const EdgeInsets.only(top: 20), child: links),
            ]),
          );
        },
      );
}
