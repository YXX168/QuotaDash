import 'codex_account.dart';
import 'request_bucket.dart';

class DashboardSnapshot {
  const DashboardSnapshot({required this.accounts, required this.checkedAt});

  final List<CodexAccount> accounts;
  final DateTime checkedAt;

  int get totalAccounts => accounts.length;

  int get totalSuccessRequests =>
      accounts.fold(0, (total, account) => total + account.successRequests);

  int get totalFailedRequests =>
      accounts.fold(0, (total, account) => total + account.failedRequests);

  int get recentRequests =>
      accounts.fold(0, (total, account) => total + account.recentTotal);

  double? get successRate {
    final total = totalSuccessRequests + totalFailedRequests;
    if (total == 0) return null;
    return totalSuccessRequests / total * 100;
  }

  List<RequestBucket> get recentRequestBuckets {
    final maxLength = accounts.fold<int>(
      0,
      (length, account) => account.recentRequests.length > length
          ? account.recentRequests.length
          : length,
    );
    if (maxLength == 0) return const [];
    return List.generate(maxLength, (index) {
      var success = 0;
      var failed = 0;
      String? time;
      for (final account in accounts) {
        final offset = maxLength - account.recentRequests.length;
        final accountIndex = index - offset;
        if (accountIndex < 0) continue;
        final bucket = account.recentRequests[accountIndex];
        success += bucket.success;
        failed += bucket.failed;
        time ??= bucket.time;
      }
      return RequestBucket(time: time, success: success, failed: failed);
    }, growable: false);
  }
}
