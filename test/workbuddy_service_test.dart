import 'dart:convert';

import 'package:cliproxy_dash/models/workbuddy_account.dart';
import 'package:cliproxy_dash/services/management_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

Map<String, Object?> credential(String index, {bool disabled = false}) => {
  'id': 'file-$index',
  'name': 'unrelated-$index.json',
  'provider': ' WorkBuddy ',
  'auth_index': index,
  'disabled': disabled,
  'quota': {'signals': []},
  'success': 2,
  'failed': 1,
  'recent_requests': [
    {'time': '10:00-10:10', 'success': 2, 'failed': 1},
  ],
};

http.Response jsonResponse(Object body, {int status = 200}) =>
    http.Response(jsonEncode(body), status);

Map<String, Object?> creditRow(String index) => {
  'auth_index': index,
  'nickname': 'Synthetic $index',
  'region': 'global',
  'credits': {
    'total_remain': 75,
    'total_used': 25,
    'total_size': 100,
    'pack_count': 1,
    'fetched_at': '2026-10-03T01:00:00Z',
    'packages': [
      {'name': 'Test package', 'remain': 75, 'used': 25, 'size': 100},
    ],
  },
};

ManagementService service(MockClient client, {String version = 'v8'}) =>
    ManagementService(
      baseUri: Uri.parse(
        'https://proxy.example.invalid/team/$version/management',
      ),
      managementKey: 'fixture-key',
      client: client,
    );

void main() {
  test(
    'explicit type wins over unknown provider and filename inference',
    () async {
      final queries = <String>[];
      final result = await service(
        MockClient((request) async {
          if (request.url.path.endsWith('/credentials')) {
            return jsonResponse({
              'files': [
                {
                  ...credential('typed'),
                  'provider': 'unknown',
                  'type': ' WorkBuddy ',
                  'name': 'renamed.json',
                },
                {
                  ...credential('unrelated'),
                  'provider': 'unknown',
                  'type': 'other-provider',
                  'name': 'workbuddy-backup.json',
                },
                {
                  ...credential('conflicting'),
                  'provider': 'workbuddy',
                  'type': 'other-provider',
                },
              ],
            });
          }
          if (request.url.path.endsWith('/accounts')) {
            return jsonResponse({
              'accounts': [
                {'auth_index': 'typed'},
              ],
            });
          }
          final index = request.url.queryParameters['auth_index']!;
          queries.add(index);
          return jsonResponse({
            'accounts': [creditRow(index)],
          });
        }),
      ).fetchDashboard();
      expect(queries, ['typed']);
      expect(result.workBuddyAccounts.single.auth.authIndex, 'typed');
    },
  );

  for (final legacyOnly in [false, true]) {
    test(
      'legacy CN and Global credentials survive unknown provider ($legacyOnly)',
      () async {
        final queries = <String>[];
        final cn = {
          ...credential('cn-account'),
          'provider': 'unknown',
          'type': 'unknown',
          'name': 'workbuddy-cn-fixture.json',
        };
        final global = {
          ...credential('global-account'),
          'name': 'workbuddy-global-fixture.json',
          if (legacyOnly) 'provider': 'unknown',
        };
        final result = await service(
          MockClient((request) async {
            if (request.url.path.endsWith('/credentials')) {
              return jsonResponse({
                'files': [
                  cn,
                  global,
                  {
                    'provider': 'unknown',
                    'name': 'other-fixture.json',
                    'auth_index': 'other',
                  },
                ],
              });
            }
            if (request.url.path.endsWith('/accounts')) {
              return jsonResponse({
                'accounts': [
                  {'auth_index': 'global-account', 'region': 'global'},
                  {'auth_index': 'cn-account', 'region': 'cn'},
                ],
              });
            }
            final index = request.url.queryParameters['auth_index']!;
            queries.add(index);
            return jsonResponse({
              'accounts': [
                {
                  ...creditRow(index),
                  'region': index == 'cn-account' ? 'cn' : 'global',
                },
              ],
            });
          }),
        ).fetchDashboard();
        expect(queries, ['cn-account', 'global-account']);
        expect(result.workBuddyAccounts.map((a) => a.regionLabel), [
          '国内版',
          '国际版',
        ]);
        expect(result.workBuddyAccounts.every((a) => a.error == null), isTrue);
        expect(result.totalSuccessRequests, 4);
      },
    );
  }

  test(
    'unloaded plugin keeps legacy accounts visible with unknown credits',
    () async {
      final result = await service(
        MockClient((request) async {
          if (request.url.path.endsWith('/credentials')) {
            return jsonResponse({
              'files': [
                {
                  ...credential('cn'),
                  'provider': 'unknown',
                  'name': 'workbuddy-cn-fixture.json',
                },
                {
                  ...credential('global'),
                  'provider': '',
                  'name': 'WORKBUDDY-global-fixture.json',
                },
              ],
            });
          }
          expect(request.url.path.endsWith('/accounts'), isTrue);
          return jsonResponse({}, status: 404);
        }),
      ).fetchDashboard();
      expect(result.workBuddyAccounts, hasLength(2));
      expect(
        result.workBuddyAccounts.every(
          (a) => a.credits == null && a.error != null,
        ),
        isTrue,
      );
    },
  );

  test(
    'reads real credits sequentially and joins only by auth_index',
    () async {
      var active = 0;
      var maximum = 0;
      final queries = <String>[];
      final result = await service(
        MockClient((request) async {
          expect(request.headers['Authorization'], 'Bearer fixture-key');
          if (request.url.path.endsWith('/credentials')) {
            return jsonResponse({
              'files': [credential('one'), credential('two')],
            });
          }
          expect(request.method, 'GET');
          if (request.url.path.endsWith('/accounts')) {
            return jsonResponse({
              'accounts': [
                {'auth_index': 'two', 'nickname': 'Second', 'selected': true},
                {'auth_index': 'one', 'nickname': 'First'},
              ],
            });
          }
          expect(request.url.path.endsWith('/credits'), isTrue);
          final index = request.url.queryParameters['auth_index']!;
          queries.add(index);
          active++;
          if (active > maximum) maximum = active;
          await Future<void>.delayed(const Duration(milliseconds: 5));
          active--;
          return jsonResponse({
            'accounts': [creditRow(index)],
          });
        }),
      ).fetchDashboard();
      expect(queries, ['one', 'two']);
      expect(maximum, 1);
      expect(result.workBuddyAccounts.map((a) => a.auth.authIndex), [
        'one',
        'two',
      ]);
      expect(result.workBuddyAccounts.first.credits!.totalRemaining, 75);
      expect(result.workBuddyAccounts.last.selected, isTrue);
      expect(result.recentRequests, 6);
      expect(result.totalSuccessRequests, 4);
    },
  );

  for (final version in ['v8', 'v0']) {
    test(
      '$version plugin routing preserves prefix, origin and query',
      () async {
        final paths = <String>[];
        final result = await service(
          MockClient((request) async {
            expect(request.url.host, 'proxy.example.invalid');
            if (request.url.path.endsWith('/credentials') ||
                request.url.path.endsWith('/auth-files')) {
              return jsonResponse({
                'files': [credential('one')],
              });
            }
            paths.add(request.url.path);
            if (request.url.path.contains('/v8/')) {
              return jsonResponse({}, status: 404);
            }
            if (request.url.path.endsWith('/accounts')) {
              return jsonResponse({
                'accounts': [
                  {'auth_index': 'one'},
                ],
              });
            }
            expect(request.url.queryParameters, {'auth_index': 'one'});
            return jsonResponse({
              'accounts': [creditRow('one')],
            });
          }),
          version: version,
        ).fetchDashboard();
        expect(result.workBuddyAccounts.single.error, isNull);
        expect(paths, [
          if (version == 'v8') '/team/v8/management/plugins/workbuddy/accounts',
          '/team/v0/management/plugins/workbuddy/accounts',
          if (version == 'v8') '/team/v8/management/plugins/workbuddy/credits',
          '/team/v0/management/plugins/workbuddy/credits',
        ]);
      },
    );
  }

  for (final status in [401, 403, 429, 500]) {
    test('HTTP $status does not retry or expose plugin diagnostics', () async {
      var calls = 0;
      final result = await service(
        MockClient((request) async {
          if (request.url.path.endsWith('/credentials')) {
            return jsonResponse({
              'files': [credential('one'), credential('two')],
            });
          }
          calls++;
          return jsonResponse({
            'error': 'synthetic-private-diagnostic',
          }, status: status);
        }),
      ).fetchDashboard();
      expect(calls, 1);
      expect(result.workBuddyAccounts, hasLength(2));
      for (final account in result.workBuddyAccounts) {
        expect(account.error.toString(), workBuddyQuotaError);
        expect(account.credits, isNull);
      }
    });
  }

  test(
    'failed credits do not hide other WorkBuddy or Codex accounts',
    () async {
      final result = await service(
        MockClient((request) async {
          if (request.url.path.endsWith('/credentials')) {
            return jsonResponse({
              'files': [
                credential('bad'),
                credential('good'),
                {'provider': 'codex', 'auth_index': 'codex'},
              ],
            });
          }
          if (request.url.path.endsWith('/api-call')) {
            final body = jsonDecode(request.body) as Map;
            return jsonResponse({
              'status_code': 200,
              'body': body['url'] == ManagementService.usageUrl
                  ? {
                      'rate_limit': {'allowed': true},
                    }
                  : {'availableCount': 1},
            });
          }
          if (request.url.path.endsWith('/accounts')) {
            return jsonResponse({
              'accounts': [
                {'auth_index': 'bad'},
                {'auth_index': 'good'},
              ],
            });
          }
          final index = request.url.queryParameters['auth_index']!;
          return jsonResponse({
            'accounts': [
              if (index == 'bad')
                {'auth_index': index, 'error': 'synthetic diagnostic'}
              else
                creditRow(index),
            ],
          });
        }),
      ).fetchDashboard();
      expect(result.accounts.single.hasError, isFalse);
      expect(
        result.workBuddyAccounts.first.error.toString(),
        workBuddyQuotaError,
      );
      expect(result.workBuddyAccounts.last.credits!.totalRemaining, 75);
    },
  );

  test('disabled and missing-index credentials never query credits', () async {
    var creditsCalls = 0;
    final result = await service(
      MockClient((request) async {
        if (request.url.path.endsWith('/credentials')) {
          return jsonResponse({
            'files': [credential('off', disabled: true), credential('')],
          });
        }
        if (request.url.path.endsWith('/credits')) creditsCalls++;
        return jsonResponse({
          'accounts': [
            {'auth_index': 'off', 'disabled': true},
          ],
        });
      }),
    ).fetchDashboard();
    expect(creditsCalls, 0);
    expect(result.workBuddyAccounts.first.disabled, isTrue);
    expect(result.workBuddyAccounts.first.error, isNull);
    expect(result.workBuddyAccounts.last.error, isNotNull);
  });

  test(
    'wrong or ambiguous credit identity remains an account-local failure',
    () async {
      for (final rows in [
        [creditRow('other')],
        [creditRow('one'), creditRow('one')],
      ]) {
        final result = await service(
          MockClient((request) async {
            if (request.url.path.endsWith('/credentials')) {
              return jsonResponse({
                'files': [credential('one')],
              });
            }
            if (request.url.path.endsWith('/accounts')) {
              return jsonResponse({
                'accounts': [
                  {'auth_index': 'one'},
                ],
              });
            }
            return jsonResponse({'accounts': rows});
          }),
        ).fetchDashboard();
        expect(result.workBuddyAccounts.single.credits, isNull);
        expect(result.workBuddyAccounts.single.error, isNotNull);
      }
    },
  );
}
