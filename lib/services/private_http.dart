import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;

/// Only application-authored messages may be shown in shareable UI errors.
abstract interface class PublicError implements Exception {
  String get message;
}

String safeErrorMessage(Object? error) {
  if (error is PublicError) return error.message;
  if (error is TimeoutException) return '连接超时，请稍后重试';
  return '操作失败，请检查连接或配置后重试';
}

void validateManagementUri(Uri uri) {
  if (!['https', 'http'].contains(uri.scheme) || uri.host.isEmpty) {
    throw const PrivateNetworkException('请输入完整的 HTTP 或 HTTPS 服务地址');
  }
  if (uri.userInfo.isNotEmpty || uri.hasQuery || uri.hasFragment) {
    throw const PrivateNetworkException('服务地址不能包含账号、密码、参数或片段');
  }
  if (uri.scheme == 'http' && !isPrivateHttpHost(uri.host)) {
    throw const PrivateNetworkException('远程服务必须使用 HTTPS；HTTP 仅用于本机或局域网 IP');
  }
}

bool isPrivateHttpHost(String host) {
  final name = host.toLowerCase().replaceAll(RegExp(r'^\[|\]$'), '');
  if (name == 'localhost') return true;
  final address = InternetAddress.tryParse(name);
  if (address == null) return false;
  final bytes = address.rawAddress;
  if (address.type == InternetAddressType.IPv4) {
    return bytes[0] == 127 ||
        bytes[0] == 10 ||
        (bytes[0] == 172 && bytes[1] >= 16 && bytes[1] <= 31) ||
        (bytes[0] == 192 && bytes[1] == 168);
  }
  return address.isLoopback ||
      (bytes[0] & 0xfe) == 0xfc ||
      (bytes[0] == 0xfe && (bytes[1] & 0xc0) == 0x80);
}

/// Credentials are never resent to a redirect target. Transport failures must
/// not expose private hostnames, IPs, request URLs or platform diagnostics.
class PrivateHttpClient extends http.BaseClient {
  PrivateHttpClient(this._inner);

  final http.Client _inner;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    request.followRedirects = false;
    if (request.url.scheme == 'http' && !isPrivateHttpHost(request.url.host)) {
      throw const PrivateNetworkException('远程服务必须使用 HTTPS');
    }
    try {
      final response = await _inner.send(request);
      if (response.statusCode >= 300 && response.statusCode < 400) {
        throw const PrivateNetworkException('服务地址发生重定向，请填写最终 HTTPS 地址');
      }
      return response;
    } on PrivateNetworkException {
      rethrow;
    } on TimeoutException {
      rethrow;
    } catch (_) {
      throw const PrivateNetworkException('连接失败，请检查网络和服务地址');
    }
  }

  @override
  void close() => _inner.close();
}

class PrivateNetworkException implements PublicError {
  const PrivateNetworkException(this.message);

  @override
  final String message;

  @override
  String toString() => message;
}
