import 'package:flutter/material.dart';

import '../models/opencode_quota.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_widgets.dart';
import '../widgets/quota_progress.dart';

class OpencodeQuotaCard extends StatelessWidget {
  const OpencodeQuotaCard({required this.quota, super.key});

  final OpencodeQuota quota;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppTheme.magenta.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppTheme.magenta.withValues(alpha: 0.2),
                  ),
                ),
                child: const Icon(
                  Icons.bolt_rounded,
                  size: 21,
                  color: AppTheme.magenta,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'OpenCode Go',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    Text(
                      '数据来自 OpenCode 官方用量接口',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ...quota.windows.map(
            (entry) => Padding(
              padding: const EdgeInsets.only(bottom: 18),
              child: QuotaProgress(label: entry.label, window: entry.window),
            ),
          ),
        ],
      ),
    );
  }
}
