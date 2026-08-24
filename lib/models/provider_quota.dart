/// Identifies a supported quota provider module.
enum QuotaProviderId { cliProxyApi, openCode }

extension QuotaProviderIdX on QuotaProviderId {
  String get displayName {
    switch (this) {
      case QuotaProviderId.cliProxyApi:
        return 'CLIProxyAPI';
      case QuotaProviderId.openCode:
        return 'OpenCode Go';
    }
  }
}

/// A single quota window exposed by any provider module.
class ProviderQuotaWindow {
  const ProviderQuotaWindow({
    required this.label,
    required this.remainingPercent,
    this.resetAt,
  });

  final String label;
  final double? remainingPercent;
  final DateTime? resetAt;
}

/// Unified quota snapshot from a single provider module.
class ProviderQuota {
  const ProviderQuota({
    required this.provider,
    required this.windows,
    this.error,
    this.checkedAt,
  });

  final QuotaProviderId provider;
  final List<ProviderQuotaWindow> windows;

  /// Non-null when the provider failed; the panel shows the error inline.
  final Object? error;
  final DateTime? checkedAt;

  bool get hasError => error != null;

  double? get averageRemainingPercent {
    final values = windows
        .map((entry) => entry.remainingPercent)
        .whereType<double>()
        .toList();
    if (values.isEmpty) return null;
    return values.reduce((a, b) => a + b) / values.length;
  }
}
