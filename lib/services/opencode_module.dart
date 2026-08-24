import '../models/opencode_quota.dart';
import '../models/provider_quota.dart';
import 'opencode_service.dart';
import 'quota_module.dart';

/// OpenCode Go provider module.
class OpenCodeModule implements QuotaModule<ProviderModuleResult> {
  OpenCodeModule({required this.apiKey});

  final String apiKey;

  @override
  bool get isEnabled => apiKey.trim().isNotEmpty;

  @override
  String get displayName => QuotaProviderId.openCode.displayName;

  @override
  Future<ProviderModuleResult> fetch() async {
    if (!isEnabled) return const ProviderModuleResult(null);
    final service = OpencodeService(apiKey: apiKey);
    try {
      final quota = await service.fetchQuota();
      return ProviderModuleResult(_toUnified(quota));
    } catch (error) {
      // A failed probe must not take down other modules.
      return ProviderModuleResult(
        ProviderQuota(
          provider: QuotaProviderId.openCode,
          windows: const [],
          error: error,
        ),
      );
    } finally {
      service.dispose();
    }
  }

  ProviderQuota _toUnified(OpencodeQuota quota) {
    return ProviderQuota(
      provider: QuotaProviderId.openCode,
      checkedAt: DateTime.now(),
      windows: [
        for (final entry in quota.windows)
          if (entry.window != null)
            ProviderQuotaWindow(
              label: entry.label,
              remainingPercent: entry.window!.remainingPercent,
              resetAt: entry.window!.resetAt,
            ),
      ],
    );
  }
}
