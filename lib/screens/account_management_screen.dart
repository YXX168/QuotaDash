import 'package:flutter/material.dart';

import '../models/app_config.dart';
import '../models/managed_account.dart';
import '../services/account_management_service.dart';
import '../services/private_http.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_widgets.dart';

class AccountManagementScreen extends StatefulWidget {
  const AccountManagementScreen({
    required this.config,
    this.repository,
    super.key,
  });
  final AppConfig config;
  final AccountManagementRepository? repository;

  @override
  State<AccountManagementScreen> createState() =>
      _AccountManagementScreenState();
}

class _AccountManagementScreenState extends State<AccountManagementScreen> {
  late final AccountManagementRepository _repository;
  List<ManagedAccount> _accounts = [];
  String? _error;
  String? _pending;
  String _filter = 'all';
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _repository =
        widget.repository ??
        AccountManagementService(
          baseUri: Uri.parse(widget.config.value('baseUrl')),
          managementKey: widget.config.value('managementKey'),
        );
    _load();
  }

  @override
  void dispose() {
    if (widget.repository == null) _repository.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (_loading || _pending != null) return;
    setState(() => _loading = true);
    try {
      final accounts = await _repository.fetchAccounts();
      if (mounted) {
        setState(() {
          _accounts = accounts;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = safeErrorMessage(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggle(ManagedAccount account, bool enabled) async {
    if (_loading || _pending != null || !account.canToggle) return;
    setState(() => _pending = account.identity);
    try {
      final accounts = await _repository.setDisabled(account, !enabled);
      if (!mounted) return;
      setState(() {
        _accounts = accounts;
        _error = null;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(enabled ? '账号已启用' : '账号已禁用')));
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = safeErrorMessage(e));
      // A timeout may follow a persisted write; reload instead of guessing.
      try {
        final accounts = await _repository.fetchAccounts();
        if (mounted) setState(() => _accounts = accounts);
      } catch (_) {}
    } finally {
      if (mounted) setState(() => _pending = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final visible = _accounts
        .where(
          (a) => switch (_filter) {
            'enabled' => a.disabled == false,
            'disabled' => a.disabled == true,
            _ => true,
          },
        )
        .toList();
    return Scaffold(
      body: AppBackdrop(
        child: SafeArea(
          child: CustomScrollView(
            slivers: [
              SliverAppBar(
                title: const Text('账号管理'),
                pinned: true,
                backgroundColor: Colors.transparent,
                surfaceTintColor: Colors.transparent,
                actions: [
                  IconButton(
                    key: const Key('accounts-refresh'),
                    tooltip: '刷新账号',
                    onPressed: _loading || _pending != null ? null : _load,
                    icon: const Icon(Icons.refresh_rounded),
                  ),
                ],
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                sliver: SliverList.list(
                  children: [
                    const Text(
                      '启用的账号参与请求分配；禁用后仍可在这里重新启用。',
                      style: TextStyle(color: Color(0xFF8F9BB1), fontSize: 12),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        for (final filter in const {
                          'all': '全部',
                          'enabled': '已启用',
                          'disabled': '已禁用',
                        }.entries)
                          ChoiceChip(
                            key: Key('accounts-filter-${filter.key}'),
                            label: Text(filter.value),
                            selected: _filter == filter.key,
                            onSelected: (_) =>
                                setState(() => _filter = filter.key),
                          ),
                      ],
                    ),
                    if (_loading) ...[
                      const SizedBox(height: 12),
                      const LinearProgressIndicator(),
                    ],
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        _error!,
                        style: const TextStyle(color: AppTheme.warning),
                      ),
                    ],
                    const SizedBox(height: 12),
                    if (!_loading && visible.isEmpty) const Text('暂无符合条件的账号'),
                    for (final account in visible)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: GlassCard(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      account.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${account.providerLabel} · ${account.statusLabel}',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: Color(0xFF8F9BB1),
                                      ),
                                    ),
                                    if (!account.canToggle) ...[
                                      const SizedBox(height: 3),
                                      Text(
                                        account.restriction,
                                        style: const TextStyle(
                                          fontSize: 10,
                                          color: Color(0xFF8F9BB1),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              if (_pending == account.identity)
                                const SizedBox.square(
                                  dimension: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              else
                                Switch.adaptive(
                                  key: ValueKey(
                                    'account-enabled-${account.identity}',
                                  ),
                                  value: account.disabled == false,
                                  onChanged:
                                      !account.canToggle ||
                                          _loading ||
                                          _pending != null
                                      ? null
                                      : (enabled) => _toggle(account, enabled),
                                ),
                            ],
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
