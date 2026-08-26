import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/proxy_api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_widgets.dart';

/// API Key 只读管理页面。
///
/// 通过 [ProxyApiService.fetchApiKeys] 拉取客户端密钥列表，默认脱敏显示，
/// 支持切换明文、长按复制与下拉刷新。
class ApiKeysScreen extends StatefulWidget {
  const ApiKeysScreen({required this.service, super.key});

  final ProxyApiService service;

  @override
  State<ApiKeysScreen> createState() => _ApiKeysScreenState();
}

class _ApiKeysScreenState extends State<ApiKeysScreen> {
  List<String> _keys = const [];
  Object? _error;
  bool _loading = true;
  bool _refreshing = false;
  bool _adding = false;
  bool _deleting = false;
  bool _reveal = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh({bool silent = false}) async {
    if (_refreshing) return;
    setState(() {
      _refreshing = true;
      if (_keys.isEmpty && !silent) _loading = true;
      _error = null;
    });
    try {
      final keys = await widget.service.fetchApiKeys();
      if (!mounted) return;
      setState(() {
        _keys = keys;
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

  Future<void> _refreshWithFeedback() async {
    await HapticFeedback.mediumImpact();
    await _refresh();
  }

  Future<void> _addKey() async {
    if (_adding || _refreshing) return;
    final controller = TextEditingController();
    final newKey = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('添加 API Key'),
        content: TextField(
          controller: controller,
          autofocus: true,
          autocorrect: true,
          enableSuggestions: true,
          decoration: const InputDecoration(labelText: 'API Key'),
          onSubmitted: (value) => Navigator.of(dialogContext).pop(value.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(controller.text.trim()),
            child: const Text('添加'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (newKey == null || newKey.isEmpty || !mounted) return;
    if (_keys.contains(newKey)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('该 API Key 已存在')));
      return;
    }

    setState(() => _adding = true);
    try {
      await widget.service.addApiKey(newKey);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('已添加 API Key')));
      await _refresh();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('添加失败：$error')));
    } finally {
      if (mounted) setState(() => _adding = false);
    }
  }

  Future<void> _deleteKey(int index) async {
    if (_deleting || _refreshing) return;
    final key = _keys[index];
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('删除 API Key'),
        content: Text('确定删除 ${_maskKey(key)} 吗？此操作会同步到服务端配置。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _deleting = true);
    try {
      await widget.service.deleteApiKey(index: index);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('已删除 API Key')));
      await _refresh();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('删除失败：$error')));
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  Future<void> _copyKey(String key) async {
    await HapticFeedback.mediumImpact();
    await Clipboard.setData(ClipboardData(text: key));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('已复制到剪贴板')));
  }

  void _toggleReveal() {
    unawaited(HapticFeedback.selectionClick());
    setState(() => _reveal = !_reveal);
  }

  String _maskKey(String key) {
    if (key.length <= 8) return '****';
    return '${key.substring(0, 4)}****${key.substring(key.length - 4)}';
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
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
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
                      icon: Icons.vpn_key_rounded,
                      size: 40,
                      iconSize: 20,
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'API Key 管理',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const Text(
                            'CLIENT CREDENTIALS',
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
                    IconButton(
                      tooltip: _reveal ? '隐藏' : '显示',
                      onPressed: _toggleReveal,
                      icon: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 180),
                        child: Icon(
                          _reveal
                              ? Icons.visibility_off_rounded
                              : Icons.visibility_rounded,
                          key: ValueKey(_reveal),
                          size: 22,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: '添加 API Key',
                      onPressed: _adding ? null : _addKey,
                      icon: const Icon(Icons.add_rounded, size: 22),
                    ),
                  ],
                ),
              ),
              _InfoBar(count: _keys.length, loading: _loading),
              const SizedBox(height: 6),
              Expanded(child: _buildBody()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2.4));
    }
    return RefreshIndicator(
      onRefresh: _refreshWithFeedback,
      color: AppTheme.cyan,
      backgroundColor: const Color(0xFF11192A),
      child: _error != null
          ? _KeyErrorView(error: _error!, onRetry: _refresh)
          : _keys.isEmpty
          ? const _KeyEmptyView()
          : ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(14, 4, 14, 28),
              itemCount: _keys.length,
              itemBuilder: (context, index) {
                final key = _keys[index];
                return _ApiKeyCard(
                  index: index,
                  rawKey: key,
                  revealed: _reveal,
                  maskKey: _maskKey,
                  deleting: _deleting,
                  onLongPress: () => _copyKey(key),
                  onCopy: () => _copyKey(key),
                  onDelete: () => _deleteKey(index),
                );
              },
            ),
    );
  }
}

class _InfoBar extends StatelessWidget {
  const _InfoBar({required this.count, required this.loading});

  final int count;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0x8A111827),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.outline.withValues(alpha: 0.6)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppTheme.violet.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(11),
              border: Border.all(
                color: AppTheme.violet.withValues(alpha: 0.18),
              ),
            ),
            child: const Icon(
              Icons.key_rounded,
              size: 18,
              color: AppTheme.violet,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  loading ? '密钥数量：--' : '密钥数量：$count',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                const Row(
                  children: [
                    Icon(
                      Icons.lock_outline_rounded,
                      size: 12,
                      color: AppTheme.warning,
                    ),
                    SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        '仅查看模式，修改请通过服务端配置',
                        style: TextStyle(
                          color: Color(0xFF8F9BB1),
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ApiKeyCard extends StatelessWidget {
  const _ApiKeyCard({
    required this.index,
    required this.rawKey,
    required this.revealed,
    required this.maskKey,
    required this.deleting,
    required this.onLongPress,
    required this.onCopy,
    required this.onDelete,
  });

  final int index;
  final String rawKey;
  final bool revealed;
  final String Function(String) maskKey;
  final bool deleting;
  final VoidCallback onLongPress;
  final VoidCallback onCopy;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final display = revealed ? rawKey : maskKey(rawKey);
    return GlassCard(
      margin: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        onLongPress: onLongPress,
        behavior: HitTestBehavior.opaque,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppTheme.cyan, AppTheme.violet],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(13),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x4438E8FF),
                    blurRadius: 10,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(
                Icons.token_rounded,
                color: AppTheme.background,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'API Key #${index + 1}',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: (revealed ? AppTheme.success : AppTheme.cyan)
                              .withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: (revealed ? AppTheme.success : AppTheme.cyan)
                                .withValues(alpha: 0.32),
                          ),
                        ),
                        child: Text(
                          revealed ? '明文' : '已脱敏',
                          style: TextStyle(
                            color: revealed ? AppTheme.success : AppTheme.cyan,
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SelectableText(
                    display,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 14,
                      height: 1.4,
                      color: const Color(0xFFDCE5F7),
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(
                        Icons.touch_app_rounded,
                        size: 12,
                        color: Color(0xFF8F9BB1),
                      ),
                      const SizedBox(width: 5),
                      const Text(
                        '长按复制',
                        style: TextStyle(
                          color: Color(0xFF8F9BB1),
                          fontSize: 11,
                        ),
                      ),
                      const Spacer(),
                      InkWell(
                        onTap: onCopy,
                        borderRadius: BorderRadius.circular(8),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.copy_rounded,
                                size: 14,
                                color: AppTheme.cyan,
                              ),
                              SizedBox(width: 4),
                              Text(
                                '复制',
                                style: TextStyle(
                                  color: AppTheme.cyan,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      InkWell(
                        onTap: deleting ? null : onDelete,
                        borderRadius: BorderRadius.circular(8),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.delete_outline_rounded,
                                size: 15,
                                color: AppTheme.danger,
                              ),
                              SizedBox(width: 4),
                              Text(
                                '删除',
                                style: TextStyle(
                                  color: AppTheme.danger,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
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

class _KeyErrorView extends StatelessWidget {
  const _KeyErrorView({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(28, 60, 28, 28),
      children: [
        GlassCard(
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
              Text('加载失败', style: Theme.of(context).textTheme.titleLarge),
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
        ),
      ],
    );
  }
}

class _KeyEmptyView extends StatelessWidget {
  const _KeyEmptyView();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(28, 80, 28, 28),
      children: [
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.vpn_key_off_outlined,
                size: 46,
                color: Color(0xFF77849E),
              ),
              const SizedBox(height: 12),
              Text('暂无 API Key', style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 6),
              const Text(
                '下拉刷新以重新获取',
                style: TextStyle(color: Color(0xFF8F9BB1), fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
