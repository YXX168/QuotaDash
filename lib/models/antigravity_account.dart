import 'codex_account.dart';
import 'provider_quota.dart';

/// Quota groups belong to one credential; they are never summed across models.
class AntigravityAccount {
  const AntigravityAccount({required this.auth, required this.quota});

  final AuthFileAccount auth;
  final ProviderQuota quota;

  ProviderQuotaWindow? get lowestWindow {
    ProviderQuotaWindow? lowest;
    for (final window in quota.windows) {
      final remaining = window.remainingPercent;
      if (remaining == null) continue;
      if (lowest == null || remaining < lowest.remainingPercent!) {
        lowest = window;
      }
    }
    return lowest;
  }
}
