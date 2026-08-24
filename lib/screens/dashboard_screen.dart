import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../models/app_config.dart';
import '../models/dashboard_snapshot.dart';
import '../models/provider_quota.dart';
import '../models/visual_mode.dart';
import '../services/cliproxyapi_module.dart';
import '../services/opencode_module.dart';
import '../services/quota_module.dart';
import '../services/quota_repository.dart';
import '../theme/app_theme.dart';
import '../widgets/account_card.dart';
import '../widgets/energy_core.dart';
import '../widgets/glass_widgets.dart';
import '../widgets/provider_quota_card.dart';
import '../widgets/quantum_emblem.dart';
import '../widgets/request_activity.dart';
import '../widgets/sync_flow_loader.dart';
import 'account_detail_screen.dart';
import 'tools_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({
    required this.config,
    required this.repository,
    required this.onEditConfig,
    required this.visualMode,
    required this.onVisualModeChanged,
    super.key,
    this.autoRefreshInterval = const Duration(minutes: 5),
  });

  final AppConfig config;
  final QuotaRepository repository;
  final Future<void> Function() onEditConfig;
  final VisualMode visualMode;
  final Future<void> Function(VisualMode) onVisualModeChanged;
  final Duration autoRefreshInterval;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  DashboardSnapshot? _snapshot;
  final Map<QuotaProviderId, ProviderQuota> _providerQuotas = {};
  Object? _error;
  bool _loading = true;
  bool _refreshing = false;
  bool _autoRefresh = true;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _refresh();
    _scheduleAutoRefresh();
  }

  @override
  void didUpdateWidget(covariant DashboardScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.repository != widget.repository) {
      _refresh();
    }
    if (oldWidget.autoRefreshInterval != widget.autoRefreshInterval) {
      _scheduleAutoRefresh();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _scheduleAutoRefresh() {
    _timer?.cancel();
    if (!_autoRefresh || widget.autoRefreshInterval <= Duration.zero) return;
    _timer = Timer.periodic(
      widget.autoRefreshInterval,
      (_) => _refresh(silent: true),
    );
  }

  Future<void> _refresh({bool silent = false}) async {
    if (_refreshing) return;
    setState(() {
      _refreshing = true;
      if (_snapshot == null && !silent) _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait<dynamic>([
        _fetchModule(CliProxyApiModule(repository: widget.repository)),
        _fetchModule(OpenCodeModule(apiKey: widget.config.opencodeKey)),
      ]);
      if (!mounted) return;
      setState(() {
        _providerQuotas.clear();
        for (final result in results) {
          if (result is CodexModuleResult) {
            _snapshot = result.snapshot;
          } else if (result is ProviderModuleResult) {
            final quota = result.quota;
            if (quota != null) _providerQuotas[quota.provider] = quota;
          }
        }
        _loading = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
        _loading = false;
      });
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  Future<ModuleResult> _fetchModule(QuotaModule<dynamic> module) async {
    if (!module.isEnabled) {
      return const ProviderModuleResult(null);
    }
    try {
      return await module.fetch();
    } catch (error) {
      // A failed module must not take down other providers.
      if (module.displayName == QuotaProviderId.cliProxyApi.displayName) {
        return CodexModuleResult(null);
      }
      return ProviderModuleResult(null);
    }
  }

  List<Widget> _providerSections() => [
    for (final provider in QuotaProviderId.values)
      if (_providerQuotas.containsKey(provider)) ...[
        const SizedBox(height: 18),
        SectionTitle(title: provider.displayName, subtitle: '额度模块'),
        const SizedBox(height: 10),
        ProviderQuotaCard(
          key: Key('quota-card-${provider.name}'),
          quota: _providerQuotas[provider]!,
        ),
      ],
  ];

  Future<void> _refreshWithFeedback() async {
    await HapticFeedback.mediumImpact();
    await _refresh();
  }

  void _toggleAutoRefresh(bool value) {
    unawaited(HapticFeedback.selectionClick());
    setState(() => _autoRefresh = value);
    _scheduleAutoRefresh();
  }

  void _openAccount(int index) {
    unawaited(HapticFeedback.lightImpact());
    final account = _snapshot!.accounts[index];
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AccountDetailScreen(account: account),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AppBackdrop(
        child: SafeArea(
          child: RefreshIndicator(
            onRefresh: _refreshWithFeedback,
            color: AppTheme.cyan,
            backgroundColor: const Color(0xFF11192A),
            child: CustomScrollView(
              key: const Key('dashboard-scroll'),
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 32),
                  sliver: SliverList.list(
                    children: [
                      _Header(
                        refreshing: _refreshing,
                        autoRefresh: _autoRefresh,
                        onRefresh: _refreshWithFeedback,
                        onAutoRefreshChanged: _toggleAutoRefresh,
                        onEditConfig: widget.onEditConfig,
                        visualMode: widget.visualMode,
                        onVisualModeChanged: widget.onVisualModeChanged,
                        onOpenTools: () {
                          unawaited(HapticFeedback.lightImpact());
                          Navigator.of(context).push(
                            PageRouteBuilder<void>(
                              transitionDuration: const Duration(
                                milliseconds: 160,
                              ),
                              reverseTransitionDuration: const Duration(
                                milliseconds: 140,
                              ),
                              pageBuilder:
                                  (context, animation, secondaryAnimation) =>
                                      ToolsScreen(config: widget.config),
                              transitionsBuilder:
                                  (
                                    context,
                                    animation,
                                    secondaryAnimation,
                                    child,
                                  ) {
                                    final curved = CurvedAnimation(
                                      parent: animation,
                                      curve: Curves.easeOutCubic,
                                      reverseCurve: Curves.easeInCubic,
                                    );
                                    return FadeTransition(
                                      opacity: curved,
                                      child: child,
                                    );
                                  },
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 10),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 620),
                        reverseDuration: const Duration(milliseconds: 360),
                        switchInCurve: Curves.easeOutCubic,
                        switchOutCurve: Curves.easeOutCubic,
                        layoutBuilder: (currentChild, previousChildren) =>
                            Stack(
                              alignment: Alignment.topCenter,
                              children: [...previousChildren, ?currentChild],
                            ),
                        transitionBuilder: (child, animation) =>
                            FadeTransition(opacity: animation, child: child),
                        child: _loading
                            ? SyncFlowLoader(
                                key: const ValueKey('loading'),
                                visualMode: widget.visualMode,
                              )
                            : _snapshot == null
                            ? _FatalErrorPanel(
                                key: const ValueKey('fatal'),
                                error: _error,
                                onRetry: _refresh,
                              )
                            : Column(
                                key: const ValueKey('dashboard-content'),
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _ServicePanel(
                                    snapshot: _snapshot!,
                                    error: _error,
                                  ),
                                  if (_error != null) ...[
                                    const SizedBox(height: 10),
                                    _StaleDataBanner(
                                      error: _error!,
                                      onRetry: _refresh,
                                    ),
                                  ],
                                  const SizedBox(height: 10),
                                  _StatsGrid(
                                    key: const Key('summary-stats-grid'),
                                    snapshot: _snapshot!,
                                  ),
                                  const SizedBox(height: 10),
                                  _TrafficPulsePanel(snapshot: _snapshot!),
                                  const SizedBox(height: 18),
                                  SectionTitle(
                                    title: 'Codex',
                                    subtitle: _snapshot!.accounts.isEmpty
                                        ? '未找到启用的 Codex 认证文件'
                                        : '${_snapshot!.totalAccounts} 个账号',
                                  ),
                                  const SizedBox(height: 10),
                                  if (_snapshot!.accounts.isEmpty)
                                    const _EmptyAccounts()
                                  else if (widget.visualMode ==
                                      VisualMode.energy)
                                    _EnergyAccountGrid(
                                      snapshot: _snapshot!,
                                      refreshing: _refreshing,
                                      onTap: _openAccount,
                                    )
                                  else
                                    _AccountGrid(
                                      snapshot: _snapshot!,
                                      onTap: _openAccount,
                                    ),
                                  ..._providerSections(),
                                ],
                              ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.refreshing,
    required this.autoRefresh,
    required this.onRefresh,
    required this.onAutoRefreshChanged,
    required this.onEditConfig,
    required this.visualMode,
    required this.onVisualModeChanged,
    required this.onOpenTools,
  });

  final bool refreshing;
  final bool autoRefresh;
  final VoidCallback onRefresh;
  final ValueChanged<bool> onAutoRefreshChanged;
  final Future<void> Function() onEditConfig;
  final VisualMode visualMode;
  final Future<void> Function(VisualMode) onVisualModeChanged;
  final VoidCallback onOpenTools;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 48),
      child: Row(
        children: [
          const QuantumEmblem(),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Quota Dash',
                  style: Theme.of(
                    context,
                  ).textTheme.titleMedium?.copyWith(letterSpacing: -0.25),
                ),
                const Text(
                  'MULTI-PROVIDER QUOTA',
                  style: TextStyle(
                    color: Color(0xFF748198),
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.05,
                  ),
                ),
              ],
            ),
          ),
          _SettingsButton(
            autoRefresh: autoRefresh,
            onAutoRefreshChanged: onAutoRefreshChanged,
            onEditConfig: onEditConfig,
            visualMode: visualMode,
            onVisualModeChanged: onVisualModeChanged,
            onOpenTools: onOpenTools,
          ),
          IconButton(
            key: const Key('refresh-button'),
            tooltip: '立即刷新',
            onPressed: refreshing ? null : onRefresh,
            icon: AnimatedSwitcher(
              duration: const Duration(milliseconds: 260),
              transitionBuilder: (child, animation) => RotationTransition(
                turns: Tween<double>(begin: 0.7, end: 1).animate(animation),
                child: FadeTransition(opacity: animation, child: child),
              ),
              child: refreshing
                  ? const SizedBox.square(
                      key: ValueKey('refreshing'),
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(
                      Icons.refresh_rounded,
                      key: ValueKey('idle'),
                      size: 22,
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsButton extends StatefulWidget {
  const _SettingsButton({
    required this.autoRefresh,
    required this.onAutoRefreshChanged,
    required this.onEditConfig,
    required this.visualMode,
    required this.onVisualModeChanged,
    required this.onOpenTools,
  });

  final bool autoRefresh;
  final ValueChanged<bool> onAutoRefreshChanged;
  final Future<void> Function() onEditConfig;
  final VisualMode visualMode;
  final Future<void> Function(VisualMode) onVisualModeChanged;
  final VoidCallback onOpenTools;

  @override
  State<_SettingsButton> createState() => _SettingsButtonState();
}

class _SettingsButtonState extends State<_SettingsButton> {
  Future<void> _open() async {
    unawaited(HapticFeedback.lightImpact());
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.65),
      builder: (sheetContext) => _SettingsSheet(
        autoRefresh: widget.autoRefresh,
        onAutoRefreshChanged: widget.onAutoRefreshChanged,
        visualMode: widget.visualMode,
        onVisualModeChanged: widget.onVisualModeChanged,
        onEditConfig: () async {
          Navigator.of(sheetContext).pop();
          await widget.onEditConfig();
        },
        onOpenTools: () {
          Navigator.of(sheetContext).pop();
          widget.onOpenTools();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      key: const Key('dashboard-menu'),
      tooltip: '设置',
      onPressed: _open,
      icon: const Icon(Icons.tune_rounded, size: 21),
    );
  }
}

class _SettingsSheet extends StatefulWidget {
  const _SettingsSheet({
    required this.autoRefresh,
    required this.onAutoRefreshChanged,
    required this.onEditConfig,
    required this.visualMode,
    required this.onVisualModeChanged,
    required this.onOpenTools,
  });

  final bool autoRefresh;
  final ValueChanged<bool> onAutoRefreshChanged;
  final Future<void> Function() onEditConfig;
  final VisualMode visualMode;
  final Future<void> Function(VisualMode) onVisualModeChanged;
  final VoidCallback onOpenTools;

  @override
  State<_SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends State<_SettingsSheet> {
  late VisualMode _visualMode;

  @override
  void initState() {
    super.initState();
    _visualMode = widget.visualMode;
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        padding: const EdgeInsets.fromLTRB(18, 10, 18, 20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF172235), Color(0xFF0E1523)],
          ),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: const Color(0xFF2C3C55)),
          boxShadow: const [
            BoxShadow(
              color: Color(0xB3000000),
              blurRadius: 38,
              offset: Offset(0, 14),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFF4A5870),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                const GradientIcon(
                  icon: Icons.tune_rounded,
                  size: 42,
                  iconSize: 21,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '控制中心',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const Text(
                        'DISPLAY & CONNECTION',
                        style: TextStyle(
                          color: Color(0xFF75839A),
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.05,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: '关闭',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded, size: 21),
                ),
              ],
            ),
            const SizedBox(height: 22),
            const _SettingsSectionLabel(
              icon: Icons.palette_outlined,
              label: '显示模式',
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _ThemeChoice(
                    title: '深海控制台',
                    subtitle: '完整信息卡片',
                    icon: Icons.grid_view_rounded,
                    selected: _visualMode == VisualMode.console,
                    colors: const [AppTheme.cyan, AppTheme.violet],
                    onTap: () => _selectMode(VisualMode.console),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _ThemeChoice(
                    title: '能量核心',
                    subtitle: '动态轨道视图',
                    icon: Icons.blur_circular_rounded,
                    selected: _visualMode == VisualMode.energy,
                    colors: const [AppTheme.violet, AppTheme.magenta],
                    onTap: () => _selectMode(VisualMode.energy),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const _SettingsSectionLabel(
              icon: Icons.settings_suggest_outlined,
              label: '运行偏好',
            ),
            const SizedBox(height: 10),
            _SettingsTile(
              icon: Icons.sync_rounded,
              iconColor: AppTheme.cyan,
              title: '自动刷新',
              subtitle: widget.autoRefresh ? '每 5 分钟同步一次额度' : '仅在手动操作时刷新',
              trailing: Switch.adaptive(
                key: const Key('auto-refresh-switch'),
                value: widget.autoRefresh,
                onChanged: widget.onAutoRefreshChanged,
              ),
            ),
            const SizedBox(height: 10),
            _SettingsTile(
              icon: Icons.admin_panel_settings_outlined,
              iconColor: AppTheme.violet,
              title: '连接配置',
              subtitle: '修改 Management API 与管理密码',
              onTap: widget.onEditConfig,
              trailing: const Icon(
                Icons.arrow_forward_rounded,
                color: Color(0xFF8B98AE),
                size: 19,
              ),
            ),
            const SizedBox(height: 10),
            _SettingsTile(
              icon: Icons.apps_rounded,
              iconColor: AppTheme.magenta,
              title: '工具箱',
              subtitle: '模型列表、API Key 与版本检查',
              onTap: widget.onOpenTools,
              trailing: const Icon(
                Icons.arrow_forward_rounded,
                color: Color(0xFF8B98AE),
                size: 19,
              ),
            ),
            const SizedBox(height: 14),
            const Center(
              child: Text(
                'Quota Dash · v${AppConfig.appVersion}',
                style: TextStyle(
                  color: Color(0xFF657289),
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.35,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _selectMode(VisualMode mode) async {
    try {
      await HapticFeedback.selectionClick();
      await widget.onVisualModeChanged(mode);
      if (mounted) setState(() => _visualMode = mode);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('外观保存失败')));
    }
  }
}

class _SettingsSectionLabel extends StatelessWidget {
  const _SettingsSectionLabel({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 15, color: const Color(0xFF8290A7)),
        const SizedBox(width: 7),
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF9BA8BD),
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.45,
          ),
        ),
      ],
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.trailing,
    required this.subtitle,
    this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final Widget trailing;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xA3121B2A),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap == null
            ? null
            : () {
                unawaited(HapticFeedback.selectionClick());
                onTap!();
              },
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: iconColor.withValues(alpha: 0.16)),
                ),
                child: Icon(icon, size: 19, color: iconColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(fontSize: 11),
                    ),
                  ],
                ),
              ),
              trailing,
            ],
          ),
        ),
      ),
    );
  }
}

class _ThemeChoice extends StatelessWidget {
  const _ThemeChoice({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.selected,
    required this.colors,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final bool selected;
  final List<Color> colors;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 260),
        height: 116,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: LinearGradient(
            colors: colors
                .map((color) => color.withValues(alpha: 0.18))
                .toList(),
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(
            color: selected ? colors.first : const Color(0xFF2A354A),
            width: selected ? 1.4 : 0.8,
          ),
        ),
        child: Stack(
          children: [
            if (selected)
              Positioned(
                top: 9,
                right: 9,
                child: Icon(
                  Icons.check_circle_rounded,
                  color: colors.first,
                  size: 17,
                ),
              ),
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, color: colors.first, size: 29),
                  const SizedBox(height: 8),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(fontSize: 9),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ServicePanel extends StatelessWidget {
  const _ServicePanel({required this.snapshot, required this.error});

  final DashboardSnapshot snapshot;
  final Object? error;

  @override
  Widget build(BuildContext context) {
    final online = error == null;
    final color = online ? AppTheme.success : AppTheme.warning;
    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0x8A111827),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          _PulsingStatusDot(color: color),
          const SizedBox(width: 8),
          Text(
            online ? 'API 在线' : '缓存数据',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
          const SizedBox(width: 8),
          const Spacer(),
          Text(
            DateFormat('HH:mm').format(snapshot.checkedAt.toLocal()),
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _PulsingStatusDot extends StatefulWidget {
  const _PulsingStatusDot({required this.color});

  final Color color;

  @override
  State<_PulsingStatusDot> createState() => _PulsingStatusDotState();
}

class _PulsingStatusDotState extends State<_PulsingStatusDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final pulse = Curves.easeInOut.transform(_controller.value);
        return Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: widget.color,
            boxShadow: [
              BoxShadow(
                color: widget.color.withValues(alpha: 0.22 + pulse * 0.34),
                blurRadius: 5 + pulse * 5,
                spreadRadius: pulse * 1.5,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({required this.snapshot, super.key});

  final DashboardSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final remaining = snapshot.averageRemainingPercent;
    final cards = [
      _StatCard(
        label: '账号总数',
        value: '${snapshot.totalAccounts}',
        icon: Icons.people_alt_rounded,
        color: AppTheme.cyan,
      ),
      _StatCard(
        label: '当前可用',
        value: '${snapshot.availableAccounts}',
        icon: Icons.bolt_rounded,
        color: AppTheme.success,
      ),
      _StatCard(
        label: '平均剩余',
        value: remaining == null ? '--' : '${remaining.toStringAsFixed(0)}%',
        icon: Icons.donut_large_rounded,
        color: AppTheme.violet,
      ),
      _StatCard(
        label: '异常账号',
        value: '${snapshot.errorAccounts}',
        icon: Icons.warning_amber_rounded,
        color: snapshot.errorAccounts == 0 ? AppTheme.success : AppTheme.danger,
      ),
    ];
    return Row(
      children: [
        for (var index = 0; index < cards.length; index++) ...[
          if (index > 0) const SizedBox(width: 6),
          Expanded(child: cards[index]),
        ],
      ],
    );
  }
}

class _TrafficPulsePanel extends StatelessWidget {
  const _TrafficPulsePanel({required this.snapshot});

  final DashboardSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final rate = snapshot.successRate;
    return GlassCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      borderColor: AppTheme.cyan.withValues(alpha: 0.2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: AppTheme.cyan,
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: AppTheme.cyan, blurRadius: 9)],
                ),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'REQUEST PULSE',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.15,
                  ),
                ),
              ),
              _PulseMetric(label: '近期', value: '${snapshot.recentRequests}'),
              const SizedBox(width: 14),
              _PulseMetric(
                label: '成功率',
                value: rate == null ? '--' : '${rate.toStringAsFixed(1)}%',
                color: rate != null && rate < 90
                    ? AppTheme.warning
                    : AppTheme.success,
              ),
            ],
          ),
          const SizedBox(height: 10),
          RequestSparkline(buckets: snapshot.recentRequestBuckets, height: 62),
          const SizedBox(height: 6),
          Text(
            snapshot.recentRequestBuckets.isEmpty
                ? '等待 CLIProxyAPI 返回近期请求时间桶'
                : '青色曲线表示请求流量，红点表示该时段存在失败请求',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(fontSize: 10),
          ),
        ],
      ),
    );
  }
}

class _PulseMetric extends StatelessWidget {
  const _PulseMetric({
    required this.label,
    required this.value,
    this.color = AppTheme.cyan,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 14,
            fontWeight: FontWeight.w800,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(fontSize: 8, height: 1),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 62,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0x9C111827),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.16), width: 0.7),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 13),
              const SizedBox(width: 4),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    value,
                    maxLines: 1,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontSize: 17,
                      color: color,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              maxLines: 1,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(fontSize: 10, height: 1),
            ),
          ),
        ],
      ),
    );
  }
}

class _AccountGrid extends StatelessWidget {
  const _AccountGrid({required this.snapshot, required this.onTap});

  final DashboardSnapshot snapshot;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 850 ? 2 : 1;
        final width = (constraints.maxWidth - (columns - 1) * 16) / columns;
        return Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            for (var index = 0; index < snapshot.accounts.length; index++)
              SizedBox(
                key: Key('account-card-$index'),
                width: width,
                child: _AnimatedAccountCard(
                  key: ValueKey(snapshot.accounts[index].id),
                  index: index,
                  child: AccountCard(
                    account: snapshot.accounts[index],
                    onTap: () => onTap(index),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _EnergyAccountGrid extends StatelessWidget {
  const _EnergyAccountGrid({
    required this.snapshot,
    required this.refreshing,
    required this.onTap,
  });

  final DashboardSnapshot snapshot;
  final bool refreshing;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1000
            ? 4
            : constraints.maxWidth >= 650
            ? 3
            : constraints.maxWidth >= 350
            ? 2
            : 1;
        const spacing = 10.0;
        final width =
            (constraints.maxWidth - (columns - 1) * spacing) / columns;
        return Wrap(
          alignment: WrapAlignment.center,
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (var index = 0; index < snapshot.accounts.length; index++)
              SizedBox(
                width: width,
                child: _AnimatedAccountCard(
                  key: ValueKey('energy-${snapshot.accounts[index].id}'),
                  index: index,
                  child: EnergyAccountCore(
                    key: Key('energy-account-$index'),
                    account: snapshot.accounts[index],
                    refreshing: refreshing,
                    onTap: () => onTap(index),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _AnimatedAccountCard extends StatefulWidget {
  const _AnimatedAccountCard({
    required this.index,
    required this.child,
    super.key,
  });

  final int index;
  final Widget child;

  @override
  State<_AnimatedAccountCard> createState() => _AnimatedAccountCardState();
}

class _AnimatedAccountCardState extends State<_AnimatedAccountCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;
  late final Animation<Offset> _position;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    );
    final curve = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
    _opacity = Tween<double>(begin: 0, end: 1).animate(curve);
    _position = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(curve);
    Future<void>.delayed(
      Duration(milliseconds: widget.index.clamp(0, 6).toInt() * 70),
      () {
        if (mounted) _controller.forward();
      },
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(position: _position, child: widget.child),
    );
  }
}

class _FatalErrorPanel extends StatelessWidget {
  const _FatalErrorPanel({
    required this.error,
    required this.onRetry,
    super.key,
  });

  final Object? error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      borderColor: AppTheme.danger.withValues(alpha: 0.35),
      child: Column(
        children: [
          const GradientIcon(
            icon: Icons.cloud_off_rounded,
            size: 62,
            iconSize: 30,
          ),
          const SizedBox(height: 18),
          Text(
            '无法连接 Management API',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 9),
          Text(
            error?.toString() ?? '未知错误',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            key: const Key('retry-button'),
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('重新连接'),
          ),
        ],
      ),
    );
  }
}

class _StaleDataBanner extends StatelessWidget {
  const _StaleDataBanner({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(14),
      borderColor: AppTheme.warning.withValues(alpha: 0.3),
      child: Row(
        children: [
          const Icon(Icons.history_rounded, color: AppTheme.warning),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '刷新失败，保留上次数据：$error',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          TextButton(onPressed: onRetry, child: const Text('重试')),
        ],
      ),
    );
  }
}

class _EmptyAccounts extends StatelessWidget {
  const _EmptyAccounts();

  @override
  Widget build(BuildContext context) {
    return const GlassCard(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Column(
          children: [
            Icon(Icons.inbox_rounded, size: 46, color: Color(0xFF77849E)),
            SizedBox(height: 12),
            Text('没有启用的 Codex 账号'),
          ],
        ),
      ),
    );
  }
}
