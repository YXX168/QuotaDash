import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cliproxy_dash/models/app_config.dart';
import 'package:cliproxy_dash/models/managed_account.dart';
import 'package:cliproxy_dash/screens/account_management_screen.dart';
import 'package:cliproxy_dash/services/account_management_service.dart';
import 'package:cliproxy_dash/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

Map<String, dynamic> row({bool disabled = false, String id = 'fixture'}) => {
  'id': id,
  'name': '$id.json',
  'email': 'synthetic@example.invalid',
  'provider': 'codex',
  'source': 'file',
  'disabled': disabled,
};
http.Response response(Object body, [int status = 200]) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json'},
);
AccountManagementService service(MockClient client, String version) =>
    AccountManagementService(
      baseUri: Uri.parse('https://example.invalid/team/$version/management/'),
      managementKey: 'fixture-key',
      client: client,
    );

class Repository implements AccountManagementRepository {
  List<ManagedAccount> accounts = [
    ManagedAccount.fromJson(row()),
    ManagedAccount.fromJson(row(disabled: true, id: 'off')),
  ];
  Completer<void>? pending;
  bool fail = false;
  int writes = 0;
  @override
  Future<List<ManagedAccount>> fetchAccounts() async => accounts;
  @override
  Future<List<ManagedAccount>> setDisabled(
    ManagedAccount account,
    bool disabled,
  ) async {
    writes++;
    await pending?.future;
    if (fail) throw const AccountManagementException('账号操作失败，请稍后刷新检查');
    accounts = [
      for (final a in accounts)
        ManagedAccount.fromJson(
          row(id: a.id, disabled: a.id == account.id ? disabled : a.disabled!),
        ),
    ];
    return accounts;
  }

  @override
  void dispose() {}
}

Future<void> pumpPage(WidgetTester tester, Repository repo) async {
  tester.view.physicalSize = const Size(320, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.dark,
      home: MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(1.5)),
        child: AccountManagementScreen(
          config: const AppConfig(),
          repository: repo,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  for (final version in ['v0', 'v8']) {
    test(
      '$version only changes selected credential and verifies reread',
      () async {
        final requests = <http.Request>[];
        var disabled = false;
        final api = service(
          MockClient((r) async {
            requests.add(r);
            expect(r.url.host, 'example.invalid');
            expect(r.headers['Authorization'], 'Bearer fixture-key');
            final resource = version == 'v8' ? 'credentials' : 'auth-files';
            expect(
              r.url.path,
              '/team/$version/management/$resource${r.method == 'PATCH' ? '/status' : ''}',
            );
            if (r.method == 'PATCH') {
              final body = jsonDecode(r.body);
              expect(body['name'], 'fixture.json');
              expect(body.keys, unorderedEquals(['name', 'disabled']));
              disabled = body['disabled'];
              return response({'status': 'ok'});
            }
            return response({
              'files': [
                row(disabled: disabled),
                row(id: 'other', disabled: true),
              ],
            });
          }),
          version,
        );
        final accounts = await api.fetchAccounts();
        expect(accounts.first.name, 'syn***@example.invalid');
        expect(accounts.last.disabled, true);
        expect(
          (await api.setDisabled(accounts.first, true)).first.disabled,
          true,
        );
        final updated = await api.fetchAccounts();
        expect(
          (await api.setDisabled(updated.first, false)).first.disabled,
          false,
        );
        expect(requests.where((r) => r.method == 'PATCH'), hasLength(2));
        api.dispose();
      },
    );
  }

  test('unconfirmed write never reports success', () async {
    final api = service(
      MockClient(
        (r) async => response(
          r.method == 'PATCH'
              ? {'status': 'ok'}
              : {
                  'files': [row()],
                },
        ),
      ),
      'v8',
    );
    await expectLater(
      api.setDisabled(ManagedAccount.fromJson(row()), true),
      throwsA(
        isA<AccountManagementException>().having(
          (e) => e.message,
          'message',
          contains('尚未确认'),
        ),
      ),
    );
    api.dispose();
  });
  for (final status in [400, 401, 403, 404, 500, 302]) {
    test('HTTP $status is sanitized and cannot retry another route', () async {
      var calls = 0;
      final api = service(
        MockClient((r) async {
          calls++;
          return http.Response(
            'private-secret https://private.invalid',
            status,
            headers: {'location': 'https://foreign.invalid'},
          );
        }),
        'v8',
      );
      await expectLater(
        api.setDisabled(ManagedAccount.fromJson(row()), true),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'error',
            isNot(contains('private-secret')),
          ),
        ),
      );
      expect(calls, 1);
      api.dispose();
    });
  }
  test('unknown state and non-file credentials cannot change status', () async {
    final api = service(
      MockClient((_) async {
        fail('must not send request');
      }),
      'v8',
    );
    for (final data in [
      {...row(), 'disabled': null},
      {...row(), 'runtime_only': true},
      {...row(), 'source': 'api_key'},
      {...row(), 'source': 'plugin'},
    ]) {
      final a = ManagedAccount.fromJson(data);
      expect(a.canToggle, false);
      await expectLater(
        api.setDisabled(a, true),
        throwsA(isA<AccountManagementException>()),
      );
    }
    api.dispose();
  });
  testWidgets('disabled account can be enabled; refresh sends no mutation', (
    tester,
  ) async {
    final repo = Repository();
    await pumpPage(tester, repo);
    expect(repo.writes, 0);
    await tester.tap(find.byKey(const Key('accounts-refresh')));
    await tester.pumpAndSettle();
    expect(repo.writes, 0);
    await tester.tap(find.byKey(const Key('accounts-filter-disabled')));
    await tester.pumpAndSettle();
    final toggle = find.byKey(const ValueKey('account-enabled-off'));
    expect(tester.widget<Switch>(toggle).value, false);
    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(repo.accounts.last.disabled, false);
    await tester.tap(find.byKey(const Key('accounts-filter-all')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('account-enabled-fixture')));
    await tester.pumpAndSettle();
    expect(repo.accounts.first.disabled, true);
    expect(repo.writes, 2);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'pending operation locks switches; failure restores actual state',
    (tester) async {
      final repo = Repository()
        ..pending = Completer<void>()
        ..fail = true;
      await pumpPage(tester, repo);
      await tester.tap(find.byKey(const ValueKey('account-enabled-fixture')));
      await tester.pump();
      expect(repo.writes, 1);
      expect(
        tester
            .widget<Switch>(find.byKey(const ValueKey('account-enabled-off')))
            .onChanged,
        isNull,
      );
      repo.pending!.complete();
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<Switch>(
              find.byKey(const ValueKey('account-enabled-fixture')),
            )
            .value,
        true,
      );
      expect(find.text('账号操作失败，请稍后刷新检查'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('render account management review', (tester) async {
    final font = Platform.environment['QUOTA_REVIEW_FONT'];
    if (font != null) {
      final loader = FontLoader('sans-serif')
        ..addFont(
          Future.value(ByteData.sublistView(File(font).readAsBytesSync())),
        );
      await loader.load();
    }
    final root = Platform.environment['FLUTTER_ROOT'];
    if (root != null) {
      final loader = FontLoader('MaterialIcons')
        ..addFont(
          Future.value(
            ByteData.sublistView(
              File(
                '$root/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
              ).readAsBytesSync(),
            ),
          ),
        );
      await loader.load();
    }
    await pumpPage(tester, Repository());
    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile('../build/visual-review/account-management.png'),
    );
  }, tags: ['golden']);
}
