import 'package:flutter/material.dart';

import '../models/app_config.dart';
import '../models/provider_quota.dart';
import '../theme/app_theme.dart';
import 'management_service.dart';
import 'provider_field.dart';
import 'quota_module.dart';
import 'quota_repository.dart';

/// Configuration keys owned by the CLIProxyAPI module.
const cliProxyApiConfigKeys = <String>['baseUrl', 'managementKey'];

/// CLIProxyAPI provider module (rich account dashboard source).
class CliProxyApiModule implements QuotaModule<CodexModuleResult> {
  const CliProxyApiModule({QuotaRepository Function()? repositoryFactory})
    : _repositoryFactory = repositoryFactory;

  final QuotaRepository Function()? _repositoryFactory;

  @override
  QuotaProviderId get id => QuotaProviderId.cliProxyApi;

  @override
  bool isEnabled(AppConfig config) => config.hasAny(cliProxyApiConfigKeys);

  @override
  String get displayName => QuotaProviderId.cliProxyApi.displayName;

  @override
  String get description => '账号、额度与请求活动仪表盘';

  @override
  Color get accentColor => AppTheme.cyan;

  @override
  IconData get icon => Icons.dns_rounded;

  @override
  List<ProviderField> get fields => const [
    ProviderField(
      key: 'baseUrl',
      label: 'Management API 地址',
      hint: 'https://your-server.example.com',
      required: true,
      keyboardType: TextInputType.url,
    ),
    ProviderField(
      key: 'managementKey',
      label: '管理密码',
      required: true,
    ),
  ];

  @override
  Future<CodexModuleResult> fetch(AppConfig config) async {
    final baseUrl = config.value('baseUrl');
    if (baseUrl.isEmpty) return const CodexModuleResult(null);
    final repository =
        _repositoryFactory?.call() ??
        ManagementService(
          baseUri: Uri.parse(baseUrl),
          managementKey: config.value('managementKey'),
        );
    // Errors propagate so the dashboard can show the real failure reason
    // while keeping other provider modules unaffected.
    final snapshot = await repository.fetchDashboard();
    return CodexModuleResult(snapshot);
  }
}
