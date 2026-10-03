import 'package:flutter/material.dart';

import '../models/workbuddy_account.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_widgets.dart';
import '../widgets/request_activity.dart';
import '../widgets/workbuddy_credits_view.dart';

class WorkBuddyDetailScreen extends StatelessWidget {
  const WorkBuddyDetailScreen({required this.account, super.key});

  final WorkBuddyAccount account;

  @override
  Widget build(BuildContext context) {
    final auth = account.auth;
    return Scaffold(
      body: AppBackdrop(
        child: SafeArea(
          child: CustomScrollView(
            slivers: [
              const SliverAppBar(
                title: Text('WorkBuddy 账号详情'),
                pinned: true,
                backgroundColor: Colors.transparent,
                surfaceTintColor: Colors.transparent,
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 38),
                sliver: SliverList.list(
                  children: [
                    GlassCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            account.displayName,
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              StatusPill(
                                label: account.regionLabel,
                                color: AppTheme.cyan,
                              ),
                              if (account.plan.isNotEmpty)
                                StatusPill(
                                  label: account.plan,
                                  color: AppTheme.cyan,
                                ),
                              if (account.disabled)
                                const StatusPill(
                                  label: '已禁用',
                                  color: Color(0xFF75829B),
                                ),
                              if (account.exhausted == true)
                                const StatusPill(
                                  label: '积分耗尽',
                                  color: AppTheme.warning,
                                ),
                              if (account.selected)
                                const StatusPill(
                                  label: '当前账号',
                                  color: AppTheme.success,
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    GlassCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SectionTitle(title: '积分与积分包'),
                          const SizedBox(height: 16),
                          WorkBuddyCreditsView(account: account),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    GlassCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SectionTitle(title: '请求活动'),
                          const SizedBox(height: 12),
                          Text(
                            '成功 ${auth.successRequests} · 失败 ${auth.failedRequests}',
                          ),
                          if (auth.recentRequests.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            RequestSparkline(buckets: auth.recentRequests),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
