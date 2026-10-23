import '../models/report.dart';
import 'cache_service.dart';

class LiveSummaryCache {
  static const _key = 'reports:live_summary:v1';
  static LiveSummary? _memory;

  LiveSummary? read(CacheService cache) {
    if (_memory != null) return _memory;
    final raw = cache.readMap(_key);
    if (raw == null) return null;
    try {
      _memory = LiveSummary.fromJson(raw);
      return _memory;
    } catch (_) {
      return null;
    }
  }

  Future<void> write(CacheService cache, LiveSummary summary) async {
    _memory = summary;
    await cache.writeMap(_key, summary.toJson());
  }
}
