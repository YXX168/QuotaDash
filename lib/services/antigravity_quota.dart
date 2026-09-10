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
            _formatLabel(group, label, window, index, bucketIndex),
            bucket,
          ),
        );
      }
    }
    if (windows.isNotEmpty) {
      windows.sort(
        (a, b) => _windowPriority(a.label).compareTo(_windowPriority(b.label)),
      );
      return windows;
    }
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

String _formatLabel(
  String rawGroup,
  String rawBucket,
  String rawWindow,
  int groupIndex,
  int bucketIndex,
) {
  final groupLower = rawGroup.toLowerCase();
  String groupName;
  if (groupLower.contains('gemini')) {
    groupName = 'Gemini Models';
  } else if (groupLower.contains('claude') || groupLower.contains('gpt')) {
    groupName = 'Claude and GPT';
  } else if (rawGroup.trim().isEmpty) {
    groupName = '额度组 ${groupIndex + 1}';
  } else {
    groupName = rawGroup.trim();
  }

  final combined = '${rawBucket.toLowerCase()} ${rawWindow.toLowerCase()}';
  String windowName;
  if (combined.contains('week') ||
      combined.contains('168') ||
      combined.contains('7d') ||
      combined.contains('604800') ||
      combined.contains('周')) {
    windowName = '周额度';
  } else if (combined.contains('session') ||
      combined.contains('5h') ||
      combined.contains('5 hour') ||
      combined.contains('18000')) {
    windowName = '5H额度';
  } else if (combined.contains('day') ||
      combined.contains('24h') ||
      combined.contains('daily') ||
      combined.contains('日')) {
    windowName = '24H额度';
  } else if (combined.contains('month') ||
      combined.contains('30d') ||
      combined.contains('720h') ||
      combined.contains('月')) {
    windowName = '月额度';
  } else {
    final fallback = rawBucket.isNotEmpty
        ? rawBucket.trim()
        : rawWindow.isNotEmpty
        ? rawWindow.trim()
        : '额度 ${bucketIndex + 1}';
    windowName = fallback.endsWith('额度') ? fallback : '$fallback额度';
  }

  return '$groupName $windowName';
}

int _windowPriority(String label) {
  if (label.startsWith('Gemini Models 周额度')) return 0;
  if (label.startsWith('Gemini Models 5H额度')) return 1;
  if (label.startsWith('Claude and GPT 周额度')) return 2;
  if (label.startsWith('Claude and GPT 5H额度')) return 3;
  if (label.contains('Gemini') && label.contains('周')) return 4;
  if (label.contains('Gemini')) return 5;
  if (label.contains('Claude') || label.contains('GPT')) return 6;
  return 7;
}
