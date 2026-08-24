import '../models/dashboard_snapshot.dart';
import '../models/provider_quota.dart';

/// Result of a single provider module refresh.
sealed class ModuleResult {
  const ModuleResult();
}

class CodexModuleResult extends ModuleResult {
  const CodexModuleResult(this.snapshot);

  final DashboardSnapshot? snapshot;
}

class ProviderModuleResult extends ModuleResult {
  const ProviderModuleResult(this.quota);

  final ProviderQuota? quota;
}

/// A pluggable quota data source. Each provider (CLIProxyAPI, OpenCode,
/// and future additions) implements this to feed its dashboard section.
abstract interface class QuotaModule<T extends ModuleResult> {
  /// Whether the module has enough configuration to attempt a fetch.
  bool get isEnabled;

  /// Human-readable provider name shown in the UI.
  String get displayName;

  Future<T> fetch();
}
