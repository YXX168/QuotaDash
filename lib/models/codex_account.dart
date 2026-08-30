import 'quota_window.dart';
import 'request_bucket.dart';

class CodexAccount {
  const CodexAccount({
    required this.id,
    required this.authIndex,
    required this.name,
    required this.email,
    required this.plan,
    required this.available,
    required this.limitReached,
    required this.primary,
    required this.secondary,
    required this.secondaryLabel,
    required this.resetCredits,
    required this.successRequests,
    required this.failedRequests,
    this.error,
    this.resetCreditsError,
    this.recentRequests = const [],
  });

  final String id;
  final String authIndex;
  final String name;
  final String email;
  final String plan;
  final bool? available;
  final bool? limitReached;
  final QuotaWindow? primary;
  final QuotaWindow? secondary;
  final String secondaryLabel;
  final int? resetCredits;
  final int successRequests;
  final int failedRequests;
  final String? error;
  final String? resetCreditsError;
  final List<RequestBucket> recentRequests;

  String get primaryLabel => primary?.displayLabel ?? '周额度';

  bool get isAvailable =>
      error == null && available == true && limitReached != true;
  bool get hasError => error != null;

  /// The weekly window is the account's primary status. Short-term limits are
  /// operational throttles and must not be averaged into this value.
  double? get weeklyRemainingPercent {
    if (primaryLabel.contains('周')) return primary?.remainingPercent;
    if (secondaryLabel.contains('周')) return secondary?.remainingPercent;
    return null;
  }

  int get recentSuccess =>
      recentRequests.fold(0, (total, bucket) => total + bucket.success);

  int get recentFailed =>
      recentRequests.fold(0, (total, bucket) => total + bucket.failed);

  int get recentTotal => recentSuccess + recentFailed;

  double? get successRate {
    final total = successRequests + failedRequests;
    if (total == 0) return null;
    return successRequests / total * 100;
  }

  DateTime? get nextResetAt {
    final resets =
        [primary?.resetAt, secondary?.resetAt]
            .whereType<DateTime>()
            .where((time) => time.isAfter(DateTime.now()))
            .toList()
          ..sort();
    return resets.isEmpty ? null : resets.first;
  }
}

class AuthFileAccount {
  const AuthFileAccount({
    required this.id,
    required this.authIndex,
    required this.name,
    required this.email,
    required this.successRequests,
    required this.failedRequests,
    required this.recentRequests,
  });

  final String id;
  final String authIndex;
  final String name;
  final String email;
  final int successRequests;
  final int failedRequests;
  final List<RequestBucket> recentRequests;

  factory AuthFileAccount.fromJson(Map<String, dynamic> json) {
    final email = _firstText([json['email'], json['account']]);
    final label = _firstText([
      json['label'],
      json['email'],
      json['name'],
      'unknown',
    ]);
    return AuthFileAccount(
      id: _firstText([json['id'], json['name'], label]),
      authIndex: _firstText([json['auth_index'], json['authIndex']]),
      name: maskName(label),
      email: email.isEmpty ? '' : maskName(email),
      successRequests: _asInt(
        json['success'] ?? json['success_requests'] ?? json['successRequests'],
      ),
      failedRequests: _asInt(
        json['failed'] ?? json['failed_requests'] ?? json['failedRequests'],
      ),
      recentRequests: _requestBuckets(json['recent_requests']),
    );
  }

  static String maskName(String value) {
    if (!value.contains('@')) {
      return value.length > 3 ? '${value.substring(0, 3)}***' : '***';
    }
    final separator = value.indexOf('@');
    final local = value.substring(0, separator);
    final domain = value.substring(separator + 1);
    final prefix = local.substring(0, local.length < 3 ? local.length : 3);
    return '$prefix***@$domain';
  }

  static String _firstText(List<Object?> values) {
    for (final value in values) {
      final text = value?.toString() ?? '';
      if (text.isNotEmpty) return text;
    }
    return '';
  }

  static int _asInt(Object? value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static List<RequestBucket> _requestBuckets(Object? value) {
    if (value is! List) return const [];
    return value
        .whereType<Map>()
        .map((item) => RequestBucket.fromJson(Map<String, dynamic>.from(item)))
        .toList(growable: false);
  }
}
