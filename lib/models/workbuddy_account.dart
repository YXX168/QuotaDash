import '../services/private_http.dart';
import 'codex_account.dart';
import 'quota_window.dart';

const workBuddyQuotaError = 'WorkBuddy 额度查询失败，请稍后刷新';

class WorkBuddyQuotaException implements PublicError {
  const WorkBuddyQuotaException();

  @override
  String get message => workBuddyQuotaError;

  @override
  String toString() => message;
}

/// Credit packages expire independently; a cycle end does not promise a refill.
class WorkBuddyPackage {
  const WorkBuddyPackage({
    required this.name,
    this.remaining,
    this.used,
    this.size,
    this.cycleStart,
    this.cycleEnd,
  });

  final String name;
  final double? remaining;
  final double? used;
  final double? size;
  final DateTime? cycleStart;
  final DateTime? cycleEnd;

  double? get remainingPercent => _percent(remaining, size);

  factory WorkBuddyPackage.fromJson(Map<String, dynamic> json) =>
      WorkBuddyPackage(
        name: _text(json['name']).isEmpty ? '积分包' : _text(json['name']),
        remaining: _amount(json['remain']),
        used: _amount(json['used']),
        size: _amount(json['size']),
        cycleStart: QuotaWindow.parseResetTime(json['cycle_start']),
        cycleEnd: QuotaWindow.parseResetTime(json['cycle_end']),
      );
}

class WorkBuddyCredits {
  const WorkBuddyCredits({
    this.totalRemaining,
    this.totalUsed,
    this.totalSize,
    this.packageCount,
    this.fetchedAt,
    this.packages = const [],
  });

  final double? totalRemaining;
  final double? totalUsed;
  final double? totalSize;
  final int? packageCount;
  final DateTime? fetchedAt;
  final List<WorkBuddyPackage> packages;

  double? get remainingPercent => _percent(totalRemaining, totalSize);

  factory WorkBuddyCredits.fromJson(Map<String, dynamic> json) {
    final count = _amount(json['pack_count']);
    final packages = json['packages'];
    return WorkBuddyCredits(
      totalRemaining: _amount(json['total_remain']),
      totalUsed: _amount(json['total_used']),
      totalSize: _amount(json['total_size']),
      packageCount: count != null && count == count.truncateToDouble()
          ? count.toInt()
          : null,
      fetchedAt: QuotaWindow.parseResetTime(json['fetched_at']),
      packages: packages is List
          ? packages
                .whereType<Map>()
                .map(
                  (raw) =>
                      WorkBuddyPackage.fromJson(Map<String, dynamic>.from(raw)),
                )
                .toList(growable: false)
          : const [],
    );
  }
}

/// Identity and request statistics come from credentials, joined by auth_index.
class WorkBuddyAccount {
  const WorkBuddyAccount({
    required this.auth,
    this.nickname = '',
    this.region = '',
    this.plan = '',
    this.disabled = false,
    this.exhausted,
    this.selected = false,
    this.credits,
    this.error,
  });

  final AuthFileAccount auth;
  final String nickname;
  final String region;
  final String plan;
  final bool disabled;
  final bool? exhausted;
  final bool selected;
  final WorkBuddyCredits? credits;
  final Object? error;

  String get displayName => nickname.isEmpty ? auth.name : nickname;
  String get regionLabel => switch (region) {
    'cn' => '国内版',
    'global' => '国际版',
    _ => '区域未知',
  };

  factory WorkBuddyAccount.fromJson({
    required AuthFileAccount auth,
    required Map<String, dynamic> json,
    bool disabled = false,
    String? error,
  }) {
    final rawCredits = json['credits'];
    final nickname = _text(json['nickname']);
    final pluginError = json['error'];
    return WorkBuddyAccount(
      auth: auth,
      nickname: nickname.isEmpty ? '' : AuthFileAccount.maskName(nickname),
      region: _text(json['region']).toLowerCase(),
      plan: _text(json['plan']),
      disabled: disabled || _bool(json['disabled']) == true,
      exhausted: _bool(json['exhausted']),
      selected: _bool(json['selected']) == true,
      credits: rawCredits is Map
          ? WorkBuddyCredits.fromJson(Map<String, dynamic>.from(rawCredits))
          : null,
      error:
          error != null ||
              (pluginError != null && _text(pluginError).isNotEmpty)
          ? const WorkBuddyQuotaException()
          : null,
    );
  }
}

String _text(Object? value) => value?.toString().trim() ?? '';

double? _amount(Object? value) {
  final parsed = value is num
      ? value.toDouble()
      : value is String
      ? double.tryParse(value.trim())
      : null;
  return parsed != null && parsed.isFinite && parsed >= 0 ? parsed : null;
}

double? _percent(double? remaining, double? size) =>
    remaining == null || size == null || size <= 0
    ? null
    : (remaining / size * 100).clamp(0.0, 100.0);

bool? _bool(Object? value) => switch (value) {
  true || 'true' => true,
  false || 'false' => false,
  _ => null,
};
