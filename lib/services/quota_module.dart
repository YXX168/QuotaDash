import 'package:flutter/material.dart';

import '../models/app_config.dart';
import '../models/dashboard_snapshot.dart';
import '../models/provider_quota.dart';
import 'provider_field.dart';

/// Result of a single provider module refresh.
sealed class ModuleResult {
  const ModuleResult();
}

/// Rich result carrying the full CLIProxyAPI dashboard snapshot.
class CodexModuleResult extends ModuleResult {
  const CodexModuleResult(this.snapshot);

  final DashboardSnapshot? snapshot;
}

/// Unified quota-window result used by every non-CLIProxyAPI provider.
class ProviderModuleResult extends ModuleResult {
  const ProviderModuleResult(this.quota);

  final ProviderQuota? quota;
}

/// A pluggable quota data source. Each provider (CLIProxyAPI, OpenCode,
/// and future additions) implements this to feed its dashboard section.
abstract interface class QuotaModule<T extends ModuleResult> {
  /// Stable identifier persisted with the module's settings.
  QuotaProviderId get id;

  /// Whether the module has enough configuration to attempt a fetch.
  bool isEnabled(AppConfig config);

  /// Human-readable provider name shown in the dashboard and settings.
  String get displayName;

  /// Short description shown under the module name.
  String get description;

  /// Accent color for cards, energy cores and badges.
  Color get accentColor;

  /// Icon representing this provider across both visual modes.
  IconData get icon;

  /// Configuration fields rendered by the dynamic settings screen.
  List<ProviderField> get fields;

  Future<T> fetch(AppConfig config);
}
