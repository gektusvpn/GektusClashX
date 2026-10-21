import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:gektusclashx/common/service_logo_cache.dart';

/// Displays a provider logo from the shared memory/disk cache.
///
/// Keeping this in one widget prevents the app icon from flashing while a
/// cached provider logo is restored on startup.
class ServiceLogoImage extends StatefulWidget {
  const ServiceLogoImage({
    super.key,
    required this.url,
    this.fit = BoxFit.cover,
    this.fallback,
  });

  final String? url;
  final BoxFit fit;
  final Widget? fallback;

  @override
  State<ServiceLogoImage> createState() => _ServiceLogoImageState();
}

class _ServiceLogoImageState extends State<ServiceLogoImage> {
  Future<Uint8List?>? _loadFuture;
  Uint8List? _initialBytes;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant ServiceLogoImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) _load();
  }

  void _load() {
    final url = widget.url;
    _initialBytes = url == null ? null : serviceLogoCache.get(url);
    _loadFuture = url == null ? null : serviceLogoCache.load(url);
  }

  @override
  Widget build(BuildContext context) {
    final fallback = widget.fallback ??
        Image.asset(
          'assets/images/icon.png',
          fit: widget.fit,
        );
    final url = widget.url;
    if (url == null || url.isEmpty) return fallback;

    return FutureBuilder<Uint8List?>(
      future: _loadFuture,
      initialData: _initialBytes,
      builder: (_, snapshot) {
        final bytes = snapshot.data ?? _initialBytes;
        if (bytes == null) {
          return snapshot.connectionState == ConnectionState.done
              ? fallback
              : const SizedBox.expand();
        }
        final isSvg =
            Uri.tryParse(url)?.path.toLowerCase().endsWith('.svg') ?? false;
        if (isSvg) {
          return SvgPicture.memory(
            bytes,
            fit: widget.fit,
            errorBuilder: (_, __, ___) => fallback,
          );
        }
        return Image.memory(
          bytes,
          fit: widget.fit,
          gaplessPlayback: true,
          errorBuilder: (_, __, ___) => fallback,
        );
      },
    );
  }
}
