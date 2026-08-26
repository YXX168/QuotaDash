class QuotaWindow {
  const QuotaWindow({
    required this.usedPercent,
    required this.remainingPercent,
    this.resetAt,
    this.limitWindowSeconds,
  });

  static const _weekWindowSeconds = 6 * 24 * 60 * 60;
  static const _monthWindowSeconds = 27 * 24 * 60 * 60;

  final double? usedPercent;
  final double? remainingPercent;
  final DateTime? resetAt;
  final int? limitWindowSeconds;

  factory QuotaWindow.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      throw const FormatException('Quota window is missing');
    }
    final used = _asDouble(
      json['used_percent'] ??
          json['usedPercent'] ??
          // OpenCode usage endpoint reports plain "percent".
          json['percent'] ??
          json['percentage'],
    );
    // Some providers report remaining directly instead of used.
    final directRemaining = _asDouble(
      json['remaining_percent'] ??
          json['remainingPercent'] ??
          json['remaining'],
    );
    final limitWindowSeconds = _asInt(
      json['limit_window_seconds'] ??
          json['limitWindowSeconds'] ??
          json['window_seconds'] ??
          json['windowSeconds'],
    );
    return QuotaWindow(
      usedPercent: used,
      remainingPercent: used != null
          ? (100 - used).clamp(0, 100)
          : directRemaining?.clamp(0, 100),
      resetAt: parseResetTime(
        json['reset_at'] ?? json['resetAt'] ?? json['resetsAt'],
      ),
      limitWindowSeconds: _positiveInt(limitWindowSeconds),
    );
  }

  double get progress => ((usedPercent ?? 0) / 100).clamp(0, 1);

  /// Labels the actual server-reported window without assuming a five-hour slot.
  String get displayLabel {
    final seconds = limitWindowSeconds;
    if (seconds == null) return '周额度';
    if (seconds >= _monthWindowSeconds) return '月度额度';
    if (seconds >= _weekWindowSeconds) return '周额度';
    return '短时额度';
  }

  static DateTime? parseResetTime(Object? value) {
    if (value is num && value > 0) {
      final milliseconds = value > 100000000000
          ? value.toInt()
          : value.toInt() * 1000;
      return DateTime.fromMillisecondsSinceEpoch(milliseconds);
    }
    if (value is String) {
      final numeric = double.tryParse(value);
      if (numeric != null) return parseResetTime(numeric);
      return DateTime.tryParse(value)?.toLocal();
    }
    return null;
  }

  static double? _asDouble(Object? value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
  }

  static int? _asInt(Object? value) {
    if (value is num) return value.toInt();
    return double.tryParse(value?.toString() ?? '')?.toInt();
  }

  static int? _positiveInt(int? value) {
    if (value == null || value <= 0) return null;
    return value;
  }
}
