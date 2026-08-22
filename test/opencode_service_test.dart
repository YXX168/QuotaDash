import 'dart:convert';

import 'package:cliproxy_dash/services/opencode_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('OpencodeService', () {
    test('parses rolling weekly and monthly usage windows', () async {
      final client = MockClient((request) async {
        expect(request.url.toString(), OpencodeService.usageUrl);
        expect(request.headers['authorization'], 'Bearer test-key');
        return http.Response(
          jsonEncode({
            'usage': {
              'rolling': {'percent': 3, 'resetsAt': 1787458162075},
              'weekly': {'percent': 10, 'resetsAt': 1787529600075},
              'monthly': {'percent': 5, 'resetsAt': 1789962107075},
            },
          }),
          200,
        );
      });
      final service = OpencodeService(apiKey: 'test-key', client: client);

      final quota = await service.fetchQuota();

      expect(quota.rolling?.usedPercent, 3);
      expect(quota.weekly?.usedPercent, 10);
      expect(quota.monthly?.usedPercent, 5);
      expect(quota.rolling?.resetAt, isNotNull);
    });

    test('throws friendly error on unauthorized key', () async {
      final client = MockClient((request) async => http.Response('', 401));
      final service = OpencodeService(apiKey: 'bad-key', client: client);

      expect(service.fetchQuota(), throwsA(isA<OpencodeException>()));
    });
  });
}
