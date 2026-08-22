import 'quota_window.dart';

class OpencodeQuota {
  const OpencodeQuota({
    required this.rolling,
    required this.weekly,
    required this.monthly,
  });

  final QuotaWindow? rolling;
  final QuotaWindow? weekly;
  final QuotaWindow? monthly;

  factory OpencodeQuota.fromJson(Map<String, dynamic> json) {
    final usage = _map(json['usage'] ?? json);
    return OpencodeQuota(
      rolling: _window(usage['rolling']),
      weekly: _window(usage['weekly']),
      monthly: _window(usage['monthly']),
    );
  }

  List<OpencodeWindow> get windows => [
    OpencodeWindow('滚动额度', rolling),
    OpencodeWindow('周额度', weekly),
    OpencodeWindow('月度额度', monthly),
  ];

  double? get averageRemainingPercent {
    final values = windows
        .map((entry) => entry.window?.remainingPercent)
        .whereType<double>()
        .toList();
    if (values.isEmpty) return null;
    return values.reduce((a, b) => a + b) / values.length;
  }

  static Map<String, dynamic> _map(Object? value) {
    return value is Map ? Map<String, dynamic>.from(value) : const {};
  }

  static QuotaWindow? _window(Object? value) {
    if (value is! Map) return null;
    return QuotaWindow.fromJson(Map<String, dynamic>.from(value));
  }
}

class OpencodeWindow {
  const OpencodeWindow(this.label, this.window);

  final String label;
  final QuotaWindow? window;
}
