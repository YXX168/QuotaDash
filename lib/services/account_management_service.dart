import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/managed_account.dart';
import 'private_http.dart';

abstract interface class AccountManagementRepository {
  Future<List<ManagedAccount>> fetchAccounts();
  Future<List<ManagedAccount>> setDisabled(
    ManagedAccount account,
    bool disabled,
  );
  void dispose();
}

class AccountManagementService implements AccountManagementRepository {
  AccountManagementService({
    required this.baseUri,
    required this.managementKey,
    http.Client? client,
  }) : _client = PrivateHttpClient(client ?? http.Client()) {
    validateManagementUri(baseUri);
  }

  final Uri baseUri;
  final String managementKey;
  final http.Client _client;

  Uri _endpoint({bool status = false}) {
    final base = baseUri.path.replaceFirst(RegExp(r'/+$'), '');
    final resource = base.endsWith('/v8/management')
        ? 'credentials'
        : 'auth-files';
    return baseUri.replace(path: '$base/$resource${status ? '/status' : ''}');
  }

  Map<String, String> get _headers => {
    'Authorization': 'Bearer $managementKey',
    'Content-Type': 'application/json',
  };

  @override
  Future<List<ManagedAccount>> fetchAccounts() async {
    final response = await _client
        .get(_endpoint(), headers: _headers)
        .timeout(const Duration(seconds: 25));
    _check(response);
    try {
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      if (data is! Map || data['files'] is! List) throw const FormatException();
      final seen = <String>{};
      return (data['files'] as List)
          .map((row) {
            if (row is! Map) throw const FormatException();
            final account = ManagedAccount.fromJson(
              Map<String, dynamic>.from(row),
            );
            if (account.identity.isEmpty || !seen.add(account.identity)) {
              throw const FormatException();
            }
            return account;
          })
          .toList(growable: false);
    } on FormatException {
      throw const AccountManagementException('管理端返回的账号列表无法识别');
    }
  }

  @override
  Future<List<ManagedAccount>> setDisabled(
    ManagedAccount account,
    bool disabled,
  ) async {
    if (!account.canToggle) {
      throw const AccountManagementException('该账号需要在管理端修改来源配置');
    }
    final response = await _client
        .patch(
          _endpoint(status: true),
          headers: _headers,
          body: jsonEncode({'name': account.lookup, 'disabled': disabled}),
        )
        .timeout(const Duration(seconds: 25));
    _check(response);
    // A successful write response alone does not establish persisted state.
    final accounts = await fetchAccounts();
    final updated = accounts.where((row) => row.identity == account.identity);
    if (updated.length != 1 || updated.single.disabled != disabled) {
      throw const AccountManagementException('账号状态尚未确认，请刷新后检查');
    }
    return accounts;
  }

  void _check(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) return;
    throw AccountManagementException(switch (response.statusCode) {
      401 || 403 => '没有账号管理权限，请检查管理密钥',
      404 => '管理端未提供账号管理接口',
      400 => '该账号不支持直接修改，请在管理端检查来源配置',
      _ => '账号操作失败，请稍后刷新检查',
    });
  }

  @override
  void dispose() => _client.close();
}

class AccountManagementException implements PublicError {
  const AccountManagementException(this.message);
  @override
  final String message;
  @override
  String toString() => message;
}
