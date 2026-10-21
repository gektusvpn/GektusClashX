import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gektusclashx/common/common.dart';
import 'package:gektusclashx/pages/scan.dart';
import 'package:gektusclashx/providers/providers.dart';
import 'package:gektusclashx/state.dart';
import 'package:gektusclashx/widgets/widgets.dart';

import 'receive_profile_dialog.dart';

enum _AddProfileMethod {
  phone,
  qrCode,
  file,
  url,
}

Future<void> showAddProfileSheet(BuildContext context,
    {bool includePhone = true}) async {
  final method = await showSheet<_AddProfileMethod>(
    context: context,
    props: const SheetProps(
      maxWidth: 420,
      maxHeight: 360,
      fitContent: true,
      isScrollControlled: true,
    ),
    builder: (_, type) => AdaptiveSheetScaffold(
      type: type,
      title: appLocalizations.addProfile,
      fitContent: true,
      body: AddProfileView(
        includePhone: includePhone && !ReceiveProfileView.isActive,
      ),
    ),
  );
  if (method == null || !context.mounted) return;

  switch (method) {
    case _AddProfileMethod.phone:
      await _receiveFromPhone(context);
    case _AddProfileMethod.qrCode:
      await _scanProfile(context);
    case _AddProfileMethod.file:
      await globalState.appController.addProfileFormFile();
    case _AddProfileMethod.url:
      await _addProfileFromUrl();
  }
}

Future<void> _scanProfile(BuildContext context) async {
  if (system.isDesktop) {
    await globalState.appController.addProfileFormQrCode();
    return;
  }

  final url = await BaseNavigator.push<String>(context, const ScanPage());
  if (url != null && url.isNotEmpty) {
    await globalState.appController.addProfileFormURL(url);
  }
}

Future<void> _addProfileFromUrl() async {
  final url = await globalState.showCommonDialog<String>(
    child: const URLFormDialog(),
  );
  if (url != null && url.isNotEmpty) {
    await globalState.appController.addProfileFormURL(url);
  }
}

Future<void> _receiveFromPhone(BuildContext context) async {
  final url = await showDialog<String>(
    context: context,
    builder: (_) => const ReceiveProfileDialog(),
  );
  if (url != null && url.isNotEmpty) {
    await globalState.appController.addProfileFormURL(url);
  }
}

class AddProfileView extends ConsumerWidget {
  const AddProfileView({super.key, this.includePhone = true});

  final bool includePhone;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAndroidTV = ref.watch(isAndroidTVProvider).valueOrNull ?? false;
    final options = [
      if (isAndroidTV && includePhone)
        _AddProfileOptionData(
          method: _AddProfileMethod.phone,
          icon: Icons.phone_android_rounded,
          title: appLocalizations.addFromPhoneTitle,
          subtitle: appLocalizations.addFromPhoneSubtitle,
        ),
      _AddProfileOptionData(
        method: _AddProfileMethod.url,
        icon: Icons.link_rounded,
        title: appLocalizations.url,
        subtitle: appLocalizations.urlDesc,
      ),
      if (!isAndroidTV)
        _AddProfileOptionData(
          method: _AddProfileMethod.qrCode,
          icon: Icons.qr_code_scanner_rounded,
          title: appLocalizations.qrcode,
          subtitle: appLocalizations.qrcodeDesc,
        ),
      _AddProfileOptionData(
        method: _AddProfileMethod.file,
        icon: Icons.upload_file_rounded,
        title: appLocalizations.file,
        subtitle: appLocalizations.fileDesc,
      ),
    ];

    return ListView.separated(
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: options.length,
      separatorBuilder: (_, __) => const SizedBox(height: 2),
      itemBuilder: (context, index) => _AddProfileOption(
        data: options[index],
        isFirst: index == 0,
        isLast: index == options.length - 1,
        isAndroidTV: isAndroidTV,
        onPressed: () => Navigator.of(context).pop(options[index].method),
      ),
    );
  }
}

class _AddProfileOptionData {
  const _AddProfileOptionData({
    required this.method,
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final _AddProfileMethod method;
  final IconData icon;
  final String title;
  final String subtitle;
}

class _AddProfileOption extends StatelessWidget {
  const _AddProfileOption({
    required this.data,
    required this.isFirst,
    required this.isLast,
    required this.isAndroidTV,
    required this.onPressed,
  });

  final _AddProfileOptionData data;
  final bool isFirst;
  final bool isLast;
  final bool isAndroidTV;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    const outerRadius = Radius.circular(24);
    const innerRadius = Radius.circular(4);
    final colorScheme = context.colorScheme;
    final borderRadius = isAndroidTV
        ? BorderRadius.circular(16)
        : BorderRadius.only(
            topLeft: isFirst ? outerRadius : innerRadius,
            topRight: isFirst ? outerRadius : innerRadius,
            bottomLeft: isLast ? outerRadius : innerRadius,
            bottomRight: isLast ? outerRadius : innerRadius,
          );

    return TVFocusEffect(
      enabled: isAndroidTV,
      borderRadius: borderRadius,
      child: Material(
        color: colorScheme.surfaceContainerHigh,
        shape: RoundedRectangleBorder(borderRadius: borderRadius),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          autofocus: isAndroidTV && isFirst,
          focusColor: colorScheme.primary.withValues(alpha: 0.24),
          onTap: onPressed,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 72),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: colorScheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      data.icon,
                      size: 24,
                      color: colorScheme.onSecondaryContainer,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          data.title,
                          style: context.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          data.subtitle,
                          style: context.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class URLFormDialog extends StatefulWidget {
  const URLFormDialog({super.key});

  @override
  State<URLFormDialog> createState() => _URLFormDialogState();
}

class _URLFormDialogState extends State<URLFormDialog> {
  final urlController = TextEditingController();

  void _handleSubmit() {
    final url = urlController.text.trim();
    if (url.isNotEmpty) {
      Navigator.of(context).pop<String>(url);
    }
  }

  Future<void> _handlePaste() async {
    final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
    if (clipboardData?.text != null) {
      urlController.text = clipboardData!.text!;
    }
  }

  @override
  Widget build(BuildContext context) => CommonDialog(
        title: appLocalizations.importFromURL,
        actions: [
          TextButton(
            onPressed: _handlePaste,
            child: Text(appLocalizations.pasteFromClipboard),
          ),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: _handleSubmit,
            child: Text(appLocalizations.submit),
          ),
        ],
        child: Padding(
          padding: const EdgeInsets.only(top: 16),
          child: TextField(
            controller: urlController,
            keyboardType: TextInputType.url,
            autofocus: true,
            minLines: 1,
            maxLines: 5,
            onSubmitted: (_) => _handleSubmit(),
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
              labelText: appLocalizations.url,
            ),
          ),
        ),
      );
}
