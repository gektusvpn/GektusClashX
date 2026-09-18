import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_cache_manager/flutter_cache_manager.dart';

const _maxServiceLogoBytes = 5 * 1024 * 1024;

String? decodeServiceLogoUrl(String? value) {
  if (value == null || value.trim().isEmpty) return null;
  var text = value.trim();
  if (text.startsWith('base64:')) text = text.substring(7).trim();
  if (text.isEmpty) return null;
  try {
    final normalized = base64.normalize(text);
    final decoded = utf8.decode(base64.decode(normalized)).trim();
    return decoded.isEmpty ? null : decoded;
  } catch (_) {
    return value.trim();
  }
}

class ServiceLogoCache {
  ServiceLogoCache._();

  static final instance = ServiceLogoCache._();

  final _memory = <String, Uint8List>{};

  Uint8List? get(String url) => _memory[url];

  Future<void> preload(String? url) async {
    if (url == null || url.isEmpty || _memory.containsKey(url)) return;
    try {
      final cached = await DefaultCacheManager().getFileFromCache(url);
      final bytes = await _read(cached?.file);
      if (bytes != null) _memory[url] = bytes;
    } catch (_) {}
  }

  Future<Uint8List?> load(String url) async {
    try {
      final file = await DefaultCacheManager().getSingleFile(url);
      final bytes = await _read(file);
      if (bytes != null) _memory[url] = bytes;
      return bytes;
    } catch (_) {
      return _memory[url];
    }
  }

  Future<Uint8List?> _read(File? file) async {
    if (file == null) return null;
    final length = await file.length();
    if (length <= 0 || length > _maxServiceLogoBytes) return null;
    return file.readAsBytes();
  }
}

final serviceLogoCache = ServiceLogoCache.instance;
