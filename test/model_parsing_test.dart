import 'package:cliproxy_dash/models/app_config.dart';
import 'package:cliproxy_dash/models/codex_account.dart';
import 'package:cliproxy_dash/models/quota_window.dart';
import 'package:cliproxy_dash/services/cliproxyapi_module.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('CLIProxyAPI only enables with both required settings', () {
    const module = CliProxyApiModule();
    expect(
      module.isEnabled(
        const AppConfig(values: {'baseUrl': 'https://proxy.example'}),
      ),
      isFalse,
    );
    expect(
      module.isEnabled(const AppConfig(values: {'managementKey': 'secret'})),
      isFalse,
    );
    expect(
      module.isEnabled(
        const AppConfig(
          values: {
            'baseUrl': 'https://proxy.example',
            'managementKey': 'secret',
          },
        ),
      ),
      isTrue,
    );
  });

  test('quota window parses server durations without assuming five hours', () {
    final snake = QuotaWindow.fromJson({
      'used_percent': 125,
      'reset_at': 1750000000,
      'limit_window_seconds': 604800,
    });
    final camel = QuotaWindow.fromJson({
      'usedPercent': '20.5',
      'resetAt': '2026-07-15T12:00:00Z',
      'limitWindowSeconds': '18000',
    });

    expect(snake.remainingPercent, 0);
    expect(snake.resetAt, isNotNull);
    expect(snake.limitWindowSeconds, 604800);
    expect(snake.displayLabel, '周额度');
    expect(camel.remainingPercent, 79.5);
    expect(camel.resetAt, isNotNull);
    expect(camel.limitWindowSeconds, 18000);
    expect(camel.displayLabel, '5H额度');
  });

  test('auth file uses reference priority and masks identity', () {
    final account = AuthFileAccount.fromJson({
      'id': 7,
      'label': 'alice@example.com',
      'email': 'different@example.com',
      'authIndex': 12,
      'success_requests': '8',
      'failedRequests': 1,
      'recent_requests': [
        {'time': '14:00-14:10', 'success': 3, 'failed': 1},
        {'time': '14:10-14:20', 'success': '4', 'failed': 0},
      ],
    });

    expect(account.id, '7');
    expect(account.authIndex, '12');
    expect(account.name, 'ali***@example.com');
    expect(account.email, 'dif***@example.com');
    expect(account.successRequests, 8);
    expect(account.failedRequests, 1);
    expect(account.recentRequests, hasLength(2));
    expect(account.recentRequests.first.time, '14:00-14:10');
    expect(account.recentRequests.first.total, 4);
    expect(account.recentRequests.last.success, 4);
    expect(AuthFileAccount.maskName('xy'), '***');
    expect(AuthFileAccount.maskName('robot'), 'rob***');
  });

  test('recent request bucket treats an empty time label as missing', () {
    final account = AuthFileAccount.fromJson({
      'id': 'empty-window',
      'recent_requests': [
        {'time': '  ', 'success': 1, 'failed': 0},
      ],
    });

    expect(account.recentRequests.single.time, isNull);
  });
}
