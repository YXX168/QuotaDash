import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/codex_account.dart';
import '../models/antigravity_account.dart';
import '../models/provider_quota.dart';
import '../models/dashboard_snapshot.dart';
import '../models/quota_window.dart';
import 'quota_repository.dart';
import 'antigravity_quota.dart';

class ManagementService implements QuotaRepository {
  ManagementService({
    required this.baseUri,
    required this.managementKey,
    http.Client? client,
  }) : _client = client ?? http.Client();

  static const usageUrl = 'https://chatgpt.com/backend-api/wham/usage';
  static const resetCreditsUrl =
      'https://chatgpt.com/backend-api/wham/rate-limit-reset-credits';
  static const userAgent = 'codex_cli_rs/0.76.0 (Debian 13.0.0; x86_64)';
  static const antigravityQuotaUrls = [
    'https://daily-cloudcode-pa.googleapis.com/v1internal:retrieveUserQuotaSummary',
    'https://daily-cloudcode-pa.sandbox.googleapis.com/v1internal:retrieveUserQuotaSummary',
    'https://cloudcode-pa.googleapis.com/v1internal:retrieveUserQuotaSummary',
    'https://cloudcode-pa.googleapis.com/v1internal:fetchAvailableModels',
  ];
  static const antigravityUserAgent =
      'antigravity/cli/1.0.13 (aidev_client; os_type=darwin; arch=arm64)';

  final Uri baseUri;
  final String managementKey;
  final http.Client _client;

  @override
  Future<DashboardSnapshot> fetchDashboard() async {
    final response = await _getJson(_endpoint('auth-files'));
    final files = response['files'];
    if (files is! List) {
      throw const ManagementException('管理接口返回缺少 files 列表');
    }

    final enabledFiles = files
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .where((item) => !_isDisabled(item['disabled']))
        .toList();
    final authFiles = enabledFiles
        .where((item) => _provider(item) == 'codex')
        .map(AuthFileAccount.fromJson)
        .toList();

    final accountsFuture = Future.wait(authFiles.map(_fetchAccount));
    final antigravityFuture = Future.wait(
      enabledFiles
          .where((item) => _provider(item) == 'antigravity')
          .map(_fetchAntigravity),
    );
    return DashboardSnapshot(
      accounts: await accountsFuture,
      antigravityAccounts: await antigravityFuture,
      checkedAt: DateTime.now(),
    );
  }

  static String _provider(Map<String, dynamic> item) {
    final provider = item['provider']?.toString().trim() ?? '';
    return (provider.isEmpty ? item['type']?.toString() ?? '' : provider)
        .trim()
        .toLowerCase();
  }

  Future<AntigravityAccount> _fetchAntigravity(
    Map<String, dynamic> file,
  ) async {
    final auth = AuthFileAccount.fromJson(file);
    try {
      if (auth.authIndex.isEmpty) {
        throw const ManagementException('认证文件缺少 auth_index');
      }
      var project = _projectId(file);
      if (project.isEmpty) {
        // Older management servers omit project metadata from auth-files.
        // Read it in memory only; no token is persisted or sent by this app.
        final name = file['name']?.toString().trim() ?? '';
        if (name.isNotEmpty) {
          final metadata = await _getJson(
            _endpoint(
              'auth-files/download',
            ).replace(queryParameters: {'name': name}),
          );
          project = _projectId(metadata);
        }
      }
      if (project.isEmpty) {
        throw const ManagementException(
          '缺少 Antigravity 项目 ID，请在 CLIProxyAPI 重新登录该账号',
        );
      }
      Object? lastError;
      for (final url in antigravityQuotaUrls) {
        try {
          final payload = await _apiCall(
            auth.authIndex,
            url,
            data: {'project': project},
            agent: antigravityUserAgent,
          );
          final windows = parseAntigravityQuota(payload);
          if (windows.isEmpty) {
            lastError = const ManagementException('上游暂未返回 Antigravity 额度');
            continue;
          }
          return AntigravityAccount(
            auth: auth,
            quota: ProviderQuota(
              provider: QuotaProviderId.antigravity,
              windows: windows,
              checkedAt: DateTime.now(),
            ),
          );
        } on Exception catch (error) {
          lastError = error;
          if (error is ManagementException &&
              (error.statusCode == 401 || error.statusCode == 429))
            break;
        }
      }
      throw lastError ?? const ManagementException('未获取到 Antigravity 额度');
    } catch (error) {
      return AntigravityAccount(
        auth: auth,
        quota: ProviderQuota(
          provider: QuotaProviderId.antigravity,
          windows: const [],
          checkedAt: DateTime.now(),
          error: _friendlyError(error),
        ),
      );
    }
  }

  static String _projectId(Map<String, dynamic> file) {
    for (final raw in [
      file,
      file['metadata'],
      file['attributes'],
      file['installed'],
      file['web'],
    ]) {
      if (raw is! Map) continue;
      for (final key in ['project_id', 'projectId', 'gemini_virtual_project']) {
        final value = raw[key]?.toString().trim() ?? '';
        if (value.isNotEmpty) return value;
      }
    }
    return '';
  }

  Future<CodexAccount> _fetchAccount(AuthFileAccount auth) async {
    if (auth.authIndex.isEmpty) {
      return _failedAccount(auth, '认证文件缺少 auth_index');
    }

    try {
      final usage = await _apiCall(auth.authIndex, usageUrl);
      final rate = _map(usage['rate_limit'] ?? usage['rateLimit']);
      final plan = (usage['plan_type'] ?? usage['planType'] ?? 'unknown')
          .toString()
          .toLowerCase();
      final primary = _window(rate['primary_window'] ?? rate['primaryWindow']);
      final secondary = _window(
        rate['secondary_window'] ?? rate['secondaryWindow'],
      );
      final secondaryLabel = _secondaryLabel(secondary, plan);

      int? resetCredits;
      String? resetCreditsError;
      try {
        final credits = await _apiCall(auth.authIndex, resetCreditsUrl);
        resetCredits = _asInt(
          credits['availableCount'] ?? credits['available_count'],
        );
      } catch (error) {
        resetCreditsError = _friendlyError(error);
      }

      return CodexAccount(
        id: auth.id,
        authIndex: auth.authIndex,
        name: auth.name,
        email: auth.email,
        plan: plan,
        available: _asBool(rate['allowed']),
        limitReached: _asBool(rate['limit_reached'] ?? rate['limitReached']),
        primary: primary,
        secondary: secondary,
        secondaryLabel: secondaryLabel,
        resetCredits: resetCredits,
        resetCreditsError: resetCreditsError,
        successRequests: auth.successRequests,
        failedRequests: auth.failedRequests,
        recentRequests: auth.recentRequests,
      );
    } catch (error) {
      return _failedAccount(auth, _friendlyError(error));
    }
  }

  CodexAccount _failedAccount(AuthFileAccount auth, String error) {
    return CodexAccount(
      id: auth.id,
      authIndex: auth.authIndex,
      name: auth.name,
      email: auth.email,
      plan: 'unknown',
      available: false,
      limitReached: null,
      primary: null,
      secondary: null,
      secondaryLabel: '周额度',
      resetCredits: null,
      successRequests: auth.successRequests,
      failedRequests: auth.failedRequests,
      recentRequests: auth.recentRequests,
      error: error,
    );
  }

  Future<Map<String, dynamic>> _apiCall(
    String authIndex,
    String url, {
    Map<String, dynamic>? data,
    String agent = userAgent,
  }) async {
    final header = <String, String>{
      'Authorization': 'Bearer \$TOKEN\$',
      'Content-Type': 'application/json',
      'User-Agent': agent,
    };
    if (url.contains('rate-limit-reset-credits')) {
      header.addAll({
        'Accept': 'application/json',
        'OpenAI-Beta': 'codex-1',
        'Originator': 'Codex Desktop',
      });
    }
    final response = await _postJson(_endpoint('api-call'), {
      'authIndex': authIndex,
      'method': data == null ? 'GET' : 'POST',
      'url': url,
      'header': header,
      if (data != null) 'data': jsonEncode(data),
    });
    final status = _asInt(response['status_code']) ?? 0;
    if (status < 200 || status >= 300) {
      throw ManagementException('上游接口返回 HTTP $status', statusCode: status);
    }
    final body = response['body'];
    if (body is String) {
      try {
        final decoded = jsonDecode(body);
        if (decoded is Map) return Map<String, dynamic>.from(decoded);
      } on FormatException {
        throw const ManagementException('上游接口返回了无效 JSON');
      }
      throw const ManagementException('上游接口返回了无法识别的数据');
    }
    if (body is Map) return Map<String, dynamic>.from(body);
    throw const ManagementException('上游接口响应缺少 body');
  }

  Future<Map<String, dynamic>> _getJson(Uri uri) async {
    final response = await _client
        .get(uri, headers: _headers)
        .timeout(const Duration(seconds: 25));
    return _decodeManagementResponse(response);
  }

  Future<Map<String, dynamic>> _postJson(
    Uri uri,
    Map<String, dynamic> body,
  ) async {
    final response = await _client
        .post(uri, headers: _headers, body: jsonEncode(body))
        .timeout(const Duration(seconds: 35));
    return _decodeManagementResponse(response);
  }

  Map<String, dynamic> _decodeManagementResponse(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final preview = response.body.replaceAll(RegExp(r'\s+'), ' ').trim();
      final previewText = preview.isEmpty
          ? ''
          : '：${preview.substring(0, preview.length.clamp(0, 180).toInt())}';
      throw ManagementException(
        '管理接口返回 HTTP ${response.statusCode}$previewText',
      );
    }
    if (response.body.trim().isEmpty) return const {};
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is! Map) {
        throw const ManagementException('管理接口返回了无法识别的数据');
      }
      return Map<String, dynamic>.from(decoded);
    } on FormatException {
      throw const ManagementException('管理接口返回了无效 JSON');
    }
  }

  Map<String, String> get _headers => {
    'Authorization': 'Bearer $managementKey',
    'Content-Type': 'application/json',
  };

  Uri _endpoint(String name) {
    final basePath = baseUri.path.endsWith('/')
        ? baseUri.path.substring(0, baseUri.path.length - 1)
        : baseUri.path;
    return baseUri.replace(path: '$basePath/$name');
  }

  static Map<String, dynamic> _map(Object? value) {
    return value is Map ? Map<String, dynamic>.from(value) : const {};
  }

  static QuotaWindow? _window(Object? value) {
    if (value is! Map) return null;
    return QuotaWindow.fromJson(Map<String, dynamic>.from(value));
  }

  static String _secondaryLabel(QuotaWindow? window, String plan) {
    final label = window?.displayLabel;
    if (label != null) return label;
    return plan == 'team' ? '月度额度' : '周额度';
  }

  static bool? _asBool(Object? value) {
    if (value is bool) return value;
    if (value?.toString().toLowerCase() == 'true') return true;
    if (value?.toString().toLowerCase() == 'false') return false;
    return null;
  }

  static bool _isDisabled(Object? value) {
    if (value is bool) return value;
    return value?.toString().toLowerCase() == 'true';
  }

  static int? _asInt(Object? value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }

  static String _friendlyError(Object error) {
    if (error is ManagementException) return error.message;
    return error.toString().replaceFirst('Exception: ', '');
  }
}

class ManagementException implements Exception {
  const ManagementException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}
