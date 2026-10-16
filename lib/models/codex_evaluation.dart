import 'codex_account.dart';

enum EvaluationKind {
  candy('糖果题', '', 'results', 'running'),
  fingerprint('指纹测试', 'fingerprint/', 'fingerprints', 'fingerprint_running'),
  modelTrace('ModelTrace', 'modeltrace/', 'modeltraces', 'modeltrace_running');

  const EvaluationKind(
    this.label,
    this.route,
    this.recordsKey,
    this.progressKey,
  );
  final String label;
  final String route;
  final String recordsKey;
  final String progressKey;
}

/// Only application-authored errors and redacted result text reach the UI.
String evaluationText(Object? value) => (value?.toString() ?? '')
    .replaceAll(
      RegExp(r'''https?://[^\s<>"']+''', caseSensitive: false),
      '[地址已隐藏]',
    )
    .replaceAll(
      RegExp(r'\b(?:[0-9]{1,3}\.){3}[0-9]{1,3}(?::[0-9]+)?\b'),
      '[地址已隐藏]',
    )
    .replaceAll(
      RegExp(r'''Bearer\s+[^\s"',}]+''', caseSensitive: false),
      'Bearer [已隐藏]',
    )
    .replaceAll(RegExp(r'\bsk-[A-Za-z0-9_-]+'), '[密钥已隐藏]')
    .replaceAll(
      RegExp(r'\beyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+'),
      '[令牌已隐藏]',
    );

Map<String, dynamic> evaluationMap(Object? value) =>
    value is Map ? Map<String, dynamic>.from(value) : const {};

int? evaluationInt(Object? value) => value is num
    ? value.isFinite
          ? value.toInt()
          : null
    : int.tryParse(value?.toString() ?? '');

class EvaluationProgress {
  EvaluationProgress(Map<String, dynamic> json)
    : done = evaluationInt(json['done']) ?? 0,
      total = evaluationInt(json['total']),
      phase = json['phase']?.toString() ?? '',
      model = evaluationText(json['model']);

  final int done;
  final int? total;
  final String phase;
  final String model;

  bool get cancelling => phase == 'cancelling';
  int totalFor(EvaluationKind kind) =>
      total ?? (kind == EvaluationKind.modelTrace ? 3 : 0);
}

class EvaluationRecord {
  EvaluationRecord(this.kind, this.data);

  final EvaluationKind kind;
  final Map<String, dynamic> data;
  String get id => data['id']?.toString() ?? '';
  String get model => evaluationText(data['model']);
  String get effort => evaluationText(data['effort']);
  String get mode => evaluationText(data['mode']);
  DateTime? get time => DateTime.tryParse(data['time']?.toString() ?? '');
  String get answer => evaluationText(data['answer']);
  bool get hasError => (data['error']?.toString() ?? '').isNotEmpty;
  String? get error => hasError ? '测试请求未完成，请检查账号状态或稍后重试' : null;
  bool get skipped => data['skipped'] == true || data['status'] == 'skipped';
  bool get correct => data['ok'] == true;
  String get status => data['status']?.toString() ?? '';
  Map<String, dynamic> get attribution => evaluationMap(data['attribution']);
  bool get isGraded =>
      kind == EvaluationKind.candy &&
      data['ok'] is bool &&
      !hasError &&
      !skipped;

  String get verdict {
    if (skipped) return '已跳过';
    if (kind == EvaluationKind.candy) {
      if (!hasError && data['ok'] is! bool) return '暂无判断结果';
      return hasError
          ? '请求失败'
          : correct
          ? '答对'
          : '答错';
    }
    if (status == 'failed') return '测试失败';
    if (status == 'cancelled') return '已停止';
    if (kind == EvaluationKind.fingerprint) {
      return switch (attribution['status']) {
        'consistent' => '与所选模型一致',
        'substitution' => '疑似模型替换',
        'different' => '与所选模型有差异',
        'ambiguous' => '暂无法判断',
        'insufficient' => '有效回答不足',
        'no_baseline' => '暂无模型基准',
        'unstable' => '结果不稳定',
        _ => '暂无判断结果',
      };
    }
    return attribution['prediction'] != null
        ? evaluationText(attribution['prediction'])
        : '暂无归因结果';
  }

  bool get positive => kind == EvaluationKind.candy
      ? isGraded && correct
      : kind == EvaluationKind.fingerprint
      ? status == 'completed' && attribution['status'] == 'consistent'
      : ['completed', 'partial'].contains(status) &&
            attribution['prediction'] != null &&
            model.toLowerCase().split('/').last ==
                attribution['prediction']
                    .toString()
                    .toLowerCase()
                    .split('/')
                    .last;

  bool get concerning => kind == EvaluationKind.candy
      ? isGraded && !correct
      : kind == EvaluationKind.fingerprint
      ? [
          'substitution',
          'different',
          'unstable',
        ].contains(attribution['status'])
      : ['completed', 'partial'].contains(status) &&
            attribution['prediction'] != null &&
            !positive;
}

class EvaluationCredential {
  EvaluationCredential(Map<String, dynamic> json)
    : id = json['id'].toString(),
      provider = (json['provider']?.toString() ?? '').trim().toLowerCase(),
      source = json['source']?.toString() ?? '',
      name = AuthFileAccount.maskName(
        (json['email']?.toString() ?? '').isNotEmpty
            ? json['email'].toString()
            : evaluationText(json['name']),
      ),
      plan = evaluationText(json['plan_type']),
      disabled = json['disabled'] == true,
      unavailable = json['unavailable'] == true,
      records = {
        for (final kind in EvaluationKind.values)
          kind: (json[kind.recordsKey] as List? ?? const [])
              .whereType<Map>()
              .map((r) => EvaluationRecord(kind, Map<String, dynamic>.from(r)))
              .toList(growable: false),
      },
      progress = {
        for (final kind in EvaluationKind.values)
          if (json[kind.progressKey] is Map)
            kind: EvaluationProgress(evaluationMap(json[kind.progressKey])),
      };

  final String id;
  final String name;
  final String provider;
  final String source;
  final String plan;
  final bool disabled;
  final bool unavailable;
  final Map<EvaluationKind, List<EvaluationRecord>> records;
  final Map<EvaluationKind, EvaluationProgress> progress;
  bool get busy => progress.isNotEmpty;
  bool get runnable => !disabled && !unavailable && !busy;

  double? accuracy(String model, String effort) {
    final graded = records[EvaluationKind.candy]!
        .where(
          (r) =>
              r.isGraded &&
              r.model == model &&
              (r.effort.isEmpty ? 'none' : r.effort) == effort,
        )
        .toList();
    if (graded.isEmpty) return null;
    return graded.where((r) => r.correct).length / graded.length * 100;
  }
}

class EvaluationState {
  EvaluationState.fromJson(Map<String, dynamic> json)
    : credentials = _credentials(json['auths']),
      storageWarning = (json['storage_error']?.toString() ?? '').isEmpty
          ? null
          : '插件无法保存测试记录，请检查服务端存储状态';

  final List<EvaluationCredential> credentials;
  final String? storageWarning;
  bool get busy => credentials.any((a) => a.busy);

  static List<EvaluationCredential> _credentials(Object? raw) {
    if (raw is! List) throw const FormatException('Invalid evaluation state');
    final ids = <String>{};
    return [for (final row in raw) _credential(row, ids)];
  }

  static EvaluationCredential _credential(Object? raw, Set<String> ids) {
    final json = evaluationMap(raw);
    final id = json['id'];
    if (id is! String ||
        id.trim().isEmpty ||
        !ids.add(id) ||
        EvaluationKind.values.any(
          (kind) =>
              json[kind.recordsKey] is! List ||
              (json[kind.recordsKey] as List).any((r) => r is! Map),
        )) {
      throw const FormatException('Invalid evaluation credential');
    }
    return EvaluationCredential(json);
  }
}
