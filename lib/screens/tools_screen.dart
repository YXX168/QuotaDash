import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/app_config.dart';
import '../services/proxy_api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_widgets.dart';
import '../widgets/quantum_emblem.dart';
import 'api_keys_screen.dart';
import 'models_screen.dart';

class ToolsScreen extends StatefulWidget {
  const ToolsScreen({required this.config, super.key});

  final AppConfig config;

  @override
  State<ToolsScreen> createState() => _ToolsScreenState();
}

class _ToolsScreenState extends State<ToolsScreen> {
  late final ProxyApiService _service;
  String? _latestVersion;
  bool _checkingVersion = false;

  @override
  void initState() {
    super.initState();
    _service = ProxyApiService(
      baseUri: Uri.parse(widget.config.value('baseUrl')),
      managementKey: widget.config.value('managementKey'),
    );
    _checkVersion();
  }

  @override
  void dispose() {
    _service.dispose();
    super.dispose();
  }

  Future<void> _checkVersion() async {
    if (_checkingVersion) return;
    setState(() => _checkingVersion = true);
    try {
      final version = await _service.fetchLatestVersion();
      if (mounted) setState(() => _latestVersion = version);
    } catch (_) {
      // Silently ignore version check errors.
    } finally {
      if (mounted) setState(() => _checkingVersion = false);
    }
  }

  void _navigate(Widget screen) {
    unawaited(HapticFeedback.lightImpact());
    Navigator.of(context).push(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 160),
        reverseTransitionDuration: const Duration(milliseconds: 140),
        pageBuilder: (context, animation, secondaryAnimation) => screen,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInCubic,
          );
          return FadeTransition(opacity: curved, child: child);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AppBackdrop(
        child: SafeArea(
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 32),
                sliver: SliverList.list(
                  children: [
                    Row(
                      children: [
                        IconButton(
                          tooltip: '返回',
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.arrow_back_rounded, size: 22),
                        ),
                        const SizedBox(width: 4),
                        const QuantumEmblem(size: 34),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '工具箱',
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(letterSpacing: -0.25),
                              ),
                              const Text(
                                'PROXY MANAGEMENT TOOLS',
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
                      ],
                    ),
                    const SizedBox(height: 20),
                    const SectionTitle(
                      title: '管理工具',
                      subtitle: '查看和管理 CLIProxyAPI 实例',
                    ),
                    const SizedBox(height: 14),
                    _ToolCard(
                      icon: Icons.model_training_rounded,
                      iconColor: AppTheme.cyan,
                      title: '模型列表',
                      subtitle: '查看已配置的 AI 模型与别名',
                      onTap: () => _navigate(
                        ModelsScreen(service: _service, config: widget.config),
                      ),
                    ),
                    const SizedBox(height: 10),
                    _ToolCard(
                      icon: Icons.key_rounded,
                      iconColor: AppTheme.success,
                      title: 'API Key 管理',
                      subtitle: '查看客户端 API Key 列表',
                      onTap: () => _navigate(ApiKeysScreen(service: _service)),
                    ),
                    const SizedBox(height: 20),
                    const SectionTitle(
                      title: '版本信息',
                      subtitle: '检查 CLIProxyAPI 最新版本',
                    ),
                    const SizedBox(height: 14),
                    GlassCard(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                      child: Row(
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: AppTheme.cyan.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(13),
                              border: Border.all(
                                color: AppTheme.cyan.withValues(alpha: 0.16),
                              ),
                            ),
                            child: _checkingVersion
                                ? const Padding(
                                    padding: EdgeInsets.all(12),
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: AppTheme.cyan,
                                    ),
                                  )
                                : const Icon(
                                    Icons.system_update_rounded,
                                    size: 20,
                                    color: AppTheme.cyan,
                                  ),
                          ),
                          const SizedBox(width: 13),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  '最新版本',
                                  style: TextStyle(fontWeight: FontWeight.w700),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  _latestVersion != null
                                      ? _latestVersion!
                                      : _checkingVersion
                                      ? '正在检查...'
                                      : '点击右侧按钮检查',
                                  style: Theme.of(
                                    context,
                                  ).textTheme.bodySmall?.copyWith(fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                          TextButton.icon(
                            onPressed: _checkingVersion ? null : _checkVersion,
                            icon: const Icon(Icons.refresh_rounded, size: 17),
                            label: const Text('检查'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    Center(
                      child: Text(
                        '连接至 ${widget.config.value('baseUrl')}',
                        style: const TextStyle(
                          color: Color(0xFF657289),
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ToolCard extends StatelessWidget {
  const _ToolCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xA3121B2A),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: iconColor.withValues(alpha: 0.18)),
                ),
                child: Icon(icon, size: 22, color: iconColor),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(fontSize: 11),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_rounded,
                color: Color(0xFF8B98AE),
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
