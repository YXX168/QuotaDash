import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

Future<void> copySensitiveKey(String key) async {
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    try {
      await const MethodChannel(
        'cn.imyxx.cliproxy_dash/sensitive-clipboard',
      ).invokeMethod<void>('copy', {'text': key});
      return;
    } catch (_) {
      // Fallback to standard clipboard if platform-specific channel fails.
    }
  }
  await Clipboard.setData(ClipboardData(text: key));
}
