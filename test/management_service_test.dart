import 'dart:convert';

import 'package:cliproxy_dash/services/management_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('ManagementService', () {
    test(
      'parses auth files and both quota endpoints like reference script',
      () async {
        final requests = <http.Request>[];
        final client = MockClient((request) async {
          requests.add(request);
          if (request.method == 'GET' &&
              request.url.path.endsWith('/auth-files')) {
            return http.Response(
              jsonEncode({
                'files': [
                  {
                    'id': 'one',
                    'provider': 'codex',
                    'email': 'alice@example.com',
                    'auth_index': 'auth-1',
                    'success': 24,
                    'failed': '2',
                    'recent_requests': [
                      {'time': '14:00-14:10', 'success': 6, 'failed': 1},
                    ],
                  },
                  {
                    'provider': 'codex',
                    'name': 'disabled@example.com',
                    'authIndex': 'auth-2',
                    'disabled': true,
                  },
                  {'provider': 'gemini', 'auth_index': 'other'},
                ],
              }),
              200,
            );
          }

          final payload = jsonDecode(request.body) as Map<String, dynamic>;
          final url = payload['url'] as String;
          if (url == ManagementService.usageUrl) {
            final header = payload['header'] as Map<String, dynamic>;
            expect(header['Authorization'], r'Bearer $TOKEN$');
            expect(header['User-Agent'], ManagementService.userAgent);
            return http.Response(
              jsonEncode({
                'status_code': 200,
                'body': jsonEncode({
                  'plan_type': 'team',
                  'rate_limit': {
                    'allowed': true,
                    'limit_reached': false,
                    'primary_window': {
                      'used_percent': 12.5,
                      'reset_at': 1750000000,
                      'limit_window_seconds': 604800,
                    },
                    'secondaryWindow': {
                      'usedPercent': '40',
                      'resetAt': '1750100000',
                      'limitWindowSeconds': 2592000,
                    },
                  },
                }),
              }),
              200,
            );
          }

          expect(url, ManagementService.resetCreditsUrl);
          final header = payload['header'] as Map<String, dynamic>;
          expect(header['Accept'], 'application/json');
          expect(header['OpenAI-Beta'], 'codex-1');
          expect(header['Originator'], 'Codex Desktop');
          return http.Response(
            jsonEncode({
              'status_code': 200,
              'body': {'available_count': 3},
            }),
            200,
          );
        });

        final service = ManagementService(
          baseUri: Uri.parse('https://proxy.example/v0/management/'),
          managementKey: 'management-secret',
          client: client,
        );
        final snapshot = await service.fetchDashboard();

        expect(snapshot.accounts, hasLength(1));
        final account = snapshot.accounts.single;
        expect(account.name, 'ali***@example.com');
        expect(account.email, 'ali***@example.com');
        expect(account.plan, 'team');
        expect(account.primaryLabel, '周额度');
        expect(account.secondaryLabel, '月度额度');
        expect(account.primary!.usedPercent, 12.5);
        expect(account.primary!.remainingPercent, 87.5);
        expect(account.secondary!.remainingPercent, 60);
        expect(account.weeklyRemainingPercent, 87.5);
        expect(account.resetCredits, 3);
        expect(account.successRequests, 24);
        expect(account.failedRequests, 2);
        expect(account.recentTotal, 7);
        expect(account.recentFailed, 1);
        expect(account.recentRequests.single.time, '14:00-14:10');
        expect(requests, hasLength(3));
        expect(
          requests.first.headers['authorization'],
          'Bearer management-secret',
        );
        expect(requests.first.url.path, '/v0/management/auth-files');
      },
    );

    test('keeps usage data when reset credits request fails', () async {
      final client = MockClient((request) async {
        if (request.method == 'GET') {
          return http.Response(
            jsonEncode({
              'files': [
                {'provider': 'codex', 'label': 'robot', 'authIndex': 'index'},
              ],
            }),
            200,
          );
        }
        final payload = jsonDecode(request.body) as Map<String, dynamic>;
        if (payload['url'] == ManagementService.usageUrl) {
          return http.Response(
            jsonEncode({
              'status_code': 200,
              'body': {
                'planType': 'plus',
                'rateLimit': {'allowed': true},
              },
            }),
            200,
          );
        }
        return http.Response(jsonEncode({'status_code': 429}), 200);
      });

      final snapshot = await ManagementService(
        baseUri: Uri.parse('https://proxy.example/v0/management'),
        managementKey: 'secret',
        client: client,
      ).fetchDashboard();

      expect(snapshot.accounts.single.error, isNull);
      expect(snapshot.accounts.single.resetCredits, isNull);
      expect(snapshot.accounts.single.resetCreditsError, contains('429'));
    });

    test('turns a failed usage call into an account-level error', () async {
      final client = MockClient((request) async {
        if (request.method == 'GET') {
          return http.Response(
            jsonEncode({
              'files': [
                {'provider': 'codex', 'label': 'bob@example.com'},
              ],
            }),
            200,
          );
        }
        fail('api-call must not run without auth index');
      });

      final snapshot = await ManagementService(
        baseUri: Uri.parse('https://proxy.example/v0/management'),
        managementKey: 'secret',
        client: client,
      ).fetchDashboard();

      expect(snapshot.accounts.single.name, 'bob***@example.com');
      expect(snapshot.accounts.single.error, contains('auth_index'));
    });

    test('reports a non-JSON upstream body as an account error', () async {
      final client = MockClient((request) async {
        if (request.method == 'GET') {
          return http.Response(
            jsonEncode({
              'files': [
                {
                  'id': 'one',
                  'provider': 'codex',
                  'label': 'alice@example.com',
                  'auth_index': 'auth-1',
                },
              ],
            }),
            200,
          );
        }
        return http.Response(
          jsonEncode({'status_code': 200, 'body': '<html>login</html>'}),
          200,
        );
      });

      final snapshot = await ManagementService(
        baseUri: Uri.parse('https://proxy.example/v0/management'),
        managementKey: 'secret',
        client: client,
      ).fetchDashboard();

      expect(snapshot.accounts.single.error, contains('无效 JSON'));
    });
  });
}
