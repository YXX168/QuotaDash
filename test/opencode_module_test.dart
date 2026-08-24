import 'dart:convert';

import 'package:cliproxy_dash/models/provider_quota.dart';
import 'package:cliproxy_dash/services/opencode_module.dart';
import 'package:cliproxy_dash/services/opencode_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('OpenCodeModule', () {
    test('is disabled when API key is empty', () async {
      final module = OpenCodeModule(apiKey: '');
      expect(module.isEnabled, isFalse);
      final result = await module.fetch();
      expect(result.quota, isNull);
    });

    test('converts OpencodeQuota to unified ProviderQuota', () async {
      OpencodeService.clientOverride = MockClient(
        (request) async => http.Response(
          jsonEncode({
            'usage': {
              'rolling': {'percent': 20},
              'weekly': {'percent': 40},
              'monthly': {'percent': 60},
            },
          }),
          200,
        ),
      );
      addTearDown(() => OpencodeService.clientOverride = null);

      final module = OpenCodeModule(apiKey: 'test-key');
      expect(module.isEnabled, isTrue);

      final result = await module.fetch();
      final quota = result.quota!;
      expect(quota.provider, QuotaProviderId.openCode);
      expect(quota.hasError, isFalse);
      expect(quota.windows.length, 3);
      expect(quota.windows[0].label, '滚动额度');
      expect(quota.windows[0].remainingPercent, 80);
      expect(quota.windows[1].remainingPercent, 60);
      expect(quota.windows[2].remainingPercent, 40);
    });
  });
}
