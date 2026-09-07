import 'dart:convert';

import 'package:cliproxy_dash/services/antigravity_quota.dart';
import 'package:cliproxy_dash/services/management_service.dart';
import 'package:cliproxy_dash/models/quota_window.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

Map<String, dynamic> _summary() => {
  'groups': [
    {
      'displayName': 'Claude',
      'buckets': [
        {
          'displayName': 'Weekly',
          'remainingFraction': '0.42',
          'resetTime': '2026-09-15T00:00:00Z',
        },
        {'display_name': 'Session', 'remaining_fraction': 0},
      ],
    },
  ],
};

http.Response _upstream(Object body, {int status = 200}) =>
    http.Response(jsonEncode({'status_code': status, 'body': body}), 200);

ManagementService _service(MockClient client) => ManagementService(
  baseUri: Uri.parse('https://proxy.example/v0/management'),
  managementKey: 'test-only',
  client: client,
);

void main() {
  test('groups preserve zero, unknown, fractional values and reset times', () {
    final windows = parseAntigravityQuota(_summary());
    expect(windows.map((w) => w.remainingPercent), [42, 0]);
    expect(windows.first.label, 'Claude · Weekly');
    expect(windows.first.resetAt!.toUtc(), DateTime.utc(2026, 9, 15));
    final legacy = parseAntigravityQuota({
      'response': {
        'models': {
          'b': {
            'quotaInfo': {'remainingFraction': 'NaN'},
          },
          'a': {
            'displayName': 'Gemini',
            'quotaInfo': {'remainingFraction': 1},
          },
          'hidden': {'displayName': 'No quota metadata'},
        },
      },
    });
    expect(legacy.map((w) => w.remainingPercent), [100, null]);
    expect(legacy.map((w) => w.label), ['Gemini', 'b']);
    expect(parseAntigravityQuota({'models': 'invalid'}), isEmpty);
  });

  test(
    'discovers Antigravity and Codex, skips disabled, uses token substitution',
    () async {
      final calls = <Map<String, dynamic>>[];
      final result = await _service(
        MockClient((request) async {
          if (request.method == 'GET') {
            return http.Response(
              jsonEncode({
                'files': [
                  {
                    'id': 'ag',
                    'type': ' Antigravity ',
                    'authIndex': 'ag-1',
                    'email': 'alice@example.com',
                    'metadata': {'project_id': 'project-test'},
                  },
                  {
                    'provider': 'antigravity',
                    'auth_index': 'off',
                    'disabled': 'true',
                  },
                  {'provider': 'codex', 'auth_index': 'codex-1'},
                ],
              }),
              200,
            );
          }
          final call = Map<String, dynamic>.from(jsonDecode(request.body));
          calls.add(call);
          if (call['authIndex'] == 'ag-1') {
            expect(call['method'], 'POST');
            expect(call['url'], ManagementService.antigravityQuotaUrls.first);
            expect(jsonDecode(call['data']), {'project': 'project-test'});
            expect(call['header']['Authorization'], r'Bearer $TOKEN$');
            return _upstream(jsonEncode(_summary()));
          }
          return _upstream(
            call['url'] == ManagementService.usageUrl
                ? {
                    'rate_limit': {'allowed': true},
                  }
                : {'availableCount': 2},
          );
        }),
      ).fetchDashboard();
      expect(result.accounts, hasLength(1));
      expect(result.antigravityAccounts, hasLength(1));
      expect(result.antigravityAccounts.single.auth.name, 'ali***@example.com');
      expect(
        result.antigravityAccounts.single.lowestWindow!.remainingPercent,
        0,
      );
      expect(calls, hasLength(3));
    },
  );

  test(
    'falls back to legacy endpoint and reads project metadata only when missing',
    () async {
      var downloads = 0;
      var quotaCalls = 0;
      final result = await _service(
        MockClient((request) async {
          if (request.url.path.endsWith('/download')) {
            downloads++;
            expect(request.url.queryParameters['name'], 'account.json');
            return http.Response(
              jsonEncode({
                'installed': {'project_id': 'p'},
              }),
              200,
            );
          }
          if (request.method == 'GET') {
            return http.Response(
              jsonEncode({
                'files': [
                  {
                    'provider': 'antigravity',
                    'auth_index': 'a',
                    'name': 'account.json',
                  },
                ],
              }),
              200,
            );
          }
          quotaCalls++;
          final payload = jsonDecode(request.body);
          if (payload['url'] != ManagementService.antigravityQuotaUrls.last) {
            return _upstream({}, status: 404);
          }
          return _upstream({
            'models': {
              'gemini': {
                'quotaInfo': {'remainingFraction': 0.75},
              },
            },
          });
        }),
      ).fetchDashboard();
      expect(downloads, 1);
      expect(quotaCalls, 4);
      expect(
        result.antigravityAccounts.single.quota.windows.single.remainingPercent,
        75,
      );
    },
  );

  test(
    'one failed account does not hide other accounts or retry throttling',
    () async {
      var failedCalls = 0;
      final result = await _service(
        MockClient((request) async {
          if (request.method == 'GET') {
            return http.Response(
              jsonEncode({
                'files': [
                  for (final id in ['bad', 'good'])
                    {
                      'provider': 'antigravity',
                      'id': id,
                      'auth_index': id,
                      'project_id': 'p',
                    },
                  {'provider': 'antigravity', 'id': 'missing'},
                ],
              }),
              200,
            );
          }
          final call = jsonDecode(request.body);
          if (call['authIndex'] == 'bad') {
            failedCalls++;
            return _upstream({}, status: 429);
          }
          return _upstream(_summary());
        }),
      ).fetchDashboard();
      expect(failedCalls, 1);
      expect(
        result.antigravityAccounts[0].quota.error.toString(),
        contains('429'),
      );
      expect(result.antigravityAccounts[1].quota.hasError, isFalse);
      expect(
        result.antigravityAccounts[2].quota.error.toString(),
        contains('auth_index'),
      );
    },
  );

  test('quota parser rejects nonfinite values and labels actual duration', () {
    final window = QuotaWindow.fromJson({
      'used_percent': 'NaN',
      'remaining_percent': 75,
      'limit_window_seconds': 7200,
      'reset_at': 'Infinity',
    });
    expect(window.remainingPercent, 75);
    expect(window.progress, .25);
    expect(window.displayLabel, '2H额度');
    expect(window.resetAt, isNull);
    expect(QuotaWindow.parseResetTime(9e30), isNull);
  });
}
