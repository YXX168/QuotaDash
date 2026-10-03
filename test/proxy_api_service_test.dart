import 'dart:convert';

import 'package:cliproxy_dash/services/proxy_api_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('ProxyApiService models', () {
    test(
      'merges configured and OAuth models and skips unusable auths',
      () async {
        final requestedModels = <String>[];
        final client = MockClient((request) async {
          expect(request.headers['authorization'], 'Bearer management-secret');
          if (request.url.path.endsWith('/config')) {
            return _jsonResponse({
              'codex-api-key': [
                {
                  'models': [
                    {
                      'name': 'gpt-config',
                      'alias': 'gpt-public',
                      'display-name': 'GPT Config',
                    },
                    {'name': ''},
                  ],
                  'excluded-models': ['gpt-old'],
                },
              ],
              'openai-compatibility': [
                {
                  'name': 'Local AI',
                  'api-key-entries': [
                    {'api-key': 'secret'},
                  ],
                  'models': [
                    {'name': 'local-model'},
                  ],
                },
              ],
              'oauth-excluded-models': {
                'codex': ['gpt-hidden'],
              },
            });
          }
          if (request.url.path.endsWith('/auth-files')) {
            return _jsonResponse({
              'files': [
                {'id': 'codex-one', 'provider': 'codex'},
                {'name': 'claude.json', 'type': 'claude'},
                {'id': 'disabled', 'provider': 'codex', 'disabled': true},
                {'id': 'cooling', 'provider': 'codex', 'unavailable': true},
              ],
            });
          }
          if (request.url.path.endsWith('/auth-files/models')) {
            final name = request.url.queryParameters['name']!;
            requestedModels.add(name);
            if (name == 'claude.json' || name == 'cooling') {
              return http.Response(jsonEncode({'error': 'stale auth'}), 404);
            }
            return _jsonResponse({
              'models': [
                {
                  'id': 'gpt-oauth',
                  'display_name': 'GPT OAuth',
                  'owned_by': 'openai',
                  'type': 'model',
                },
                {'id': 'gpt-oauth', 'display_name': 'GPT OAuth'},
                {'id': ''},
              ],
            });
          }
          fail('unexpected request: ${request.method} ${request.url}');
        });

        final result = await createService(client).fetchModels();

        expect(requestedModels, containsAll(['codex-one', 'claude.json']));
        expect(requestedModels, isNot(contains('disabled')));
        expect(requestedModels, contains('cooling'));

        final codex = result.providers.singleWhere(
          (group) => group.provider == 'OpenAI Codex',
        );
        expect(
          codex.models.map((model) => model.name),
          containsAll(['gpt-oauth', 'gpt-config']),
        );
        final oauth = codex.models.singleWhere(
          (model) => model.name == 'gpt-oauth',
        );
        final configured = codex.models.singleWhere(
          (model) => model.name == 'gpt-config',
        );
        expect(oauth.alias, isNull);
        expect(oauth.label, 'GPT OAuth');
        expect(oauth.ownedBy, 'openai');
        expect(configured.label, 'GPT Config');
        expect(configured.displayName, 'GPT Config');
        expect(codex.excludedModels, ['gpt-hidden', 'gpt-old']);

        final local = result.providers.singleWhere(
          (group) => group.provider == 'Local AI',
        );
        expect(local.models.single.name, 'local-model');
      },
    );

    test('keeps config models when auth discovery is unavailable', () async {
      final client = MockClient((request) async {
        if (request.url.path.endsWith('/config')) {
          return _jsonResponse({
            'gemini-api-key': [
              {
                'models': [
                  {'name': 'gemini-test'},
                ],
              },
            ],
          });
        }
        return http.Response(jsonEncode({'error': 'not found'}), 404);
      });

      final result = await createService(client).fetchModels();

      expect(result.providers.single.provider, 'Gemini');
      expect(result.providers.single.models.single.name, 'gemini-test');
    });
  });

  group('ProxyApiService management requests', () {
    test('formats API key GET, PUT, PATCH and DELETE requests', () async {
      final requests = <http.Request>[];
      final client = MockClient((request) async {
        requests.add(request);
        if (request.method == 'GET') {
          return _jsonResponse({
            'api-keys': ['first', 'second'],
          });
        }
        return _jsonResponse({'status': 'ok'});
      });
      final service = createService(client);

      expect(await service.fetchApiKeys(), ['first', 'second']);
      await service.replaceApiKeys(['only']);
      await service.addApiKey('new-key');
      await service.updateApiKey(index: 0, value: 'changed');
      await service.deleteApiKey(index: 0);

      expect(requests.map((request) => request.method), [
        'GET',
        'PUT',
        'PATCH',
        'PATCH',
        'DELETE',
      ]);
      expect(jsonDecode(requests[1].body), ['only']);
      expect(jsonDecode(requests[2].body), {
        'old': 'new-key',
        'new': 'new-key',
      });
      expect(jsonDecode(requests[3].body), {'index': 0, 'value': 'changed'});
      expect(requests[4].url.queryParameters, {'index': '0'});
    });

    test('includes status without server error details', () async {
      final detail = 'failure ' * 80;
      final client = MockClient(
        (request) async => http.Response(jsonEncode({'error': detail}), 503),
      );

      await expectLater(
        createService(client).fetchApiKeys(),
        throwsA(
          isA<ProxyApiException>()
              .having((error) => error.message, 'message', contains('503'))
              .having(
                (error) => error.message.length,
                'bounded message length',
                lessThan(230),
              ),
        ),
      );
    });

    test('rejects invalid API key mutation arguments', () async {
      final service = createService(
        MockClient((request) async => _jsonResponse({})),
      );

      await expectLater(service.updateApiKey(), throwsArgumentError);
      await expectLater(
        service.updateApiKey(oldValue: 'old'),
        throwsArgumentError,
      );
      await expectLater(service.deleteApiKey(), throwsArgumentError);
      await expectLater(
        service.deleteApiKey(value: 'key', index: 0),
        throwsArgumentError,
      );
    });
  });
}

ProxyApiService createService(http.Client client) {
  return ProxyApiService(
    baseUri: Uri.parse('https://proxy.example/v0/management/'),
    managementKey: 'management-secret',
    client: client,
  );
}

http.Response _jsonResponse(Object body, [int statusCode = 200]) {
  return http.Response(
    jsonEncode(body),
    statusCode,
    headers: {'content-type': 'application/json'},
  );
}
