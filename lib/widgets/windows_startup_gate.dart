import 'package:flutter/material.dart';
import 'package:gektusclashx/common/startup_diagnostics.dart';
import 'package:gektusclashx/state.dart';

/// The window can render while core initialization is still running. Keep its
/// controls inert until the initial VPN state has been reconciled.
class WindowsStartupGate extends StatelessWidget {
  const WindowsStartupGate({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<bool>(
        valueListenable: windowsStartupReady,
        builder: (context, ready, _) => Directionality(
          textDirection: TextDirection.ltr,
          child: Stack(children: [
            AbsorbPointer(
                absorbing: !ready,
                child: ExcludeFocus(excluding: !ready, child: child)),
            ValueListenableBuilder<String?>(
              valueListenable: windowsStartupError,
              builder: (context, error, _) => ready && error == null
                  ? const SizedBox.shrink()
                  : Align(
                      alignment: Alignment.bottomCenter,
                      child: Material(
                        color: error == null
                            ? Colors.black87
                            : Colors.red.shade900,
                        child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(children: [
                              if (error == null)
                                const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2)),
                              const SizedBox(width: 12),
                              Expanded(
                                  child: Text(error ?? 'Starting GektusClashX…',
                                      style: const TextStyle(
                                          color: Colors.white))),
                              if (error != null && !ready)
                                TextButton(
                                    onPressed: () =>
                                        globalState.appController.handleExit(),
                                    child: const Text('Exit',
                                        style: TextStyle(color: Colors.white))),
                            ])),
                      )),
            ),
          ]),
        ),
      );
}
