import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

Future<void> copySensitiveKey(String key) async {
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    await const MethodChannel(
      'cn.imyxx.cliproxy_dash/sensitive-clipboard',
    ).invokeMethod<void>('copy', {'text': key});
    return;
  }
  await Clipboard.setData(ClipboardData(text: key));
}
