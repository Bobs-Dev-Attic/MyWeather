import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Tracks API call timestamps per source and enforces user-configured
/// rolling-window rate limits (calls per hour / per day).
///
/// Timestamps are persisted so limits survive app restarts, which keeps the
/// app within free-tier allowances across sessions.
class RateLimiter {
  RateLimiter(this._prefs);

  static const _prefix = 'ratelimiter.';
  final SharedPreferences _prefs;

  List<int> _load(String sourceId) {
    final raw = _prefs.getString('$_prefix$sourceId');
    if (raw == null) return [];
    try {
      return (jsonDecode(raw) as List).map((e) => e as int).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _save(String sourceId, List<int> stamps) async {
    await _prefs.setString('$_prefix$sourceId', jsonEncode(stamps));
  }

  /// Prunes timestamps older than 24h.
  List<int> _prune(List<int> stamps, int nowMs) {
    final dayAgo = nowMs - const Duration(hours: 24).inMilliseconds;
    return stamps.where((t) => t >= dayAgo).toList();
  }

  int _countSince(List<int> stamps, int nowMs, Duration window) {
    final cutoff = nowMs - window.inMilliseconds;
    return stamps.where((t) => t >= cutoff).length;
  }

  /// Number of calls in the trailing hour.
  int callsLastHour(String sourceId) {
    final now = DateTime.now().millisecondsSinceEpoch;
    return _countSince(_load(sourceId), now, const Duration(hours: 1));
  }

  /// Number of calls in the trailing day.
  int callsLastDay(String sourceId) {
    final now = DateTime.now().millisecondsSinceEpoch;
    return _countSince(_load(sourceId), now, const Duration(hours: 24));
  }

  /// Whether another call is currently permitted under the given limits.
  bool canCall(String sourceId, {required int maxPerHour, required int maxPerDay}) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final stamps = _prune(_load(sourceId), now);
    final hour = _countSince(stamps, now, const Duration(hours: 1));
    final day = _countSince(stamps, now, const Duration(hours: 24));
    return hour < maxPerHour && day < maxPerDay;
  }

  /// Records that a call was made now.
  Future<void> record(String sourceId) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final stamps = _prune(_load(sourceId), now)..add(now);
    await _save(sourceId, stamps);
  }

  /// Clears all recorded calls for a source.
  Future<void> reset(String sourceId) async {
    await _prefs.remove('$_prefix$sourceId');
  }
}
