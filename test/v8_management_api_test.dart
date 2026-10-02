import 'dart:convert';

import 'package:cliproxy_dash/models/antigravity_account.dart';
import 'package:cliproxy_dash/models/codex_account.dart';
import 'package:cliproxy_dash/models/dashboard_snapshot.dart';
import 'package:cliproxy_dash/models/provider_quota.dart';
import 'package:cliproxy_dash/models/request_bucket.dart';
import 'package:cliproxy_dash/services/proxy_api_service.dart';
import 'package:cliproxy_dash/services/management_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart';
import 'package:http/testing.dart';

void main() {
  test('v8 API key and runtime config routes use the new tree', () async {
    final requests = <Request>[];
    final client = MockClient((request) async {
      requests.add(request);
      if (request.method == 'GET' &&
          request.url.path.endsWith('/config/access/api-keys')) {
        return Response(jsonEncode(['first']), 200);
      }
      if (request.method == 'GET' &&
          request.url.path.endsWith('/config/server/discovery/enabled')) {
        return Response('true', 200);
      }
      return Response(jsonEncode({'status': 'ok', 'config-version': 8}), 200);
    });
    final service = ProxyApiService(
      baseUri: Uri.parse('https://proxy.example/v8/management'),
      managementKey: 'secret',
      client: client,
    );

    expect(await service.fetchApiKeys(), ['first']);
    await service.addApiKey('second');
    expect(await service.readConfigPath('server/discovery/enabled'), true);
    await service.writeConfigPath('server/discovery/enabled', false);

    expect(requests.map((request) => '${request.method} ${request.url.path}'), [
      'GET /v8/management/config/access/api-keys',
      'GET /v8/management/config/access/api-keys',
      'PUT /v8/management/config/access/api-keys',
      'GET /v8/management/config/server/discovery/enabled',
      'PUT /v8/management/config/server/discovery/enabled',
    ]);
    expect(jsonDecode(requests[2].body), ['first', 'second']);
  });

  test('request buckets combine Codex and Antigravity data', () {
    const codex = CodexAccount(
      id: 'codex',
      authIndex: 'c',
      name: 'codex',
      email: '',
      plan: 'plus',
      available: true,
      limitReached: false,
      primary: null,
      secondary: null,
      secondaryLabel: '周额度',
      resetCredits: null,
      successRequests: 3,
      failedRequests: 1,
      recentRequests: [
        RequestBucket(time: '10:00-10:10', success: 2, failed: 1),
      ],
    );
    const auth = AuthFileAccount(
      id: 'antigravity',
      authIndex: 'a',
      name: 'antigravity',
      email: '',
      successRequests: 4,
      failedRequests: 2,
      recentRequests: [
        RequestBucket(time: '10:00-10:10', success: 4, failed: 2),
      ],
    );
    final snapshot = DashboardSnapshot(
      accounts: [codex],
      antigravityAccounts: [
        AntigravityAccount(
          auth: auth,
          quota: ProviderQuota(
            provider: QuotaProviderId.antigravity,
            windows: [],
          ),
        ),
      ],
      checkedAt: DateTime(2026),
    );

    expect(snapshot.recentRequests, 9);
    expect(snapshot.successRate, closeTo(70, 0.001));
    expect(snapshot.recentRequestBuckets.single.success, 6);
    expect(snapshot.recentRequestBuckets.single.failed, 3);
  });

  test('request windows align by time rather than list position', () {
    final snapshot = _trafficSnapshot(
      codex: const [
        RequestBucket(time: '10:00-10:10', success: 2, failed: 1),
        RequestBucket(time: '10:10-10:20', success: 3, failed: 0),
      ],
      antigravity: const [
        RequestBucket(time: '10:00-10:10', success: 4, failed: 2),
      ],
    );
    expect(snapshot.recentRequestBuckets.map((bucket) => bucket.time), [
      '10:00-10:10',
      '10:10-10:20',
    ]);
    expect(snapshot.recentRequestBuckets.map((bucket) => bucket.success), [
      6,
      3,
    ]);
    expect(snapshot.recentRequestBuckets.map((bucket) => bucket.failed), [
      3,
      0,
    ]);
    expect(snapshot.recentRequests, 12);
  });

  test('request windows retain missing provider intervals across midnight', () {
    final snapshot = _trafficSnapshot(
      codex: const [
        RequestBucket(time: '23:50-00:00', success: 2, failed: 0),
        RequestBucket(time: '00:10-00:20', success: 3, failed: 0),
      ],
      antigravity: const [
        RequestBucket(time: '00:00-00:10', success: 4, failed: 1),
      ],
    );
    expect(snapshot.recentRequestBuckets.map((bucket) => bucket.time), [
      '23:50-00:00',
      '00:00-00:10',
      '00:10-00:20',
    ]);
    expect(snapshot.recentRequestBuckets.map((bucket) => bucket.total), [
      2,
      5,
      3,
    ]);
  });

  test('Antigravity-only and unlabeled request windows remain usable', () {
    final antigravity = _trafficSnapshot(
      antigravity: const [
        RequestBucket(time: '10:00-10:10', success: 4, failed: 2),
      ],
    );
    expect(antigravity.recentRequests, 6);
    expect(antigravity.recentRequestBuckets.single.total, 6);
    final unlabeled = _trafficSnapshot(
      codex: const [
        RequestBucket(time: null, success: 2, failed: 0),
        RequestBucket(time: null, success: 3, failed: 0),
      ],
      antigravity: const [RequestBucket(time: null, success: 4, failed: 1)],
    );
    expect(unlabeled.recentRequestBuckets.map((bucket) => bucket.total), [
      2,
      8,
    ]);
  });

  test('v8 YAML reads and writes preserve Chinese text and headers', () async {
    const yaml = 'config-version: 8\n# 中文配置\nplugins:\n  enabled: false\n';
    final requests = <Request>[];
    final service = ProxyApiService(
      baseUri: Uri.parse('https://proxy.example/v8/management'),
      managementKey: 'secret',
      client: MockClient((request) async {
        requests.add(request);
        if (request.method == 'GET') {
          return Response(
            yaml,
            200,
            headers: {'content-type': 'application/yaml; charset=utf-8'},
          );
        }
        return Response('{"status":"ok"}', 200);
      }),
    );
    expect(await service.fetchConfigYaml(), yaml);
    await service.replaceConfigYaml(yaml);
    expect(requests.last.url.path, '/v8/management/config.yaml');
    expect(requests.last.headers['content-type'], contains('application/yaml'));
    expect(requests.last.body, yaml);
  });

  test('malformed key reads never overwrite the existing key list', () async {
    final methods = <String>[];
    final service = ProxyApiService(
      baseUri: Uri.parse('https://proxy.example/v8/management'),
      managementKey: 'secret',
      client: MockClient((request) async {
        methods.add(request.method);
        return Response('{"unexpected":true}', 200);
      }),
    );
    await expectLater(
      service.addApiKey('new'),
      throwsA(isA<ProxyApiException>()),
    );
    expect(methods, ['GET']);
  });

  test('v8 dashboard uses credentials and requests API call routes', () async {
    final paths = <String>[];
    final service = ManagementService(
      baseUri: Uri.parse('https://proxy.example/v8/management'),
      managementKey: 'secret',
      client: MockClient((request) async {
        paths.add(request.url.path);
        if (request.method == 'GET') {
          return Response(
            jsonEncode({
              'files': [
                {
                  'id': 'codex',
                  'auth_index': 'c',
                  'provider': 'codex',
                  'name': 'codex.json',
                },
              ],
            }),
            200,
          );
        }
        expect(request.url.path, '/v8/management/requests/api-call');
        final body = jsonDecode(request.body) as Map;
        expect(body['authIndex'], 'c');
        return Response(
          jsonEncode({
            'status_code': 200,
            'body': jsonEncode(
              body['url'] == ManagementService.usageUrl
                  ? {
                      'plan_type': 'plus',
                      'rate_limit': {'allowed': true, 'limit_reached': false},
                    }
                  : {'reset_credits': 1},
            ),
          }),
          200,
        );
      }),
    );
    final snapshot = await service.fetchDashboard();
    expect(snapshot.accounts.single.error, isNull);
    expect(paths.first, '/v8/management/credentials');
    expect(paths.skip(1), everyElement('/v8/management/requests/api-call'));
  });
}

DashboardSnapshot _trafficSnapshot({
  List<RequestBucket> codex = const [],
  List<RequestBucket> antigravity = const [],
}) => DashboardSnapshot(
  accounts: codex.isEmpty
      ? []
      : [
          CodexAccount(
            id: 'codex',
            authIndex: 'c',
            name: 'codex',
            email: '',
            plan: 'plus',
            available: true,
            limitReached: false,
            primary: null,
            secondary: null,
            secondaryLabel: '周额度',
            resetCredits: null,
            successRequests: 0,
            failedRequests: 0,
            recentRequests: codex,
          ),
        ],
  antigravityAccounts: antigravity.isEmpty
      ? []
      : [
          AntigravityAccount(
            auth: AuthFileAccount(
              id: 'antigravity',
              authIndex: 'a',
              name: 'antigravity',
              email: '',
              successRequests: 0,
              failedRequests: 0,
              recentRequests: antigravity,
            ),
            quota: const ProviderQuota(
              provider: QuotaProviderId.antigravity,
              windows: [],
            ),
          ),
        ],
  checkedAt: DateTime(2026),
);
