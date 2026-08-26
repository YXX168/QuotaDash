import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/opencode_quota.dart';

class OpencodeService {
  /// Optional test hook; production code leaves this null.
  static http.Client? clientOverride;

  OpencodeService({required this.apiKey, http.Client? client})
    : _client = client ?? clientOverride ?? http.Client();

  static const usageUrl = 'https://opencode.ai/zen/go/v1/usage';

  final String apiKey;
  final http.Client _client;

  void dispose() => _client.close();

  Future<OpencodeQuota> fetchQuota() async {
    if (apiKey.trim().isEmpty) {
      throw const OpencodeException('未配置 OpenCode API Key');
    }
    final response = await _client
        .get(
          Uri.parse(usageUrl),
          headers: {
            'Accept': 'application/json',
            'Authorization': 'Bearer ${apiKey.trim()}',
          },
        )
        .timeout(const Duration(seconds: 20));
    if (response.statusCode == 401 || response.statusCode == 403) {
      throw const OpencodeException('API Key 无效或已过期');
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw OpencodeException('用量接口返回 HTTP ${response.statusCode}');
    }
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is! Map) {
        throw const OpencodeException('用量接口返回了无法识别的数据');
      }
      return OpencodeQuota.fromJson(Map<String, dynamic>.from(decoded));
    } on FormatException {
      throw const OpencodeException('用量接口返回了无效 JSON');
    }
  }
}

class OpencodeException implements Exception {
  const OpencodeException(this.message);

  final String message;

  @override
  String toString() => message;
}
