import 'codex_account.dart';
import 'antigravity_account.dart';
import 'request_bucket.dart';

class DashboardSnapshot {
  const DashboardSnapshot({
    required this.accounts,
    required this.checkedAt,
    this.antigravityAccounts = const [],
  });

  final List<CodexAccount> accounts;
  final DateTime checkedAt;
  final List<AntigravityAccount> antigravityAccounts;

  int get totalAccounts => accounts.length;

  int get totalSuccessRequests =>
      accounts.fold(0, (total, account) => total + account.successRequests) +
      antigravityAccounts.fold(
        0,
        (total, account) => total + account.auth.successRequests,
      );

  int get totalFailedRequests =>
      accounts.fold(0, (total, account) => total + account.failedRequests) +
      antigravityAccounts.fold(
        0,
        (total, account) => total + account.auth.failedRequests,
      );

  int get recentRequests =>
      accounts.fold(0, (total, account) => total + account.recentTotal) +
      antigravityAccounts.fold(
        0,
        (total, account) =>
            total +
            account.auth.recentRequests.fold(
              0,
              (subtotal, bucket) => subtotal + bucket.total,
            ),
      );

  int get codexRecentRequests =>
      accounts.fold(0, (total, account) => total + account.recentTotal);

  int get antigravityRecentRequests => antigravityAccounts.fold(
    0,
    (total, account) =>
        total +
        account.auth.recentRequests.fold(
          0,
          (subtotal, bucket) => subtotal + bucket.total,
        ),
  );

  double? get successRate {
    final total = totalSuccessRequests + totalFailedRequests;
    if (total == 0) return null;
    return totalSuccessRequests / total * 100;
  }

  List<RequestBucket> get recentRequestBuckets {
    final sources = <List<RequestBucket>>[
      ...accounts.map((account) => account.recentRequests),
      ...antigravityAccounts.map((account) => account.auth.recentRequests),
    ].where((requests) => requests.isNotEmpty).toList(growable: false);
    final maxLength = sources.fold<int>(
      0,
      (length, requests) => requests.length > length ? requests.length : length,
    );
    if (maxLength == 0) return const [];
    // Labels identify the actual window. Positional alignment alone can merge
    // unrelated windows when one provider omits an empty or older bucket.
    final reference = sources.firstWhere(
      (requests) => requests.length == maxLength,
    );
    final labeled = <String, RequestBucket>{};
    final unlabeled = <int, RequestBucket>{};
    for (final requests in sources) {
      final offset = maxLength - requests.length;
      for (var index = 0; index < requests.length; index++) {
        final bucket = requests[index];
        final position = index + offset;
        final label = bucket.time?.trim() ?? '';
        final referenceLabel = reference[position].time?.trim() ?? '';
        final key = label.isNotEmpty ? label : referenceLabel;
        final previous = key.isEmpty ? unlabeled[position] : labeled[key];
        final combined = RequestBucket(
          time: key.isEmpty ? null : key,
          success: (previous?.success ?? 0) + bucket.success,
          failed: (previous?.failed ?? 0) + bucket.failed,
        );
        if (key.isEmpty) {
          unlabeled[position] = combined;
        } else {
          labeled[key] = combined;
        }
      }
    }
    if (labeled.isNotEmpty && unlabeled.isEmpty) {
      final buckets = labeled.values.toList(growable: false);
      final clock = RegExp(r'^([0-9]{1,2}):([0-9]{2})');
      int? minute(String? label) {
        final match = clock.firstMatch(label ?? '');
        if (match == null) return null;
        return int.parse(match[1]!) * 60 + int.parse(match[2]!);
      }

      if (buckets.every((bucket) => minute(bucket.time) != null)) {
        buckets.sort((a, b) => minute(a.time)!.compareTo(minute(b.time)!));
        // The largest gap is outside this recent window, even at midnight.
        var start = 0;
        var largestGap = -1;
        for (var index = 0; index < buckets.length; index++) {
          final next = (index + 1) % buckets.length;
          final gap =
              (minute(buckets[next].time)! - minute(buckets[index].time)!) %
              1440;
          if (gap > largestGap) {
            largestGap = gap;
            start = next;
          }
        }
        return [...buckets.skip(start), ...buckets.take(start)];
      } else if (buckets.every(
        (bucket) => DateTime.tryParse(bucket.time!) != null,
      )) {
        buckets.sort(
          (a, b) => DateTime.parse(a.time!).compareTo(DateTime.parse(b.time!)),
        );
      }
      return buckets;
    }
    return List.generate(maxLength, (index) {
      var success = 0;
      var failed = 0;
      String? time;
      for (final requests in sources) {
        final offset = maxLength - requests.length;
        final accountIndex = index - offset;
        if (accountIndex < 0) continue;
        final bucket = requests[accountIndex];
        success += bucket.success;
        failed += bucket.failed;
        time ??= bucket.time;
      }
      return RequestBucket(time: time, success: success, failed: failed);
    }, growable: false);
  }
}
