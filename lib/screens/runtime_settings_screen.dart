import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/proxy_api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_widgets.dart';
import '../widgets/quantum_emblem.dart';

class RuntimeToggleGroup {
  const RuntimeToggleGroup({
    required this.title,
    required this.subtitle,
    required this.definitions,
  });

  final String title;
  final String subtitle;
  final List<RuntimeToggleDefinition> definitions;
}

/// Runtime switch groups exposed by the CLIProxyAPI v8 configuration tree.
const runtimeToggleGroups = <RuntimeToggleGroup>[
  RuntimeToggleGroup(
    title: '网络与安全',
    subtitle: '局域网广播与访问权限控制',
    definitions: [
      RuntimeToggleDefinition(
        path: 'server/discovery/enabled',
        label: '局域网服务发现',
        description: '通过 mDNS 广播当前 CLIProxyAPI 服务',
        icon: Icons.wifi_tethering_rounded,
        color: AppTheme.cyan,
      ),
      RuntimeToggleDefinition(
        path: 'management/allow-remote',
        label: '允许远程管理',
        description: '允许非本机访问管理接口，请确认密钥安全',
        icon: Icons.public_rounded,
        color: AppTheme.warning,
      ),
    ],
  ),
  RuntimeToggleGroup(
    title: '路由与调度',
    subtitle: '账号黏性、前缀过滤与调度策略',
    definitions: [
      RuntimeToggleDefinition(
        path: 'routing/session-affinity',
        label: '会话粘滞路由',
        description: '同一会话尽量复用同一个上游账号',
        icon: Icons.link_rounded,
        color: AppTheme.violet,
      ),
      RuntimeToggleDefinition(
        path: 'routing/force-model-prefix',
        label: '强制模型前缀',
        description: '无前缀模型请求只使用无前缀凭据',
        icon: Icons.route_rounded,
        color: AppTheme.magenta,
      ),
      RuntimeToggleDefinition(
        path: 'routing/cooldown/disable-cooling',
        label: '关闭账号冷却',
        description: '关闭失败后的凭据冷却调度',
        icon: Icons.ac_unit_rounded,
        color: AppTheme.cyan,
      ),
      RuntimeToggleDefinition(
        path: 'requests/passthrough-headers',
        label: '透传上游响应头',
        description: '将筛选后的上游响应头转发给客户端',
        icon: Icons.swap_horiz_rounded,
        color: AppTheme.success,
      ),
    ],
  ),
  RuntimeToggleGroup(
    title: '日志与监控',
    subtitle: '调试输出、文件日志与用量统计',
    definitions: [
      RuntimeToggleDefinition(
        path: 'observability/logs/debug',
        label: '调试日志',
        description: '输出更详细的服务运行日志',
        icon: Icons.bug_report_outlined,
        color: AppTheme.warning,
      ),
      RuntimeToggleDefinition(
        path: 'observability/logs/logging-to-file',
        label: '写入日志文件',
        description: '将应用日志写入滚动文件',
        icon: Icons.description_outlined,
        color: AppTheme.violet,
      ),
      RuntimeToggleDefinition(
        path: 'observability/logs/request-log',
        label: '记录请求日志',
        description: '记录代理请求与响应（管理请求除外）',
        icon: Icons.receipt_long_outlined,
        color: AppTheme.magenta,
      ),
      RuntimeToggleDefinition(
        path: 'observability/usage/usage-statistics-enabled',
        label: '启用用量统计',
        description: '保留内存中的请求用量聚合数据',
        icon: Icons.insights_rounded,
        color: AppTheme.success,
      ),
    ],
  ),
  RuntimeToggleGroup(
    title: '扩展系统',
    subtitle: 'CLIProxyAPI 插件与扩展加载',
    definitions: [
      RuntimeToggleDefinition(
        path: 'plugins/enabled',
        label: '启用插件系统',
        description: '允许 CLIProxyAPI 加载已配置的插件',
        icon: Icons.extension_rounded,
        color: AppTheme.cyan,
      ),
    ],
  ),
];

final runtimeToggleDefinitions = <RuntimeToggleDefinition>[
  for (final group in runtimeToggleGroups) ...group.definitions,
];

class RuntimeToggleDefinition {
  const RuntimeToggleDefinition({
    required this.path,
    required this.label,
    required this.description,
    required this.icon,
    required this.color,
  });

  final String path;
  final String label;
  final String description;
  final IconData icon;
  final Color color;
}

class RuntimeSettingsScreen extends StatefulWidget {
  const RuntimeSettingsScreen({required this.service, super.key});

  final ProxyApiService service;

  @override
  State<RuntimeSettingsScreen> createState() => _RuntimeSettingsScreenState();
}

class _RuntimeSettingsScreenState extends State<RuntimeSettingsScreen> {
  final _yamlController = TextEditingController();
  Map<String, bool> _values = {};
  bool _loading = true;
  String? _error;
  String? _savingPath;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _yamlController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final config = await widget.service.fetchRuntimeConfig();
      final values = <String, bool>{};
      for (final definition in runtimeToggleDefinitions) {
        final raw = _valueAt(config, definition.path);
        if (raw is bool) values[definition.path] = raw;
      }
      if (!mounted) return;
      setState(() {
        _values = values;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.toString();
      });
    }
  }

  Future<void> _toggle(RuntimeToggleDefinition definition, bool value) async {
    final previous = _values[definition.path] ?? false;
    setState(() {
      _values[definition.path] = value;
      _savingPath = definition.path;
    });
    try {
      await widget.service.writeConfigPath(definition.path, value);
      if (mounted) await HapticFeedback.selectionClick();
    } catch (error) {
      if (!mounted) return;
      setState(() => _values[definition.path] = previous);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('保存失败：$error')));
    } finally {
      if (mounted) setState(() => _savingPath = null);
    }
  }

  Future<void> _openYamlEditor() async {
    try {
      _yamlController.text = await widget.service.fetchConfigYaml();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('读取配置文件失败：$error')));
      return;
    }
    if (!mounted) return;
    final saved = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.72),
      builder: (dialogContext) => _YamlEditorDialog(
        controller: _yamlController,
        onSave: () async {
          await widget.service.replaceConfigYaml(_yamlController.text);
        },
      ),
    );
    if (saved == true) {
      await _load();
    }
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
                                '运行开关',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const Text(
                                '热更新服务运行参数',
                                style: TextStyle(
                                  color: Color(0xFF748198),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: '刷新',
                          onPressed: _loading || _savingPath != null
                              ? null
                              : _load,
                          icon: const Icon(Icons.refresh_rounded),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (_error != null)
                      GlassCard(
                        borderColor: AppTheme.warning.withValues(alpha: 0.3),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.info_outline_rounded,
                              color: AppTheme.warning,
                            ),
                            const SizedBox(width: 12),
                            Expanded(child: Text(_error!)),
                          ],
                        ),
                      )
                    else if (_loading)
                      const GlassCard(
                        child: SizedBox(
                          height: 160,
                          child: Center(child: CircularProgressIndicator()),
                        ),
                      )
                    else ...[
                      for (final group in runtimeToggleGroups) ...[
                        SectionTitle(
                          title: group.title,
                          subtitle: group.subtitle,
                        ),
                        const SizedBox(height: 12),
                        for (final definition in group.definitions) ...[
                          _ToggleCard(
                            definition: definition,
                            value: _values[definition.path] ?? false,
                            saving: _savingPath == definition.path,
                            onChanged: _savingPath == null
                                ? (value) => _toggle(definition, value)
                                : null,
                          ),
                          const SizedBox(height: 10),
                        ],
                        const SizedBox(height: 12),
                      ],
                      const SectionTitle(
                        title: '高级配置',
                        subtitle: '直接编辑并热加载服务完整 YAML 配置',
                      ),
                      const SizedBox(height: 12),
                      _YamlCard(
                        onTap: _savingPath == null ? _openYamlEditor : null,
                      ),
                    ],
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

Object? _valueAt(Map<String, dynamic> config, String path) {
  Object? current = config;
  for (final segment in path.split('/')) {
    if (current is! Map) return null;
    current = current[segment];
  }
  return current;
}

class _ToggleCard extends StatelessWidget {
  const _ToggleCard({
    required this.definition,
    required this.value,
    required this.saving,
    required this.onChanged,
  });

  final RuntimeToggleDefinition definition;
  final bool value;
  final bool saving;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
      borderColor: definition.color.withValues(alpha: value ? 0.3 : 0.12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: definition.color.withValues(alpha: value ? 0.15 : 0.07),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(definition.icon, color: definition.color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  definition.label,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 3),
                Text(
                  definition.description,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          if (saving)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            Switch.adaptive(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _YamlCard extends StatelessWidget {
  const _YamlCard({required this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      borderColor: AppTheme.violet.withValues(alpha: 0.22),
      child: Row(
        children: [
          const GradientIcon(
            icon: Icons.data_object_rounded,
            size: 40,
            iconSize: 20,
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('配置文件', style: TextStyle(fontWeight: FontWeight.w700)),
                SizedBox(height: 3),
                Text('查看或编辑 CLIProxyAPI v8 YAML 配置'),
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
    );
  }
}

class _YamlEditorDialog extends StatefulWidget {
  const _YamlEditorDialog({required this.controller, required this.onSave});

  final TextEditingController controller;
  final Future<void> Function() onSave;

  @override
  State<_YamlEditorDialog> createState() => _YamlEditorDialogState();
}

class _YamlEditorDialogState extends State<_YamlEditorDialog> {
  bool _saving = false;
  String? _error;

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.onSave();
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF121C2D),
      title: const Text('配置文件'),
      content: SizedBox(
        width: 720,
        height: MediaQuery.sizeOf(context).height * 0.62,
        child: Column(
          children: [
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  _error!,
                  style: const TextStyle(color: AppTheme.warning),
                ),
              ),
            Expanded(
              child: TextField(
                controller: widget.controller,
                expands: true,
                maxLines: null,
                minLines: null,
                textAlignVertical: TextAlignVertical.top,
                autocorrect: false,
                enableSuggestions: false,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                  color: Color(0xFFD4E2F8),
                ),
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'YAML',
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox.square(
                  dimension: 17,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('保存并热加载'),
        ),
      ],
    );
  }
}
