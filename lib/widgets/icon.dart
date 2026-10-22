import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_svg/svg.dart';
import 'package:gektusclashx/common/common.dart';

class CommonHeaderIconButton extends StatelessWidget {
  const CommonHeaderIconButton({
    super.key,
    required this.onPressed,
    required this.icon,
    this.tooltip,
    this.iconSize,
  });

  final VoidCallback? onPressed;
  final Widget icon;
  final String? tooltip;
  final double? iconSize;

  @override
  Widget build(BuildContext context) => IconButton.filledTonal(
        tooltip: tooltip,
        onPressed: onPressed,
        iconSize: iconSize,
        style: IconButton.styleFrom(
          backgroundColor: context.colorScheme.surfaceContainerHigh,
          foregroundColor: context.colorScheme.onSurfaceVariant,
        ),
        icon: icon,
      );
}

class CommonTargetIcon extends StatelessWidget {
  const CommonTargetIcon({
    super.key,
    required this.src,
    required this.size,
  });
  final String src;
  final double size;

  Widget _defaultIcon() => Icon(
        IconsExt.target,
        size: size,
      );

  Widget _buildIcon() {
    if (src.isEmpty) {
      return _defaultIcon();
    }

    final base64 = src.getBase64;
    if (base64 != null) {
      return Image.memory(
        base64,
        gaplessPlayback: true,
        cacheWidth: (size * 2).toInt(),
        cacheHeight: (size * 2).toInt(),
        errorBuilder: (_, error, ___) => _defaultIcon(),
      );
    }

    if (src.isSvg) {
      return FutureBuilder(
        future: DefaultCacheManager().getSingleFile(src),
        builder: (_, snapshot) {
          final data = snapshot.data;
          if (data == null) {
            return const SizedBox();
          }
          return SvgPicture.file(
            data,
            width: size,
            height: size,
            errorBuilder: (_, __, ___) => _defaultIcon(),
          );
        },
      );
    }

    return CachedNetworkImage(
      imageUrl: src,
      width: size,
      height: size,
      fit: BoxFit.contain,
      memCacheWidth: (size * 2).toInt(),
      memCacheHeight: (size * 2).toInt(),
      placeholder: (_, __) => const SizedBox(),
      errorWidget: (_, __, ___) => _defaultIcon(),
    );
  }

  @override
  Widget build(BuildContext context) => SizedBox(
        width: size,
        height: size,
        child: _buildIcon(),
      );
}

class TelegramIcon extends StatelessWidget {
  const TelegramIcon({super.key, this.size = 20});

  final double size;

  static const _svg = '''
<svg viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">
  <path fill="currentColor" d="M9.78 18.65l.28-4.23 7.68-6.92c.34-.31-.07-.46-.52-.19L7.74 13.3 3.64 12c-.88-.25-.89-.86.2-1.3l15.97-6.16c.73-.33 1.43.18 1.15 1.3l-2.72 12.81c-.19.91-.74 1.13-1.5.71L12.6 16.3l-1.99 1.93c-.23.23-.42.42-.83.42z"/>
</svg>
''';

  @override
  Widget build(BuildContext context) => SvgPicture.string(
        _svg,
        width: size,
        height: size,
        colorFilter: ColorFilter.mode(
          IconTheme.of(context).color ?? context.colorScheme.onSurface,
          BlendMode.srcIn,
        ),
      );
}
