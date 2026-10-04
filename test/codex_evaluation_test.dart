import 'dart:convert';
import 'package:cliproxy_dash/models/codex_evaluation.dart';
import 'package:cliproxy_dash/services/codex_evaluation_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

Map<String, dynamic> evaluationFixture({bool running = false}) => {
  'auths': [
    {
      'id': 'synthetic-a.json',
      'provider': 'codex',
      'source': 'auth_files',
      'email': 'synthetic@example.invalid',
      'name': 'synthetic-a',
      'plan_type': 'plus',
      'disabled': false,
      if (running) 'running': {'done': 1, 'total': 3},
      'results': [
        {
          'model': 'fixture-model',
          'effort': 'low',
          'ok': true,
          'answer': '答案为 21',
          'time': '2026-10-05T01:00:00Z',
        },
        {'model': 'fixture-model', 'effort': 'high', 'ok': false},
        {
          'model': 'fixture-model',
          'effort': 'low',
          'ok': false,
          'error': 'private-diagnostic',
        },
        {'model': 'fixture-model', 'effort': 'low', 'skipped': true},
      ],
      'fingerprints': [
        {
          'id': 'fp1',
          'model': 'fixture-model',
          'status': 'completed',
          'attribution': {'status': 'consistent'},
        },
      ],
      'modeltraces': [
        {
          'id': 'mt1',
          'model': 'fixture-model',
          'status': 'partial',
          'attribution': {'prediction': 'fixture-model', 'probability': 0.9},
        },
      ],
    },
    {
      'id': 'synthetic-b.json',
      'provider': 'antigravity',
      'source': 'auth_files',
      'name': 'Another',
      'disabled': false,
      'results': [],
      'fingerprints': [],
      'modeltraces': [],
    },
  ],
};
http.Response _json(Object body, {int status = 200}) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);
CodexEvaluationService _service(MockClient client, {String version = 'v8'}) =>
    CodexEvaluationService(
      baseUri: Uri.parse('https://example.invalid/team/$version/management'),
      managementKey: 'fictional-key',
      client: client,
    );
void main() {
  test(
    'accuracy excludes errors/skips and separates effort; names and text redacted',
    () {
      final state = EvaluationState.fromJson(evaluationFixture(running: true));
      final credential = state.credentials.first;
      expect(credential.name, 'syn***@example.invalid');
      expect(credential.accuracy('fixture-model', 'low'), 100);
      expect(credential.accuracy('fixture-model', 'high'), 0);
      expect(credential.accuracy('another-model', 'low'), isNull);
      expect(credential.runnable, isFalse);
      expect(state.busy, isTrue);
      expect(credential.progress[EvaluationKind.candy]!.done, 1);
      expect(
        evaluationText('https://private.example.invalid/x 10.1.2.3:456'),
        isNot(contains('private.example')),
      );
      expect(
        evaluationText('Bearer abc-secret sk-fictional-key eyJxxx.abc.def'),
        isNot(contains('abc-secret')),
      );
      expect(
        credential.records[EvaluationKind.fingerprint]!.single.verdict,
        '与所选模型一致',
      );
      expect(
        credential.records[EvaluationKind.modelTrace]!.single.positive,
        isTrue,
      );
      expect(credential.records[EvaluationKind.candy]![2].verdict, '请求失败');
      expect(credential.records[EvaluationKind.candy]![3].verdict, '已跳过');
      expect(evaluationInt(double.infinity), isNull);
      expect(EvaluationRecord(EvaluationKind.candy, {}).isGraded, isFalse);
      expect(
        () => EvaluationState.fromJson({
          'auths': [
            {'id': 'a'},
          ],
        }),
        throwsFormatException,
      );
      expect(
        () => EvaluationState.fromJson({'auths': null}),
        throwsFormatException,
      );
    },
  );
  for (final version in ['v8', 'v0']) {
    test('$version paths stay same-origin; reads never start tests', () async {
      final paths = <String>[];
      final service = _service(
        MockClient((request) async {
          expect(request.method, 'GET');
          expect(request.url.host, 'example.invalid');
          expect(request.headers['Authorization'], 'Bearer fictional-key');
          paths.add(request.url.path);
          if (request.url.path.contains('/v8/')) return _json({}, status: 404);
          if (request.url.path.endsWith('/state')) {
            return _json(evaluationFixture());
          }
          expect(request.url.path, '/team/v0/management/auth-files/models');
          expect(request.url.queryParameters['name'], isNotEmpty);
          return _json({
            'models': [
              {'id': 'fixture-model'},
              {'id': 'image-fixture'},
              {'id': 'codex-auto-review'},
            ],
          });
        }),
        version: version,
      );
      final state = await service.fetchState();
      expect(await service.fetchModels(state.credentials), ['fixture-model']);
      expect(
        paths.first,
        '/team/$version/management/plugins/cpa-codex-candy-eval/state',
      );
      service.dispose();
    });
  }
  for (final code in [400, 401, 403, 500]) {
    test('HTTP $code cannot fallback or expose diagnostics', () async {
      var calls = 0;
      final service = _service(
        MockClient((request) async {
          calls++;
          return _json({
            'error': 'https://private.invalid sk-fictional-secret',
          }, status: code);
        }),
      );
      await expectLater(
        service.fetchState(),
        throwsA(
          isA<EvaluationException>().having(
            (e) => e.message,
            'public message',
            isNot(contains('private.invalid')),
          ),
        ),
      );
      expect(calls, 1);
      service.dispose();
    });
  }
  for (final kind in EvaluationKind.values) {
    test(
      '${kind.name} dispatch uses only selected IDs and per-account models',
      () async {
        final posts = <http.Request>[];
        final service = _service(
          MockClient((request) async {
            if (request.method == 'GET') {
              if (request.url.queryParameters['name'] == 'unknown') {
                return _json({}, status: 500);
              }
              return _json({'models': []});
            }
            posts.add(request);
            if (request.url.path.contains('/v8/')) {
              return _json({}, status: 404);
            }
            return _json({'started': 1, 'skipped': 1, 'unchecked': 1});
          }),
        );
        final text = await service.run(
          kind: kind,
          ids: ['known', 'unknown'],
          model: 'fixture-model',
          runs: 2,
        );
        final body = jsonDecode(posts.last.body) as Map;
        expect(body['auth_ids'], ['known', 'unknown']);
        expect(body['model_catalog'], {'known': []});
        expect(body['all'], isNull);
        expect(
          posts.last.url.path,
          '/team/v0/management/plugins/cpa-codex-candy-eval/${kind.route}run',
        );
        expect(body['effort'], kind == EvaluationKind.candy ? 'low' : isNull);
        expect(body['runs'], kind == EvaluationKind.candy ? 2 : isNull);
        expect(body['concurrency'], kind == EvaluationKind.candy ? isNull : 2);
        expect(text, contains('已启动 1 个账号'));
        service.dispose();
      },
    );
  }
  test(
    'record/cancel encode identifiers; redirects cannot leak keys',
    () async {
      final requests = <http.Request>[];
      final service = _service(
        MockClient((request) async {
          requests.add(request);
          if (request.url.path.endsWith('/record')) {
            return _json({
              'id': 'a/b',
              'model': 'fixture-model',
              'status': 'failed',
            });
          }
          return _json({'cancelled': 1});
        }),
      );
      final record = EvaluationRecord(EvaluationKind.fingerprint, {
        'id': 'a/b',
      });
      expect((await service.fetchRecord('a+b.json', record)).id, 'a/b');
      expect(requests.first.url.queryParameters, {
        'auth_id': 'a+b.json',
        'id': 'a/b',
      });
      await service.cancel(EvaluationKind.modelTrace, ['a+b.json']);
      expect(jsonDecode(requests.last.body), {
        'auth_ids': ['a+b.json'],
      });
      await expectLater(
        service.cancel(EvaluationKind.candy, ['a']),
        throwsA(isA<EvaluationException>()),
      );
      service.dispose();
      final redirect = _service(
        MockClient(
          (r) async => http.Response(
            '',
            302,
            headers: {'location': 'https://foreign.invalid'},
          ),
        ),
      );
      await expectLater(redirect.fetchState(), throwsA(isA<Exception>()));
      redirect.dispose();
    },
  );
}
