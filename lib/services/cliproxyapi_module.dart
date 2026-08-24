import '../models/provider_quota.dart';
import 'quota_module.dart';
import 'quota_repository.dart';

/// CLIProxyAPI provider module (the original Codex account dashboard).
class CliProxyApiModule implements QuotaModule<CodexModuleResult> {
  CliProxyApiModule({required this.repository});

  final QuotaRepository repository;

  @override
  bool get isEnabled => true;

  @override
  String get displayName => QuotaProviderId.cliProxyApi.displayName;

  @override
  Future<CodexModuleResult> fetch() async {
    final snapshot = await repository.fetchDashboard();
    return CodexModuleResult(snapshot);
  }
}
