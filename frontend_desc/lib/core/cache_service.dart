import 'dart:convert';

import 'package:hive/hive.dart';

class CacheService {
  CacheService(this._box);

  final Box<String> _box;

  static const boxName = 'emad_crm_cache_v1';

  Map<String, dynamic>? readMap(String key) {
    final raw = _box.get(key);
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return decoded;
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<void> writeMap(String key, Map<String, dynamic> value) async {
    await _box.put(key, jsonEncode(value));
  }

  Future<void> removeByPrefix(String prefix) async {
    final keys = <String>[];
    for (final dynamic key in _box.keys) {
      if (key is String && key.startsWith(prefix)) {
        keys.add(key);
      }
    }
    if (keys.isNotEmpty) {
      await _box.deleteAll(keys);
    }
  }
}
