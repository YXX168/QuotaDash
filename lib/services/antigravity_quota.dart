import '../models/provider_quota.dart';
import '../models/quota_window.dart';

/// Supports current grouped buckets and older fetchAvailableModels responses.
/// Missing or malformed fractions remain unknown, never a synthetic full quota.
List<ProviderQuotaWindow> parseAntigravityQuota(Map<String, dynamic> payload) {
  final nested = payload['response'];
  if (nested is Map &&
      !payload.containsKey('groups') &&
      !payload.containsKey('models')) {
    return parseAntigravityQuota(Map<String, dynamic>.from(nested));
  }
  final windows = <ProviderQuotaWindow>[];
  final groups = payload['groups'];
  if (groups is List) {
    for (final (index, raw) in groups.indexed) {
      if (raw is! Map) continue;
      final group = _text(raw['displayName'] ?? raw['display_name']);
      final buckets = raw['buckets'];
      if (buckets is! List) continue;
      for (final (bucketIndex, bucket) in buckets.indexed) {
        if (bucket is! Map) continue;
        final label = _text(bucket['displayName'] ?? bucket['display_name']);
        final window = _text(bucket['window']);
        windows.add(
          _window(
            '${group.isEmpty ? '额度组 ${index + 1}' : group} · '
            '${label.isNotEmpty
                ? label
                : window.isNotEmpty
                ? window
                : '额度 ${bucketIndex + 1}'}',
            bucket,
          ),
        );
      }
    }
    if (windows.isNotEmpty) return windows;
  }
  final models = payload['models'];
  if (models is! Map) return windows;
  final keys = models.keys.map((key) => key.toString()).toList()..sort();
  for (final key in keys) {
    final model = models[key];
    if (model is! Map) continue;
    final quota = model['quotaInfo'] ?? model['quota_info'];
    if (quota is! Map) continue;
    final label = _text(model['displayName'] ?? model['display_name']);
    windows.add(_window(label.isEmpty ? key : label, quota));
  }
  return windows;
}

ProviderQuotaWindow _window(String label, Map quota) {
  final raw = quota['remainingFraction'] ?? quota['remaining_fraction'];
  final fraction = raw is num ? raw.toDouble() : double.tryParse('$raw');
  return ProviderQuotaWindow(
    label: label,
    remainingPercent: fraction != null && fraction.isFinite
        ? fraction.clamp(0.0, 1.0) * 100
        : null,
    resetAt: QuotaWindow.parseResetTime(
      quota['resetTime'] ?? quota['reset_time'],
    ),
  );
}

String _text(Object? value) => value?.toString().trim() ?? '';
