import 'package:cliproxy_dash/services/private_http.dart';
import 'package:cliproxy_dash/services/proxy_api_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('authenticated requests refuse redirects', () async {
    final client = PrivateHttpClient(
      MockClient((request) async {
        expect(request.followRedirects, isFalse);
        return http.Response(
          '',
          302,
          headers: {'location': 'https://other.example.invalid/collect'},
        );
      }),
    );
    await expectLater(
      client.get(
        Uri.parse('https://private.example.invalid/config'),
        headers: {'Authorization': 'Bearer test-only'},
      ),
      throwsA(isA<PrivateNetworkException>()),
    );
    client.close();
  });

  test('network exceptions never display their private URL', () async {
    final client = PrivateHttpClient(
      MockClient((request) async {
        throw http.ClientException('private detail', request.url);
      }),
    );
    try {
      await client.get(Uri.parse('https://private.example.invalid/config'));
      fail('Expected a safe network error');
    } catch (error) {
      expect(safeErrorMessage(error), isNot(contains('private')));
      expect(safeErrorMessage(error), contains('连接失败'));
    }
    expect(
      safeErrorMessage(Exception('token=test-only')),
      isNot(contains('token')),
    );
    client.close();
  });

  test('server error bodies never enter user-facing exceptions', () async {
    final service = ProxyApiService(
      baseUri: Uri.parse('https://proxy.example.invalid/v8/management'),
      managementKey: 'test-only',
      client: MockClient(
        (_) async => http.Response('token=test-only private-address', 500),
      ),
    );
    await expectLater(
      service.fetchApiKeys(),
      throwsA(
        predicate(
          (error) =>
              safeErrorMessage(error).contains('HTTP 500') &&
              !safeErrorMessage(error).contains('test-only') &&
              !safeErrorMessage(error).contains('private-address'),
        ),
      ),
    );
    service.dispose();
  });

  test('connection URLs cannot embed credentials or tracking parameters', () {
    for (final url in [
      'https://user:password@proxy.example.invalid/v8/management',
      'https://proxy.example.invalid/?key=test-only',
      'https://proxy.example.invalid/#private',
      'ftp://proxy.example.invalid',
      'http://proxy.example.invalid',
      'http://192.0.2.1',
    ]) {
      expect(
        () => validateManagementUri(Uri.parse(url)),
        throwsA(isA<PrivateNetworkException>()),
      );
    }
    expect(
      () => validateManagementUri(
        Uri.parse('https://proxy.example.invalid/v8/management'),
      ),
      returnsNormally,
    );
  });

  test('HTTP is limited to literal local network addresses and loopback', () {
    for (final host in [
      'localhost',
      '127.0.0.1',
      '10.1.2.3',
      '172.16.1.2',
      '192.168.1.2',
      '::1',
      'fd00::1',
      'fe80::1',
    ]) {
      expect(isPrivateHttpHost(host), isTrue);
    }
    for (final host in [
      '172.32.0.1',
      '192.0.2.1',
      'example.invalid',
      '10.1.2.999',
      '2001:db8::1',
    ]) {
      expect(isPrivateHttpHost(host), isFalse);
    }
  });

  test(
    'legacy delete by value resolves an index without exposing the key in a URL',
    () async {
      final requests = <http.Request>[];
      final service = ProxyApiService(
        baseUri: Uri.parse('https://proxy.example.invalid/v0/management'),
        managementKey: 'test-only',
        client: MockClient((request) async {
          requests.add(request);
          return http.Response(
            request.method == 'GET' ? '["key-to-delete"]' : '{}',
            200,
          );
        }),
      );
      await service.deleteApiKey(value: 'key-to-delete');
      expect(requests.map((r) => r.method), ['GET', 'DELETE']);
      expect(requests.last.url.queryParameters, {'index': '0'});
      expect(
        requests.any((r) => r.url.toString().contains('key-to-delete')),
        isFalse,
      );
      service.dispose();
    },
  );
}
