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

  /// Weekly quota window for Gemini Models.
  ProviderQuotaWindow? get geminiWeeklyWindow {
    for (final window in quota.windows) {
      final label = window.label.toLowerCase();
      if (label.contains('gemini') &&
          (label.contains('周') ||
              label.contains('168') ||
              label.contains('week'))) {
        return window;
      }
    }
    for (final window in quota.windows) {
      final label = window.label.toLowerCase();
      if (label.contains('周') ||
          label.contains('168') ||
          label.contains('week')) {
        return window;
      }
    }
    return quota.windows.isNotEmpty ? quota.windows.first : null;
  }

  /// 5-hour quota window for Gemini Models.
  ProviderQuotaWindow? get gemini5HWindow {
    for (final window in quota.windows) {
      final label = window.label.toLowerCase();
      if (label.contains('gemini') &&
          (label.contains('5h') ||
              label.contains('session') ||
              label.contains('5 hour'))) {
        return window;
      }
    }
    for (final window in quota.windows) {
      final label = window.label.toLowerCase();
      if (label.contains('5h') ||
          label.contains('session') ||
          label.contains('5 hour')) {
        return window;
      }
    }
    return quota.windows.length > 1 ? quota.windows[1] : null;
  }
}
