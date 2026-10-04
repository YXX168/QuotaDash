import 'dart:io';
import 'package:cliproxy_dash/models/app_config.dart';
import 'package:cliproxy_dash/models/codex_evaluation.dart';
import 'package:cliproxy_dash/screens/codex_evaluation_screen.dart';
import 'package:cliproxy_dash/services/codex_evaluation_service.dart';
import 'package:cliproxy_dash/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'codex_evaluation_test.dart' show evaluationFixture;

class FakeEvaluationRepository implements CodexEvaluationRepository {
  bool running = false;
  int runsStarted = 0;
  List<String> lastIDs = [];
  @override
  Future<EvaluationState> fetchState() async =>
      EvaluationState.fromJson(evaluationFixture(running: running));
  @override
  Future<List<String>> fetchModels(
    List<EvaluationCredential> credentials,
  ) async => ['fixture-model'];
  @override
  Future<String> run({
    required EvaluationKind kind,
    required List<String> ids,
    required String model,
    String effort = 'low',
    int runs = 1,
    String mode = 'quick',
    int concurrency = 2,
  }) async {
    runsStarted++;
    lastIDs = ids;
    running = kind == EvaluationKind.candy;
    return '已启动 1 个账号';
  }

  @override
  Future<void> cancel(EvaluationKind kind, List<String> ids) async {
    running = false;
  }

  @override
  Future<EvaluationRecord> fetchRecord(
    String credentialId,
    EvaluationRecord record,
  ) async => record;
  @override
  void dispose() {}
}

Future<void> pumpPage(
  WidgetTester tester,
  FakeEvaluationRepository repository, {
  double width = 390,
  double scale = 1,
}) async {
  tester.view.physicalSize = Size(width, 1100);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.dark,
      home: MediaQuery(
        data: MediaQueryData(
          size: Size(width, 1100),
          textScaler: TextScaler.linear(scale),
        ),
        child: RepaintBoundary(
          key: const Key('evaluation-review'),
          child: CodexEvaluationScreen(
            config: const AppConfig(),
            repository: repository,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'refresh is read-only, default Codex selection and user start show progress',
    (tester) async {
      final repository = FakeEvaluationRepository();
      await pumpPage(tester, repository);
      expect(repository.runsStarted, 0);
      expect(find.text('syn***@example.invalid'), findsOneWidget);
      expect(find.text('Ano***'), findsNothing);
      await tester.tap(find.byKey(const Key('evaluation-refresh')));
      await tester.pumpAndSettle();
      expect(repository.runsStarted, 0);
      await tester.ensureVisible(find.byKey(const Key('evaluation-run')));
      await tester.tap(find.byKey(const Key('evaluation-run')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(repository.lastIDs, ['synthetic-a.json']);
      expect(repository.runsStarted, 1);
      await tester.ensureVisible(find.text('测试进行中 · 1/3'));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  for (final width in [320.0, 390.0]) {
    testWidgets('all tabs and detail work at width $width with large text', (
      tester,
    ) async {
      await pumpPage(
        tester,
        FakeEvaluationRepository(),
        width: width,
        scale: 1.5,
      );
      for (final kind in EvaluationKind.values) {
        await tester.ensureVisible(
          find.byKey(Key('evaluation-tab-${kind.name}')),
        );
        await tester.tap(find.byKey(Key('evaluation-tab-${kind.name}')));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.byKey(const Key('evaluation-cost')));
        expect(tester.takeException(), isNull);
      }
      await tester.ensureVisible(find.text('历史记录 · 1'));
      await tester.tap(find.text('历史记录 · 1'));
      await tester.pumpAndSettle();
      final history = find.widgetWithText(ListTile, 'fixture-model').last;
      await tester.drag(
        find.byKey(const Key('evaluation-scroll')),
        const Offset(0, -250),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(history);
      await tester.pumpAndSettle();
      await tester.tap(history);
      await tester.pumpAndSettle();
      expect(find.text('ModelTrace详情'), findsOneWidget);
      expect(find.textContaining('最近模型：'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
  testWidgets('render evaluation native review', (tester) async {
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
      final icons = FontLoader('MaterialIcons')
        ..addFont(
          Future.value(
            ByteData.sublistView(
              File(
                '$root/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
              ).readAsBytesSync(),
            ),
          ),
        );
      await icons.load();
    }
    await pumpPage(tester, FakeEvaluationRepository(), width: 390);
    await expectLater(
      find.byKey(const Key('evaluation-review')),
      matchesGoldenFile('../build/visual-review/codex-evaluation.png'),
    );
    await tester.pumpWidget(const SizedBox.shrink());
  }, tags: ['golden']);
}
