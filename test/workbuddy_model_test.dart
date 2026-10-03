import 'package:cliproxy_dash/models/antigravity_account.dart';
import 'package:cliproxy_dash/models/codex_account.dart';
import 'package:cliproxy_dash/models/dashboard_snapshot.dart';
import 'package:cliproxy_dash/models/provider_quota.dart';
import 'package:cliproxy_dash/models/request_bucket.dart';
import 'package:cliproxy_dash/models/workbuddy_account.dart';
import 'package:flutter_test/flutter_test.dart';

const auth = AuthFileAccount(
  id: 'fixture',
  authIndex: 'fixture-index',
  name: 'fix***',
  email: '',
  successRequests: 4,
  failedRequests: 2,
  recentRequests: [RequestBucket(time: '00:00-00:10', success: 3, failed: 1)],
);

void main() {
  test('parses numeric credits, account metadata and package expiry', () {
    final account = WorkBuddyAccount.fromJson(
      auth: auth,
      json: {
        'nickname': 'Synthetic account',
        'region': 'global',
        'plan': 'pro',
        'selected': true,
        'exhausted': false,
        'credits': {
          'total_remain': '375.5',
          'total_used': 124.5,
          'total_size': 500,
          'pack_count': '1',
          'fetched_at': '2026-10-03T01:00:00Z',
          'packages': [
            {
              'name': 'Synthetic package',
              'remain': '375.5',
              'used': 124.5,
              'size': 500,
              'cycle_start': '2026-10-01T00:00:00Z',
              'cycle_end': '2026-10-31T00:00:00Z',
            },
          ],
        },
      },
    );
    expect(account.displayName, 'Syn***');
    expect(account.regionLabel, '国际版');
    expect(account.plan, 'pro');
    expect(account.selected, isTrue);
    expect(account.exhausted, isFalse);
    expect(account.credits!.remainingPercent, 75.1);
    expect(account.credits!.packageCount, 1);
    expect(account.credits!.fetchedAt!.toUtc(), DateTime.utc(2026, 10, 3, 1));
    expect(
      account.credits!.packages.single.cycleEnd!.toUtc(),
      DateTime.utc(2026, 10, 31),
    );
  });

  test('unknown, malformed and zero balances remain distinct', () {
    expect(WorkBuddyCredits.fromJson({}).totalRemaining, isNull);
    for (final value in ['NaN', 'Infinity', -1, true, 'broken']) {
      final credits = WorkBuddyCredits.fromJson({
        'total_remain': value,
        'total_size': 500,
      });
      expect(credits.totalRemaining, isNull);
      expect(credits.remainingPercent, isNull);
    }
    final zero = WorkBuddyCredits.fromJson({
      'total_remain': 0,
      'total_size': 500,
    });
    expect(zero.totalRemaining, 0);
    expect(zero.remainingPercent, 0);
    for (final capacity in [null, 0, 'NaN']) {
      expect(
        WorkBuddyCredits.fromJson({
          'total_remain': 0,
          'total_size': capacity,
        }).remainingPercent,
        isNull,
      );
    }
    final malformed = WorkBuddyCredits.fromJson({
      'pack_count': 1.5,
      'fetched_at': 'invalid',
      'packages': [
        null,
        'invalid',
        {'remain': 10, 'size': 5},
      ],
    });
    expect(malformed.packageCount, isNull);
    expect(malformed.fetchedAt, isNull);
    expect(malformed.packages.single.remainingPercent, 100);
    expect(malformed.packages.single.cycleEnd, isNull);
  });

  test('plugin error payloads never become display messages', () {
    final account = WorkBuddyAccount.fromJson(
      auth: auth,
      json: {'error': 'synthetic-private-diagnostic'},
    );
    expect(account.error.toString(), workBuddyQuotaError);
    expect(account.credits, isNull);
    expect(account.exhausted, isNull);
  });

  test('all-provider totals and sparse midnight buckets include WorkBuddy', () {
    final snapshot = DashboardSnapshot(
      accounts: const [
        CodexAccount(
          id: 'codex',
          authIndex: 'c',
          name: 'c',
          email: '',
          plan: 'plus',
          available: true,
          limitReached: false,
          primary: null,
          secondary: null,
          secondaryLabel: '周额度',
          resetCredits: null,
          successRequests: 2,
          failedRequests: 0,
          recentRequests: [
            RequestBucket(time: '23:50-00:00', success: 2, failed: 0),
          ],
        ),
      ],
      antigravityAccounts: const [
        AntigravityAccount(
          auth: auth,
          quota: ProviderQuota(
            provider: QuotaProviderId.antigravity,
            windows: [],
          ),
        ),
      ],
      workBuddyAccounts: const [WorkBuddyAccount(auth: auth)],
      checkedAt: DateTime(2026),
    );
    expect(snapshot.totalAccounts, 3);
    expect(snapshot.totalSuccessRequests, 10);
    expect(snapshot.totalFailedRequests, 4);
    expect(snapshot.recentRequests, 10);
    expect(snapshot.workBuddyRecentRequests, 4);
    expect(snapshot.recentRequestBuckets.map((bucket) => bucket.time), [
      '23:50-00:00',
      '00:00-00:10',
    ]);
    expect(snapshot.recentRequestBuckets.map((bucket) => bucket.total), [2, 8]);
    expect(snapshot.successRate, closeTo(10 / 14 * 100, 0.001));
  });

  test('WorkBuddy-only traffic supports unlabeled buckets', () {
    final snapshot = DashboardSnapshot(
      accounts: const [],
      workBuddyAccounts: const [WorkBuddyAccount(auth: auth)],
      checkedAt: DateTime(2026),
    );
    expect(snapshot.totalAccounts, 1);
    expect(snapshot.recentRequests, 4);
    expect(snapshot.recentRequestBuckets.single.failed, 1);
  });
}
