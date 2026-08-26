import 'package:flutter/material.dart';

import '../models/app_config.dart';
import '../models/model_info.dart';
import '../services/proxy_api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_widgets.dart';

class ModelsScreen extends StatefulWidget {
  const ModelsScreen({required this.service, required this.config, super.key});

  final ProxyApiService service;
  final AppConfig config;

  @override
  State<ModelsScreen> createState() => _ModelsScreenState();
}

class _ModelsScreenState extends State<ModelsScreen> {
  ModelListResult? _result;
  Object? _error;
  bool _loading = true;

  static const _providerColors = <Color>[
    AppTheme.cyan,
    AppTheme.violet,
    AppTheme.magenta,
    AppTheme.success,
    AppTheme.warning,
  ];

  @override
  void initState() {
    super.initState();
    _loadModels();
  }

  Future<void> _loadModels() async {
    setState(() {
      if (_result == null) _loading = true;
      _error = null;
    });
    try {
      final result = await widget.service.fetchModels();
      if (!mounted) return;
      setState(() {
        _result = result;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.of(context).canPop();
    return Scaffold(
      body: AppBackdrop(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 18, 4),
                child: Row(
                  children: [
                    if (canPop)
                      IconButton(
                        tooltip: '返回',
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.arrow_back_rounded),
                      ),
                    if (canPop) const SizedBox(width: 4),
                    const GradientIcon(
                      icon: Icons.category_rounded,
                      size: 40,
                      iconSize: 20,
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '模型列表',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const Text(
                            'CONFIGURED MODELS',
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
              ),
              const SizedBox(height: 6),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _loadModels,
                  color: AppTheme.cyan,
                  backgroundColor: const Color(0xFF11192A),
                  child: CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: _buildSlivers(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildSlivers() {
    if (_loading) {
      return const [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(child: CircularProgressIndicator(color: AppTheme.cyan)),
        ),
      ];
    }
    if (_error != null) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: _ErrorView(error: _error!, onRetry: _loadModels),
        ),
      ];
    }
    final result = _result;
    if (result == null || result.providers.isEmpty) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: _EmptyView(onRetry: _loadModels),
        ),
      ];
    }

    return [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        sliver: SliverList.list(
          children: [
            _SummaryCard(
              totalModels: result.totalModels,
              totalExcluded: result.totalExcluded,
              providerCount: result.providers.length,
              baseUrl: widget.config.value('baseUrl'),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        sliver: SliverList.builder(
          itemCount: result.providers.length,
          itemBuilder: (context, index) {
            final group = result.providers[index];
            final color = _providerColors[index % _providerColors.length];
            return Padding(
              padding: EdgeInsets.only(
                bottom: index < result.providers.length - 1 ? 14 : 0,
              ),
              child: _ProviderGroupCard(group: group, accentColor: color),
            );
          },
        ),
      ),
    ];
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.totalModels,
    required this.totalExcluded,
    required this.providerCount,
    required this.baseUrl,
  });

  final int totalModels;
  final int totalExcluded;
  final int providerCount;
  final String baseUrl;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(18),
      borderColor: AppTheme.cyan.withValues(alpha: 0.2),
      child: Row(
        children: [
          const GradientIcon(
            icon: Icons.category_rounded,
            size: 52,
            iconSize: 26,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('已配置模型', style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 2),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '$totalModels',
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(color: AppTheme.cyan),
                    ),
                    const SizedBox(width: 6),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text(
                        '个模型 · $providerCount 个提供商',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
                if (baseUrl.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    baseUrl,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontSize: 10,
                      color: const Color(0xFF6B7689),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (totalExcluded > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.warning.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: AppTheme.warning.withValues(alpha: 0.3),
                ),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.block_rounded, size: 13, color: AppTheme.warning),
                  SizedBox(width: 5),
                  Text(
                    '已排除',
                    style: TextStyle(
                      color: AppTheme.warning,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _ProviderGroupCard extends StatelessWidget {
  const _ProviderGroupCard({required this.group, required this.accentColor});

  final ProviderGroup group;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(18),
      borderColor: accentColor.withValues(alpha: 0.22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionTitle(
            title: group.provider,
            subtitle:
                '${group.models.length} 个可用模型'
                '${group.excludedModels.isEmpty ? '' : ' · ${group.excludedModels.length} 个已排除'}',
            trailing: Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: accentColor,
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: accentColor, blurRadius: 7)],
              ),
            ),
          ),
          const SizedBox(height: 14),
          for (final model in group.models)
            _ModelTile(model: model, accentColor: accentColor),
          if (group.excludedModels.isNotEmpty) ...[
            const SizedBox(height: 6),
            const Padding(
              padding: EdgeInsets.only(top: 4, bottom: 8),
              child: Text(
                '已排除模型',
                style: TextStyle(
                  color: Color(0xFF7A8499),
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            for (final name in group.excludedModels)
              _ExcludedModelTile(name: name),
          ],
        ],
      ),
    );
  }
}

class _ModelTile extends StatelessWidget {
  const _ModelTile({required this.model, required this.accentColor});

  final ModelInfo model;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    final hasAlias = model.alias != null && model.alias != model.name;
    final hasLabel = model.label != null && model.label != model.name;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: accentColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  model.name,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFE2E8F5),
                  ),
                ),
                if (hasAlias)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      '别名：${model.alias}',
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(fontSize: 11),
                    ),
                  ),
                if (hasLabel)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      '显示名称：${model.label}',
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(fontSize: 11),
                    ),
                  ),
              ],
            ),
          ),
          if (hasAlias || hasLabel)
            const Icon(
              Icons.label_outline_rounded,
              size: 15,
              color: Color(0xFF7A8499),
            ),
        ],
      ),
    );
  }
}

class _ExcludedModelTile extends StatelessWidget {
  const _ExcludedModelTile({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          const Icon(Icons.block_rounded, size: 13, color: Color(0xFF5C6678)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              name,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF5C6678),
                decoration: TextDecoration.lineThrough,
                decorationColor: Color(0xFF5C6678),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      borderColor: AppTheme.danger.withValues(alpha: 0.35),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const GradientIcon(
            icon: Icons.cloud_off_rounded,
            size: 62,
            iconSize: 30,
          ),
          const SizedBox(height: 18),
          Text('加载模型列表失败', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 9),
          Text(
            error.toString(),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('重试'),
          ),
        ],
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.inbox_rounded, size: 46, color: Color(0xFF77849E)),
          const SizedBox(height: 12),
          const Text('暂无模型数据'),
          const SizedBox(height: 16),
          TextButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('刷新'),
          ),
        ],
      ),
    );
  }
}
