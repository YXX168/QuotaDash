import '../models/app_config.dart';
import 'cliproxyapi_module.dart';
import 'opencode_module.dart';
import 'quota_module.dart';
import 'quota_repository.dart';

/// Signature used to construct one bound quota module instance.
typedef ModuleFactory =
    QuotaModule Function(
      AppConfig config, {
      QuotaRepository? cliProxyRepository,
    });

/// Central registry of every quota provider module compiled into the app.
///
/// Adding a new provider means implementing [QuotaModule] and appending its
/// factory here - no dashboard, settings or storage changes are required.
class ProviderRegistry {
  const ProviderRegistry({this.factories = defaultFactories});

  /// The standard registry with every built-in provider module.
  static const ProviderRegistry defaultRegistry = ProviderRegistry();

  static const List<ModuleFactory> defaultFactories = [
    _createCliProxyModule,
    _createOpenCodeModule,
  ];

  final List<ModuleFactory> factories;

  /// Fresh module instances ready to fetch with [config].
  List<QuotaModule> createModules(
    AppConfig config, {
    QuotaRepository? cliProxyRepository,
  }) => [
    for (final factory in factories)
      factory(config, cliProxyRepository: cliProxyRepository),
  ];

  /// Module metadata used by the dynamic settings screen.
  List<QuotaModule> get modules => createModules(const AppConfig());

  static QuotaModule _createCliProxyModule(
    AppConfig config, {
    QuotaRepository? cliProxyRepository,
  }) => CliProxyApiModule(
    repositoryFactory: cliProxyRepository == null
        ? null
        : () => cliProxyRepository,
  );

  static QuotaModule _createOpenCodeModule(
    AppConfig config, {
    QuotaRepository? cliProxyRepository,
  }) => const OpenCodeModule();
}
