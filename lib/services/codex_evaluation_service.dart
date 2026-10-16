import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/codex_evaluation.dart';
import 'private_http.dart';

abstract interface class CodexEvaluationRepository {
  Future<EvaluationState> fetchState();
  Future<List<String>> fetchModels(List<EvaluationCredential> credentials);
  Future<String> run({
    required EvaluationKind kind,
    required List<String> ids,
    required String model,
    String effort = 'low',
    int runs = 1,
    String mode = 'quick',
    int concurrency = 2,
  });
  Future<void> cancel(EvaluationKind kind, List<String> ids);
  Future<EvaluationRecord> fetchRecord(
    String credentialId,
    EvaluationRecord record,
  );
  void dispose();
}

class CodexEvaluationService implements CodexEvaluationRepository {
  CodexEvaluationService({
    required this.baseUri,
    required this.managementKey,
    http.Client? client,
  }) : _client = PrivateHttpClient(client ?? http.Client()) {
    validateManagementUri(baseUri);
  }

  static const pluginId = 'cpa-codex-candy-eval';
  final Uri baseUri;
  final String managementKey;
  final http.Client _client;

  @override
  void dispose() => _client.close();

  Uri _endpoint(String route) => baseUri.replace(
    path: '${baseUri.path.replaceFirst(RegExp(r'/+$'), '')}/$route',
  );

  Future<Map<String, dynamic>> _request(
    String route, {
    String method = 'GET',
    Map<String, dynamic>? body,
    Map<String, String>? query,
  }) async {
    var uri = _endpoint(route).replace(queryParameters: query);
    Future<http.Response> send() {
      final headers = {
        'Authorization': 'Bearer $managementKey',
        'Content-Type': 'application/json',
      };
      return (method == 'POST'
              ? _client.post(uri, headers: headers, body: jsonEncode(body))
              : _client.get(uri, headers: headers))
          .timeout(const Duration(seconds: 30));
    }

    var response = await send();
    final path = baseUri.path.replaceFirst(RegExp(r'/+$'), '');
    if (response.statusCode == 404 && path.endsWith('/v8/management')) {
      final prefix = path.substring(0, path.length - '/v8/management'.length);
      final legacyRoute = route == 'credentials/models'
          ? 'auth-files/models'
          : route;
      uri = uri.replace(path: '$prefix/v0/management/$legacyRoute');
      response = await send();
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw EvaluationException(switch (response.statusCode) {
        401 || 403 => '管理密码无效或没有访问权限，请检查连接设置',
        404 => '未找到降智测试插件，请在管理端安装并启用插件',
        400 => '测试参数或账号状态已变化，请刷新后重新选择',
        _ => '测试接口暂时不可用（HTTP ${response.statusCode}），请稍后重试',
      }, statusCode: response.statusCode);
    }
    try {
      final data = jsonDecode(response.body);
      if (data is Map<String, dynamic>) return data;
    } on FormatException {
      // Raw server bodies can include keys, URLs or provider diagnostics.
    }
    throw const EvaluationException('测试接口返回的数据格式无效，请升级插件后重试');
  }

  Future<Map<String, dynamic>> _plugin(
    String route, {
    String method = 'GET',
    Map<String, dynamic>? body,
    Map<String, String>? query,
  }) => _request(
    'plugins/$pluginId/$route',
    method: method,
    body: body,
    query: query,
  );

  @override
  Future<EvaluationState> fetchState() async {
    final data = await _plugin('state');
    try {
      return EvaluationState.fromJson(data);
    } on FormatException {
      throw const EvaluationException('测试记录格式无效，请升级插件后重试');
    }
  }

  Future<List<String>?> _modelsFor(String id) async {
    try {
      final route = baseUri.path.contains('/v8/management')
          ? 'credentials/models'
          : 'auth-files/models';
      final data = await _request(route, query: {'name': id});
      final raw = data['models'];
      if (raw is! List) return null;
      return raw
          .whereType<Map>()
          .map((r) => (r['id'] ?? r['name'] ?? '').toString().trim())
          .where((id) => id.isNotEmpty)
          .toSet()
          .toList();
    } on EvaluationException catch (e) {
      if (e.statusCode == 401 || e.statusCode == 403) rethrow;
      return null;
    } on Exception {
      return null; // Unknown catalog must never be treated as unsupported.
    }
  }

  @override
  Future<List<String>> fetchModels(
    List<EvaluationCredential> credentials,
  ) async {
    final catalogs = await Future.wait([
      for (final a in credentials.where((a) => !a.disabled)) _modelsFor(a.id),
    ]);
    return catalogs
        .whereType<List<String>>()
        .expand((x) => x)
        .where(
          (id) =>
              !id.toLowerCase().contains('image') &&
              id.toLowerCase().split('/').last.split('(').first !=
                  'codex-auto-review',
        )
        .toSet()
        .toList()
      ..sort();
  }

  @override
  Future<String> run({
    required EvaluationKind kind,
    required List<String> ids,
    required String model,
    String effort = 'low',
    int runs = 1,
    String mode = 'quick',
    int concurrency = 2,
  }) async {
    if (ids.isEmpty ||
        ids.any((id) => id.trim().isEmpty) ||
        model.trim().isEmpty ||
        runs < 1 ||
        runs > 10 ||
        !['quick', 'standard', 'strict'].contains(mode) ||
        !['none', 'low', 'medium', 'high', 'xhigh', 'max'].contains(effort) ||
        concurrency < 1 ||
        concurrency > (kind == EvaluationKind.modelTrace ? 3 : 6)) {
      throw const EvaluationException('请选择有效的账号、模型和测试参数');
    }
    final catalog = <String, List<String>>{};
    for (final id in ids.toSet()) {
      final models = await _modelsFor(id);
      if (models != null) catalog[id] = models;
    }
    final result = await _plugin(
      '${kind.route}run',
      method: 'POST',
      body: {
        'auth_ids': ids.toSet().toList(),
        'model': model.trim(),
        'model_catalog': catalog,
        if (kind == EvaluationKind.candy) ...{
          'effort': effort,
          'runs': runs,
        } else ...{
          'concurrency': concurrency,
          if (kind == EvaluationKind.fingerprint) 'mode': mode,
        },
      },
    );
    final count = evaluationInt(result['started']) ?? 0;
    final skipped = evaluationInt(result['skipped']) ?? 0;
    final busy = evaluationInt(result['busy']) ?? 0;
    final unchecked = evaluationInt(result['unchecked']) ?? 0;
    return '已启动 $count 个账号${skipped > 0 ? '；$skipped 个不支持该模型，已跳过' : ''}'
        '${busy > 0 ? '；$busy 个正在测试' : ''}${unchecked > 0 ? '；$unchecked 个模型目录未知，交由服务端处理' : ''}';
  }

  @override
  Future<void> cancel(EvaluationKind kind, List<String> ids) async {
    if (kind == EvaluationKind.candy || ids.isEmpty) {
      throw const EvaluationException('此测试不支持停止');
    }
    await _plugin(
      '${kind.route}cancel',
      method: 'POST',
      body: {'auth_ids': ids},
    );
  }

  @override
  Future<EvaluationRecord> fetchRecord(
    String credentialId,
    EvaluationRecord record,
  ) async {
    if (record.kind == EvaluationKind.candy) return record;
    if (record.id.isEmpty) throw const EvaluationException('缺少测试记录标识，请刷新后重试');
    final data = await _plugin(
      '${record.kind.route}record',
      query: {'auth_id': credentialId, 'id': record.id},
    );
    return EvaluationRecord(record.kind, data);
  }
}

class EvaluationException implements PublicError {
  const EvaluationException(this.message, {this.statusCode});
  @override
  final String message;
  final int? statusCode;
  @override
  String toString() => message;
}
