import 'package:flutter/material.dart';

import '../models/app_config.dart';
import '../models/opencode_quota.dart';
import '../models/provider_quota.dart';
import '../theme/app_theme.dart';
import 'opencode_service.dart';
import 'provider_field.dart';
import 'quota_module.dart';

/// Configuration keys owned by the OpenCode Go module.
const openCodeConfigKeys = <String>['openCodeApiKey'];

/// OpenCode Go provider module.
class OpenCodeModule implements QuotaModule<ProviderModuleResult> {
  const OpenCodeModule({
    OpencodeService Function(String apiKey)? serviceFactory,
  }) : _serviceFactory = serviceFactory;

  final OpencodeService Function(String apiKey)? _serviceFactory;

  @override
  QuotaProviderId get id => QuotaProviderId.openCode;

  @override
  bool isEnabled(AppConfig config) => config.hasAny(openCodeConfigKeys);

  @override
  String get displayName => QuotaProviderId.openCode.displayName;

  @override
  String get description => '套餐额度与恢复周期';

  @override
  Color get accentColor => AppTheme.magenta;

  @override
  IconData get icon => Icons.bolt_rounded;

  @override
  List<ProviderField> get fields => const [
    ProviderField(
      key: 'openCodeApiKey',
      label: 'OpenCode API Key',
      hint: 'sk-...',
      obscure: true,
    ),
  ];

  @override
  Future<ProviderModuleResult> fetch(AppConfig config) async {
    final apiKey = config.value('openCodeApiKey');
    if (apiKey.isEmpty) return const ProviderModuleResult(null);
    final service =
        _serviceFactory?.call(apiKey) ?? OpencodeService(apiKey: apiKey);
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
