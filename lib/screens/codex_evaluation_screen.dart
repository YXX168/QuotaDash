import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/app_config.dart';
import '../models/codex_evaluation.dart';
import '../services/codex_evaluation_service.dart';
import '../services/private_http.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_widgets.dart';

class CodexEvaluationScreen extends StatefulWidget {
  const CodexEvaluationScreen({
    required this.config,
    this.repository,
    this.initialCredentialId,
    super.key,
  });
  final AppConfig config;
  final CodexEvaluationRepository? repository;
  final String? initialCredentialId;

  @override
  State<CodexEvaluationScreen> createState() => _CodexEvaluationScreenState();
}

class _CodexEvaluationScreenState extends State<CodexEvaluationScreen>
    with WidgetsBindingObserver {
  late final CodexEvaluationRepository _service;
  final _modelInput = TextEditingController();
  final _selected = <String>{};
  EvaluationState? _state;
  EvaluationKind _kind = EvaluationKind.candy;
  List<String> _models = [];
  String _filter = 'codex';
  String _effort = 'low';
  String _mode = 'quick';
  int _runs = 1;
  int _concurrency = 2;
  bool _loading = false;
  bool _pending = false;
  bool _foreground = true;
  String? _error;
  String? _catalogWarning;
  Timer? _poll;

  List<EvaluationCredential> get _visible =>
      _state?.credentials
          .where((a) => _filter == 'all' || a.provider == _filter)
          .toList() ??
      [];
  List<EvaluationCredential> get _targets => _visible
      .where(
        (a) => a.runnable && (_selected.isEmpty || _selected.contains(a.id)),
      )
      .toList();
  int get _requests => switch (_kind) {
    EvaluationKind.candy => _runs,
    EvaluationKind.fingerprint => switch (_mode) {
      'standard' => 200,
      'strict' => 400,
      _ => 60,
    },
    EvaluationKind.modelTrace => 3,
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _service =
        widget.repository ??
        CodexEvaluationService(
          baseUri: Uri.parse(widget.config.value('baseUrl')),
          managementKey: widget.config.value('managementKey'),
        );
    if (widget.initialCredentialId case final id?) _selected.add(id);
    _load(catalog: true);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _poll?.cancel();
    if (widget.repository == null) _service.dispose();
    _modelInput.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _poll?.cancel();
    if (_foreground) _load();
  }

  void _schedule() {
    _poll?.cancel();
    if (_foreground && !_pending && mounted) {
      _poll = Timer(Duration(seconds: _state?.busy == true ? 3 : 20), _load);
    }
  }

  Future<void> _load({bool catalog = false}) async {
    if (_loading || _pending || !mounted) return;
    _poll?.cancel();
    setState(() => _loading = true);
    try {
      final state = await _service.fetchState();
      if (!mounted) return;
      setState(() {
        _state = state;
        _error = null;
        // Keep explicit selection if an account disappears or is disabled:
        // polling must never turn one selected account into an all-account run.
      });
      if (catalog) {
        try {
          final models = await _service.fetchModels(state.credentials);
          if (!mounted) return;
          setState(() {
            _models = models;
            _catalogWarning = models.isEmpty ? '暂未读取到模型目录，可填写管理端中的模型名称' : null;
            if (_modelInput.text.isEmpty) {
              _modelInput.text = models.contains('gpt-6.1-sol')
                  ? 'gpt-6.1-sol'
                  : models.firstOrNull ?? '';
            }
          });
        } catch (e) {
          if (mounted) setState(() => _catalogWarning = safeErrorMessage(e));
        }
      }
    } catch (e) {
      if (mounted) setState(() => _error = safeErrorMessage(e));
    } finally {
      if (mounted) {
        setState(() => _loading = false);
        _schedule();
      }
    }
  }

  Future<void> _run(List<String> ids) async {
    if (_pending ||
        _loading ||
        ids.isEmpty ||
        _modelInput.text.trim().isEmpty) {
      return;
    }
    _poll?.cancel();
    setState(() => _pending = true);
    try {
      final message = await _service.run(
        kind: _kind,
        ids: ids,
        model: _modelInput.text.trim(),
        effort: _effort,
        runs: _runs,
        mode: _mode,
        concurrency: _concurrency,
      );
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(safeErrorMessage(e))));
      }
    } finally {
      if (mounted) {
        setState(() => _pending = false);
        await _load();
      }
    }
  }

  Future<void> _cancel(EvaluationCredential credential) async {
    if (_pending || _loading) return;
    _poll?.cancel();
    setState(() => _pending = true);
    try {
      await _service.cancel(_kind, [credential.id]);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(safeErrorMessage(e))));
      }
    } finally {
      if (mounted) {
        setState(() => _pending = false);
        await _load();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final visible = _visible;
    final targets = _targets;
    final probeModels = _models
        .where(
          (id) =>
              _kind == EvaluationKind.candy || !RegExp(r'[()]').hasMatch(id),
        )
        .toList();
    final model = _modelInput.text;
    final canRun =
        !_pending && !_loading && _error == null && model.trim().isNotEmpty;
    return Scaffold(
      body: AppBackdrop(
        child: SafeArea(
          child: RefreshIndicator(
            onRefresh: () => _load(catalog: true),
            child: ListView(
              key: const Key('evaluation-scroll'),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                Row(
                  children: [
                    IconButton(
                      tooltip: '返回',
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.arrow_back_rounded),
                    ),
                    const Expanded(
                      child: Text(
                        'Codex 降智测试',
                        style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    IconButton(
                      key: const Key('evaluation-refresh'),
                      tooltip: '刷新记录与模型',
                      onPressed: _loading || _pending
                          ? null
                          : () => _load(catalog: true),
                      icon: _loading
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.refresh_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                GlassCard(
                  padding: const EdgeInsets.all(16),
                  borderColor: AppTheme.violet.withValues(alpha: 0.4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(
                            Icons.psychology_alt_rounded,
                            color: AppTheme.violet,
                            size: 23,
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '推理表现与模型归因',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        '糖果题观察回答表现；指纹与 ModelTrace 比对模型特征。单次结果仅供参考，可结合历史复测。',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF9AA8BE),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          for (final kind in EvaluationKind.values)
                            ChoiceChip(
                              key: Key('evaluation-tab-${kind.name}'),
                              label: Text(kind.label),
                              selected: _kind == kind,
                              onSelected: _pending
                                  ? null
                                  : (_) => setState(() {
                                      _kind = kind;
                                      _concurrency =
                                          kind == EvaluationKind.modelTrace
                                          ? 3
                                          : 2;
                                      if (kind != EvaluationKind.candy &&
                                          RegExp(
                                            r'[()]',
                                          ).hasMatch(_modelInput.text)) {
                                        _modelInput.text =
                                            _models
                                                .where(
                                                  (m) => !RegExp(
                                                    r'[()]',
                                                  ).hasMatch(m),
                                                )
                                                .firstOrNull ??
                                            '';
                                      }
                                    }),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (_error case final error?)
                  _Notice(error, color: AppTheme.danger),
                if (_state?.storageWarning case final warning?)
                  _Notice(warning),
                if (_catalogWarning case final warning?) _Notice(warning),
                const SizedBox(height: 12),
                GlassCard(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (probeModels.isNotEmpty)
                        DropdownButtonFormField<String>(
                          key: ValueKey(
                            'model-${_kind.name}-$model-${probeModels.length}',
                          ),
                          initialValue: probeModels.contains(model)
                              ? model
                              : null,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: '测试模型',
                            isDense: true,
                          ),
                          items: [
                            for (final id in probeModels)
                              DropdownMenuItem(
                                value: id,
                                child: Text(
                                  id,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                          ],
                          onChanged: _pending
                              ? null
                              : (value) => setState(
                                  () => _modelInput.text = value ?? '',
                                ),
                        )
                      else
                        TextField(
                          key: const Key('evaluation-model-input'),
                          controller: _modelInput,
                          enabled: !_pending,
                          onChanged: (_) => setState(() {}),
                          autocorrect: false,
                          decoration: const InputDecoration(
                            labelText: '测试模型',
                            hintText: '填写管理端的模型名称',
                            isDense: true,
                          ),
                        ),
                      const SizedBox(height: 12),
                      if (_kind == EvaluationKind.candy) ...[
                        _select('推理强度', _effort, const {
                          'none': '由服务端决定',
                          'low': '低 · low',
                          'medium': '中 · medium',
                          'high': '高 · high',
                          'xhigh': '更高 · xhigh',
                          'max': '最高 · max',
                        }, (v) => _effort = v),
                        const SizedBox(height: 10),
                        _select('每账号测试次数', '$_runs', {
                          for (var i = 1; i <= 10; i++) '$i': '$i 次',
                        }, (v) => _runs = int.parse(v)),
                      ] else ...[
                        if (_kind == EvaluationKind.fingerprint) ...[
                          _select('采集模式', _mode, const {
                            'quick': '快速 · 60 次请求',
                            'standard': '标准 · 200 次请求',
                            'strict': '严格 · 400 次请求',
                          }, (v) => _mode = v),
                          const SizedBox(height: 10),
                        ],
                        _select(
                          '每账号并发数',
                          '$_concurrency',
                          {
                            for (
                              var i = 1;
                              i <= (_kind == EvaluationKind.modelTrace ? 3 : 6);
                              i++
                            )
                              '$i': '$i',
                          },
                          (v) => _concurrency = int.parse(v),
                        ),
                      ],
                      const SizedBox(height: 14),
                      Text(
                        '每账号 $_requests 次 · 本次 ${targets.length} 个账号 · 预计 ${targets.length * _requests} 次请求',
                        key: const Key('evaluation-cost'),
                        style: const TextStyle(
                          color: AppTheme.warning,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _kind == EvaluationKind.fingerprint
                            ? '采集会消耗账号额度；停止后，已发出的请求仍需返回。'
                            : '测试会消耗账号额度，单次请求输入约 1.4 万 Token${_kind == EvaluationKind.modelTrace ? '，失败可能重试' : ''}。',
                        style: Theme.of(
                          context,
                        ).textTheme.bodySmall?.copyWith(fontSize: 11),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          key: const Key('evaluation-run'),
                          onPressed: canRun && targets.isNotEmpty
                              ? () => _run(targets.map((a) => a.id).toList())
                              : null,
                          icon: _pending
                              ? const SizedBox.square(
                                  dimension: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.play_arrow_rounded, size: 20),
                          label: Text(
                            '${_selected.isEmpty ? '测试可用账号' : '测试已选账号'}（${targets.length}）',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        '账号与记录',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: visible.any((a) => a.runnable) && !_pending
                          ? () => setState(() {
                              final usable = visible
                                  .where((a) => a.runnable)
                                  .map((a) => a.id)
                                  .toSet();
                              if (usable.every(_selected.contains)) {
                                _selected.clear();
                              } else {
                                _selected.addAll(usable);
                              }
                            })
                          : null,
                      child: Text(_selected.isEmpty ? '全选' : '取消选择'),
                    ),
                  ],
                ),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    for (final filter in {
                      'codex',
                      'all',
                      ...?_state?.credentials.map((a) => a.provider),
                    })
                      ChoiceChip(
                        label: Text(
                          filter == 'all'
                              ? '全部'
                              : filter == 'codex'
                              ? 'Codex'
                              : evaluationText(filter),
                        ),
                        selected: _filter == filter,
                        onSelected: _pending
                            ? null
                            : (_) => setState(() {
                                _filter = filter;
                                _selected.clear();
                              }),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                if (_state == null && _loading)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(30),
                      child: CircularProgressIndicator(),
                    ),
                  )
                else if (visible.isEmpty)
                  GlassCard(
                    padding: const EdgeInsets.all(20),
                    child: Text(
                      _error == null
                          ? '暂无符合筛选条件的账号，请在管理端添加凭证或切换筛选。'
                          : '暂未读取到测试记录，请刷新重试。',
                    ),
                  ),
                for (final credential in visible)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _credentialCard(credential, canRun),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _select(
    String label,
    String value,
    Map<String, String> options,
    ValueChanged<String> change,
  ) => DropdownButtonFormField<String>(
    key: ValueKey('$label-$value'),
    initialValue: value,
    isExpanded: true,
    decoration: InputDecoration(labelText: label, isDense: true),
    items: [
      for (final entry in options.entries)
        DropdownMenuItem(value: entry.key, child: Text(entry.value)),
    ],
    onChanged: _pending
        ? null
        : (v) {
            if (v != null) setState(() => change(v));
          },
  );

  Widget _credentialCard(EvaluationCredential credential, bool canRun) {
    final records = credential.records[_kind]!;
    final last = records.lastOrNull;
    final progress = credential.progress[_kind];
    final accuracy = credential.accuracy(_modelInput.text, _effort);
    final total = progress?.totalFor(_kind) ?? 0;
    return GlassCard(
      key: ValueKey('evaluation-account-${credential.id}'),
      padding: const EdgeInsets.all(14),
      borderColor: credential.busy
          ? AppTheme.violet.withValues(alpha: 0.55)
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Checkbox(
                value: _selected.contains(credential.id),
                onChanged:
                    !_pending && !credential.disabled && !credential.unavailable
                    ? (v) => setState(() {
                        if (v == true) {
                          _selected.add(credential.id);
                        } else {
                          _selected.remove(credential.id);
                        }
                      })
                    : null,
              ),
              Expanded(
                child: Text(
                  credential.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _tag(credential.provider, AppTheme.cyan),
              if (credential.plan.isNotEmpty)
                _tag(credential.plan.toUpperCase(), AppTheme.violet),
              if (credential.disabled)
                _tag('已停用', AppTheme.warning)
              else if (credential.unavailable)
                _tag('暂不可用', AppTheme.warning),
              if (_kind == EvaluationKind.candy && accuracy != null)
                _tag('正确率 ${accuracy.round()}%', AppTheme.success),
            ],
          ),
          const SizedBox(height: 12),
          if (progress != null) ...[
            Text(
              '${progress.cancelling ? '正在停止' : '测试进行中'} · ${progress.done}/$total',
              style: const TextStyle(color: AppTheme.violet, fontSize: 13),
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: total > 0 ? (progress.done / total).clamp(0, 1) : null,
              color: AppTheme.violet,
              backgroundColor: AppTheme.outline,
              borderRadius: BorderRadius.circular(6),
            ),
            if (_kind != EvaluationKind.candy)
              TextButton.icon(
                onPressed: _pending || _loading || progress.cancelling
                    ? null
                    : () => _cancel(credential),
                icon: const Icon(Icons.stop_rounded, size: 18),
                label: const Text('停止后续请求'),
              ),
          ] else ...[
            if (credential.busy)
              const Text(
                '该账号正在执行另一项测试',
                style: TextStyle(color: AppTheme.warning, fontSize: 12),
              ),
            if (last != null) ...[
              Text(
                last.verdict,
                style: TextStyle(
                  color: _recordColor(last),
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${last.model}${last.effort.isNotEmpty ? ' · ${last.effort}' : ''} · ${_time(last.time)}',
                style: const TextStyle(color: Color(0xFF8F9BB1), fontSize: 11),
              ),
            ] else
              const Text(
                '尚未测试',
                style: TextStyle(color: Color(0xFF8F9BB1), fontSize: 13),
              ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: canRun && credential.runnable
                  ? () => _run([credential.id])
                  : null,
              icon: const Icon(Icons.play_arrow_rounded, size: 18),
              label: const Text('测试此账号'),
            ),
          ],
          if (records.isNotEmpty)
            Theme(
              data: Theme.of(
                context,
              ).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                tilePadding: EdgeInsets.zero,
                childrenPadding: EdgeInsets.zero,
                title: Text(
                  '历史记录 · ${records.length}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF9AA8BE),
                  ),
                ),
                children: [
                  for (final record in records.reversed)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      leading: Icon(
                        record.positive
                            ? Icons.check_circle_outline_rounded
                            : record.concerning
                            ? Icons.warning_amber_rounded
                            : Icons.info_outline_rounded,
                        color: _recordColor(record),
                        size: 19,
                      ),
                      title: Text(
                        record.verdict,
                        style: const TextStyle(fontSize: 13),
                      ),
                      subtitle: Text(
                        '${record.model} · ${_time(record.time)}',
                        style: const TextStyle(fontSize: 11),
                      ),
                      trailing: const Icon(
                        Icons.chevron_right_rounded,
                        size: 18,
                      ),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => _EvaluationRecordScreen(
                            credential: credential,
                            record: record,
                            service: _service,
                          ),
                        ),
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

Color _recordColor(EvaluationRecord record) => record.positive
    ? AppTheme.success
    : record.concerning
    ? AppTheme.warning
    : record.hasError || record.status == 'failed'
    ? AppTheme.danger
    : AppTheme.cyan;
String _time(DateTime? time) =>
    time == null ? '时间未知' : DateFormat('MM-dd HH:mm').format(time.toLocal());
String _percent(Object? raw) =>
    raw is num && raw.isFinite && raw >= 0 && raw <= 1
    ? '${(raw * 100).toStringAsFixed(1)}%'
    : '—';
Widget _tag(String label, Color color) => Container(
  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
  decoration: BoxDecoration(
    color: color.withValues(alpha: 0.1),
    borderRadius: BorderRadius.circular(8),
  ),
  child: Text(
    label,
    style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w700),
  ),
);

class _Notice extends StatelessWidget {
  const _Notice(this.text, {this.color = AppTheme.warning});
  final String text;
  final Color color;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 10),
    child: GlassCard(
      padding: const EdgeInsets.all(12),
      borderColor: color.withValues(alpha: 0.4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, color: color, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: TextStyle(fontSize: 12, color: color)),
          ),
        ],
      ),
    ),
  );
}

class _EvaluationRecordScreen extends StatefulWidget {
  const _EvaluationRecordScreen({
    required this.credential,
    required this.record,
    required this.service,
  });
  final EvaluationCredential credential;
  final EvaluationRecord record;
  final CodexEvaluationRepository service;
  @override
  State<_EvaluationRecordScreen> createState() =>
      _EvaluationRecordScreenState();
}

class _EvaluationRecordScreenState extends State<_EvaluationRecordScreen> {
  late EvaluationRecord _record = widget.record;
  bool _loading = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    if (_record.kind != EvaluationKind.candy) _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final record = await widget.service.fetchRecord(
        widget.credential.id,
        widget.record,
      );
      if (mounted) {
        setState(() {
          _record = record;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = safeErrorMessage(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = _record.data;
    final attr = _record.attribution;
    return Scaffold(
      body: AppBackdrop(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              Row(
                children: [
                  IconButton(
                    tooltip: '返回',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back_rounded),
                  ),
                  Expanded(
                    child: Text(
                      '${_record.kind.label}详情',
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              GlassCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.credential.name,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF9AA8BE),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _record.verdict,
                      style: TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.w800,
                        color: _recordColor(_record),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${_record.model} · ${_time(_record.time)}',
                      style: const TextStyle(fontSize: 12),
                    ),
                    if (_record.status == 'partial')
                      const Text(
                        '部分结果',
                        style: TextStyle(color: AppTheme.warning),
                      ),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _tag(
                          '耗时 ${data['duration_ms'] is num ? ((data['duration_ms'] as num) / 1000).toStringAsFixed(1) : '—'} 秒',
                          AppTheme.cyan,
                        ),
                        _tag(
                          '输入 ${evaluationInt(data['input_tokens']) ?? '—'} Token',
                          AppTheme.violet,
                        ),
                        _tag(
                          '输出 ${evaluationInt(data['output_tokens']) ?? '—'} Token',
                          AppTheme.violet,
                        ),
                        if (evaluationInt(data['reasoning_tokens'])
                            case final tokens? when tokens > 0)
                          _tag('推理 $tokens Token', AppTheme.violet),
                      ],
                    ),
                  ],
                ),
              ),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.all(20),
                  child: Center(child: CircularProgressIndicator()),
                ),
              if (_error case final error?) ...[
                _Notice(error, color: AppTheme.danger),
                TextButton(
                  onPressed: _loading ? null : _load,
                  child: const Text('重新读取详情'),
                ),
              ],
              if (_record.error case final error?)
                _Notice(error, color: AppTheme.danger),
              if (_record.kind == EvaluationKind.candy) ...[
                const SizedBox(height: 16),
                const SectionTitle(
                  title: '模型回答',
                  subtitle: '题目标准答案为 21；正确率按模型与推理强度分别统计',
                ),
                const SizedBox(height: 10),
                GlassCard(
                  padding: const EdgeInsets.all(16),
                  child: SelectableText(
                    _record.answer.isEmpty ? '本次没有可显示的回答' : _record.answer,
                    style: const TextStyle(fontSize: 13, height: 1.6),
                  ),
                ),
              ] else if (_record.kind == EvaluationKind.fingerprint) ...[
                const SizedBox(height: 16),
                GlassCard(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '采集与稳定性',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        '完成 ${evaluationInt(data['done']) ?? '—'} / ${evaluationInt(data['total']) ?? '—'} · 有效 ${evaluationInt(data['valid']) ?? '—'} · 失败 ${evaluationInt(data['errors']) ?? '—'}',
                      ),
                      if (attr['nearest'] != null)
                        Text('最近模型：${evaluationText(attr['nearest'])}'),
                      Text('自一致性 JSD：${_decimal(attr['self_jsd'])}'),
                      const Text(
                        'JSD 越小，回答分布越接近；样本不足或不稳定时可复测。',
                        style: TextStyle(
                          fontSize: 11,
                          color: Color(0xFF9AA8BE),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const SectionTitle(title: '基准比对'),
                const SizedBox(height: 10),
                for (final raw in attr['comparisons'] as List? ?? const [])
                  _comparison(evaluationMap(raw)),
                if ((attr['comparisons'] as List? ?? const []).isEmpty)
                  const GlassCard(child: Text('暂无可比数据')),
              ] else ...[
                const SizedBox(height: 16),
                GlassCard(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '模型归因',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '最近模型：${evaluationText(attr['prediction']).isEmpty ? '—' : evaluationText(attr['prediction'])} · ${_percent(attr['probability'])}',
                      ),
                      Text(
                        '模型家族：${evaluationText(attr['family_prediction_name'])} · ${_percent(attr['family_probability'])}',
                      ),
                      Text(
                        '有效回答：${evaluationInt(attr['used_outputs']) ?? '—'} / 3',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const SectionTitle(
                  title: '候选模型排行',
                  subtitle: '概率来自插件归因模型，作为比对参考',
                ),
                const SizedBox(height: 10),
                for (final raw in attr['results'] as List? ?? const [])
                  _candidate(evaluationMap(raw)),
                if ((attr['results'] as List? ?? const []).isEmpty)
                  const GlassCard(child: Text('暂无候选模型')),
                for (final raw in data['samples'] as List? ?? const [])
                  _sample(evaluationMap(raw)),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _decimal(Object? value) =>
      value is num && value.isFinite ? value.toStringAsFixed(4) : '—';
  Widget _comparison(Map<String, dynamic> c) => GlassCard(
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.all(14),
    child: ExpansionTile(
      tilePadding: EdgeInsets.zero,
      title: Text(
        evaluationText(c['model']),
        style: const TextStyle(fontSize: 13),
      ),
      subtitle: Text(
        'JSD ${_decimal(c['mean_jsd'])} · p ${_decimal(c['p_value'])}',
        style: const TextStyle(fontSize: 11),
      ),
      children: [
        for (final raw in c['cells'] as List? ?? const [])
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              '${evaluationText(evaluationMap(raw)['cell'])} · JSD ${_decimal(evaluationMap(raw)['jsd'])}',
              style: const TextStyle(fontSize: 12),
            ),
          ),
      ],
    ),
  );
  Widget _candidate(Map<String, dynamic> c) => GlassCard(
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.all(14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          evaluationText(c['display_name'] ?? c['model']),
          style: const TextStyle(fontSize: 13),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: LinearProgressIndicator(
                value:
                    c['probability'] is num &&
                        (c['probability'] as num).isFinite
                    ? (c['probability'] as num).toDouble().clamp(0, 1)
                    : 0,
                color: AppTheme.violet,
                backgroundColor: AppTheme.outline,
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              _percent(c['probability']),
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
      ],
    ),
  );
  Widget _sample(Map<String, dynamic> sample) => GlassCard(
    margin: const EdgeInsets.only(top: 8),
    padding: const EdgeInsets.all(14),
    child: ExpansionTile(
      tilePadding: EdgeInsets.zero,
      title: Text(
        sample['accepted'] == true ? '有效挑战回答' : '未计入的挑战',
        style: const TextStyle(fontSize: 13),
      ),
      children: [
        SelectableText(
          evaluationText(sample['prompt']),
          style: const TextStyle(fontSize: 12),
        ),
        const SizedBox(height: 8),
        SelectableText(
          evaluationText(sample['text']),
          style: const TextStyle(fontSize: 12),
        ),
        if ((sample['error']?.toString() ?? '').isNotEmpty)
          const Text('本次挑战请求失败', style: TextStyle(color: AppTheme.danger)),
      ],
    ),
  );
}
