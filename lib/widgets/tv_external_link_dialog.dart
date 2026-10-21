import 'package:flutter/material.dart';
import 'package:gektusclashx/common/common.dart';
import 'package:url_launcher/url_launcher.dart';

import 'tv_controls.dart';

class TVExternalLinkDialog extends StatefulWidget {
  const TVExternalLinkDialog({super.key, required this.uri});
  final Uri uri;

  @override
  State<TVExternalLinkDialog> createState() => _TVExternalLinkDialogState();
}

class _TVExternalLinkDialogState extends State<TVExternalLinkDialog> {
  bool _failed = false;
  bool _opening = false;

  Future<void> _openOnTV() async {
    if (_opening) return;
    setState(() {
      _opening = true;
      _failed = false;
    });
    var launched = false;
    try {
      launched =
          await launchUrl(widget.uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      launched = false;
    }
    if (mounted) {
      setState(() {
        _opening = false;
        _failed = !launched;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    return Dialog(
      backgroundColor: colors.surfaceContainerHigh,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 48, vertical: 28),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 592),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(appLocalizations.openOnPhone,
                    style: context.textTheme.headlineSmall),
                const SizedBox(height: 24),
                Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                  TVQrCode(data: widget.uri.toString()),
                  const SizedBox(width: 28),
                  Expanded(
                      child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text(appLocalizations.scanLinkWithPhone,
                            style: context.textTheme.bodyLarge
                                ?.copyWith(height: 1.4)),
                        const SizedBox(height: 16),
                        Text(widget.uri.toString(),
                            maxLines: 4,
                            overflow: TextOverflow.ellipsis,
                            style: context.textTheme.bodyMedium
                                ?.copyWith(color: colors.onSurfaceVariant)),
                        if (_failed) ...[
                          const SizedBox(height: 12),
                          Text(appLocalizations.openLinkFailed,
                              style: context.textTheme.bodyMedium
                                  ?.copyWith(color: colors.error)),
                        ],
                      ])),
                ]),
                const SizedBox(height: 24),
                Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                  TVActionButton(
                      label: appLocalizations.openOnTV,
                      icon: Icons.open_in_new_rounded,
                      onPressed: _openOnTV),
                  const SizedBox(width: 12),
                  TVActionButton(
                      label: MaterialLocalizations.of(context).closeButtonLabel,
                      icon: Icons.check_rounded,
                      autofocus: true,
                      onPressed: () => Navigator.of(context).pop()),
                ]),
              ]),
        ),
      ),
    );
  }
}
